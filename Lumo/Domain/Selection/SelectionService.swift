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
    var essentialSelection = FamilyActivitySelection() {
        didSet { didEditEssential = true }
    }
    /// Apps the user wants shielded.
    var blockSelection = FamilyActivitySelection() {
        didSet { didEditBlocked = true }
    }

    /// Whether the user actually opened and used each picker in this session.
    ///
    /// Load-bearing. Tokens are opaque, so a persisted selection CANNOT be loaded back into a
    /// picker — the in-memory selection always starts empty. Treating it as authoritative meant
    /// re-picking one list silently wiped the other. Observed on device: editing the blocklist
    /// erased three protected apps, which is the one failure mode here with a physical-harm path.
    private(set) var didEditEssential = false
    private(set) var didEditBlocked = false

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

    /// Persists the essential set on its own, without touching the blocklist.
    ///
    /// Called when leaving the essential step rather than waiting for the end of the flow. The
    /// previous version only saved on the final commit, so a user who protected their medical apps
    /// and then skipped the blocklist had that protection silently discarded — the one failure mode
    /// in this project with a physical-harm path.
    @discardableResult
    func commitEssentialOnly() -> Bool {
        guard let store = LumoStack.stateStore(for: .app) else {
            commitError = .appGroupUnavailable
            return false
        }
        guard var table = try? store.loadBuckets() else {
            commitError = .storeUnavailable
            return false
        }
        table.essential = blobs(from: essentialSelection)
        for token in table.essential { table.markEssential(token) }
        guard (try? store.saveBuckets(table)) != nil else {
            commitError = .storeUnavailable
            return false
        }
        LumoStack.reconcileNow(.app)
        LumoStack.diagnostics(for: .app).record(
            "selection.essentialSaved", detail: "\(table.essential.count) token(s)")
        return true
    }

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

        // Only replace a list the user actually edited. Otherwise the persisted set stands.
        if didEditEssential {
            table.essential = blobs(from: essentialSelection)
            for token in table.essential { table.markEssential(token) }
        }

        // Likewise, leave the blocklist alone if it was not touched.
        let wantedApps = didEditBlocked
            ? blobs(fromApplications: blockSelection)
            : Set(table.buckets.values.filter { $0.kind == .application }.map(\.token))
        let wantedCategories = didEditBlocked
            ? blobs(fromCategories: blockSelection)
            : Set(table.buckets.values.filter { $0.kind == .category }.map(\.token))

        do {
            let outcome = try BucketPartitioner.commit(
                applications: wantedApps,
                categories: wantedCategories,
                into: table,
                now: Date()
            )
            try store.saveBuckets(outcome.table)
            lastOutcome = outcome

            // A slot that was just added or removed cannot keep a window bought for whatever used
            // to occupy it, or a newly locked app inherits free access.
            let reassigned = outcome.added.union(outcome.removed)
            if var state = try? store.loadState() {
                let dropped = state.invalidateWindows(forReassignedSlots: reassigned)
                if dropped > 0 {
                    try? store.saveState(state)
                    LumoStack.diagnostics(for: .app).record(
                        "selection.windowsInvalidated", detail: "\(dropped) for reassigned slots")
                }
            }
            LumoStack.diagnostics(for: .app).record(
                "selection.committed",
                detail: "added \(outcome.added.count) retained \(outcome.retained.count) refusedEssential \(outcome.refusedAsEssential.count) tableTotal \(outcome.table.buckets.count)"
            )

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
        let encoded = selection.applicationTokens.compactMap { try? TokenCodec.blob(from: $0) }
        let unique = Set(encoded)
        // Instrumented because a silent drop OR a silent collision here both present identically:
        // a blocklist that mysteriously ends up empty. Distinct-count is the decisive number —
        // if N tokens produce fewer than N blobs, the codec is not preserving identity.
        LumoStack.diagnostics(for: .app).record(
            "selection.encodeApps",
            detail: "tokens \(selection.applicationTokens.count) encoded \(encoded.count) distinct \(unique.count) bytes \(encoded.first?.raw.count ?? -1)"
        )
        return unique
    }

    private func blobs(fromCategories selection: FamilyActivitySelection) -> Set<TokenBlob> {
        Set(selection.categoryTokens.compactMap { try? TokenCodec.blob(from: $0) })
    }
}
