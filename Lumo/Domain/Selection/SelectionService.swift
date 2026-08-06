import FamilyControls
import Foundation
import LumoCore
import LumoShieldKit
import ManagedSettings
import Observation

/// Turns a `FamilyActivitySelection` into committed bucket slots.
///
/// Two selections are kept, and the order they are collected in matters: the **essential** set is
/// gathered first, on its own screen, so that a token can never pass through a state where it is
/// both chosen-for-shielding and medically necessary.
@MainActor
@Observable
final class SelectionService {

    /// Apps the user has marked as never-shield.
    var essentialSelection = FamilyActivitySelection()
    /// Apps the user wants shielded.
    var blockSelection = FamilyActivitySelection()

    private(set) var lastOutcome: BucketPartitioner.Outcome?
    private(set) var commitError: CommitFailure?

    enum CommitFailure: Equatable {
        /// Named rather than counted, so the UI can say which apps did not fit.
        case tooManyApps(requested: Int, cap: Int)
        case tooManyCategories(requested: Int, cap: Int)
        case appGroupUnavailable
        case storeUnavailable

        var message: String {
            switch self {
            case let .tooManyApps(requested, cap):
                "You picked \(requested) apps. iOS lets Lumo lock \(cap) at once — remove \(requested - cap) and try again."
            case let .tooManyCategories(requested, cap):
                "You picked \(requested) categories. Lumo supports \(cap)."
            case .appGroupUnavailable, .storeUnavailable:
                "Lumo can't save your choices right now. Reopening the app usually fixes it."
            }
        }
    }

    // MARK: - Counts for live UI

    var blockedAppCount: Int { blockSelection.applicationTokens.count }
    var blockedCategoryCount: Int { blockSelection.categoryTokens.count }
    var essentialCount: Int {
        essentialSelection.applicationTokens.count + essentialSelection.categoryTokens.count
    }

    var appCap: Int { BucketTable.defaultMaxApplicationTokens }
    var isOverCap: Bool { blockedAppCount > appCap }

    /// Remaining headroom, floored at zero so the UI never shows a negative.
    var remainingAppSlots: Int { max(0, appCap - blockedAppCount) }

    // MARK: - Commit

    /// Persists both selections and applies shields.
    ///
    /// All-or-nothing. Over the cap the whole commit is refused and the overflow is named, because
    /// iOS fails **silently and totally** at 51 shielded tokens — there is no error to catch, so a
    /// partial commit would look exactly like Lumo eating the user's settings.
    @discardableResult
    func commit() -> Bool {
        commitError = nil

        guard let store = LumoStack.stateStore(for: .app) else {
            commitError = .appGroupUnavailable
            return false
        }
        guard var table = try? store.loadBuckets() else {
            commitError = .storeUnavailable
            return false
        }

        // Essential first, and evicting as it goes, so no window exists in which a token is both
        // essential and shielded.
        table.essential = blobs(from: essentialSelection)
        for token in table.essential { table.markEssential(token) }

        do {
            let outcome = try BucketPartitioner.commit(
                applications: blobs(fromApplications: blockSelection),
                categories: blobs(fromCategories: blockSelection),
                into: table,
                now: Date()
            )
            try store.saveBuckets(outcome.table)
            lastOutcome = outcome

            // Apply immediately. A saved-but-unapplied blocklist is the state where the UI says
            // "locked" and nothing is.
            LumoStack.reconcileNow(.app)
            DarwinPing.windowsChanged.post()
            return true

        } catch let error as BucketPartitioner.CommitError {
            switch error {
            case let .tooManyApplications(requested, cap, _):
                commitError = .tooManyApps(requested: requested, cap: cap)
            case let .tooManyCategories(requested, cap, _):
                commitError = .tooManyCategories(requested: requested, cap: cap)
            }
            return false
        } catch {
            commitError = .storeUnavailable
            return false
        }
    }

    /// Loads any previously committed selection so the picker opens on what the user already chose.
    ///
    /// Tokens are opaque and cannot be turned back into a `FamilyActivitySelection` reliably, so
    /// this only restores counts for display. Re-opening the picker starts from the system's own
    /// notion of the current selection.
    func loadCommittedCounts() -> (apps: Int, categories: Int, essential: Int)? {
        guard let store = LumoStack.stateStore(for: .app),
              let table = try? store.loadBuckets()
        else { return nil }
        return (table.applicationBucketCount, table.categoryBucketCount, table.essential.count)
    }

    // MARK: - Token conversion

    private func blobs(from selection: FamilyActivitySelection) -> Set<TokenBlob> {
        blobs(fromApplications: selection).union(blobs(fromCategories: selection))
    }

    private func blobs(fromApplications selection: FamilyActivitySelection) -> Set<TokenBlob> {
        // A token that will not encode is silently dropped rather than failing the whole commit:
        // losing one app from the blocklist is recoverable by re-picking, whereas refusing the
        // commit strands the user with no blocklist at all.
        Set(selection.applicationTokens.compactMap { try? TokenCodec.blob(from: $0) })
    }

    private func blobs(fromCategories selection: FamilyActivitySelection) -> Set<TokenBlob> {
        Set(selection.categoryTokens.compactMap { try? TokenCodec.blob(from: $0) })
    }
}
