import Foundation
import LumoCore
import LumoShieldKit
import SwiftData

/// Launch-argument hooks for UI tests.
///
/// These exist because the flows that broke on device are **not reachable in a test otherwise**:
/// `FamilyActivityPicker` is a system, out-of-process view that does not function in the Simulator
/// at all, and it returns opaque tokens that cannot be synthesised. So a UI test can tap the button
/// that opens it but can never make it return a selection.
///
/// Rather than give up on the five bugs that were pure UI-flow problems, the app can be launched
/// with pre-seeded selections. That keeps the *interesting* assertions testable — does re-picking one
/// list wipe the other, does a sheet survive its first tap — in the Simulator, in CI.
///
/// Gated on launch arguments, which cannot be supplied to an App Store build, so this is inert in
/// production rather than merely discouraged.
enum UITestSupport {

    private static let args = Set(CommandLine.arguments)

    static var isActive: Bool { args.contains("-lumo-ui-testing") }

    /// Wipes all Lumo state so each test starts from a known point.
    static var shouldResetState: Bool { args.contains("-lumo-reset") }

    /// Jumps past onboarding, for tests about Settings rather than setup.
    static var shouldSkipOnboarding: Bool { args.contains("-lumo-skip-onboarding") }

    static var seedEssentialCount: Int { intValue(after: "-lumo-seed-essential") }
    static var seedBlockedCount: Int { intValue(after: "-lumo-seed-blocked") }
    static var seedCoins: Int { intValue(after: "-lumo-seed-coins") }

    private static func intValue(after flag: String) -> Int {
        let all = CommandLine.arguments
        guard let index = all.firstIndex(of: flag), index + 1 < all.count else { return 0 }
        return Int(all[index + 1]) ?? 0
    }

    /// Applies the requested state before any UI renders.
    static func apply() {
        guard isActive else { return }
        guard let store = LumoStack.stateStore(for: .app) else { return }

        if shouldResetState {
            store.removeAll()
            try? store.saveSchemaVersion(SchemaVersion.current)
        }

        var table = (try? store.loadBuckets()) ?? .empty
        var state = (try? store.loadState()) ?? .initial

        // Synthetic tokens. Deliberately deterministic and clearly fake — a UI test asserting
        // COUNTS does not need real tokens, and using recognisable bytes means a leak into
        // production data would be obvious rather than subtle.
        if seedEssentialCount > 0 {
            table.essential = Set((0..<seedEssentialCount).map { syntheticToken(0xE0 + $0) })
        }
        if seedBlockedCount > 0 {
            let apps = Set((0..<seedBlockedCount).map { syntheticToken(0xB0 + $0) })
            if let outcome = try? BucketPartitioner.commit(
                applications: apps, categories: [], into: table, now: Date()) {
                table = outcome.table
            }
        }
        // Stamp the current week ALWAYS, not only when seeding coins.
        //
        // The weekly grant fires whenever `weekStart` is stale, and on a reset install it always is
        // — so it expired the seeded balance and replaced it with the full 140. A test that asked
        // for 8 coins silently got 140, and one that asked for none got an affordable ladder. The
        // grant is right; the seed just has to look like a week already in progress.
        state.week.weekStart = GrantCycle.weekStart(for: Date())
        if seedCoins > 0 {
            // Granted, never earned — the invariant holds even in a test hook, because `earned` is
            // the pot nothing may inflate.
            state.wallet.issueGrant(seedCoins)
        }

        try? store.saveBuckets(table, essential: .replaceBecauseUserEdited)
        try? store.saveState(state)
    }

    /// Clears SwiftData too.
    ///
    /// Separate from `apply()` because it must run AFTER the model container is open, whereas
    /// `apply()` runs before any UI so the seeded state is migrated and reconciled like any other.
    ///
    /// Needed because `store.removeAll()` clears the App Group defaults and nothing else — which is
    /// correct for the product (teardown deliberately keeps the ledger and the user's history) and
    /// wrong for tests, where habits leaking from one case into the next made the empty-state path
    /// unreachable.
    @MainActor
    static func resetPersistence() {
        guard isActive, shouldResetState else { return }
        // Opens the container first. It is created lazily by `ledgerStore()`, so at this point in
        // launch it is still nil — the first version of this guard therefore returned early every
        // single time and reset nothing, while looking exactly like a reset that found nothing.
        LumoPersistence.start()
        guard let container = LumoPersistence.container else { return }
        let context = ModelContext(container)
        try? context.delete(model: HabitRecord.self)
        try? context.delete(model: SessionRecord.self)
        try? context.delete(model: LedgerEntryRecord.self)
        try? context.save()
    }

    /// `FA CE` prefix so a synthetic token is recognisable at a glance in a state dump. If one ever
    /// leaked into real data it would be obvious rather than subtle.
    private static func syntheticToken(_ marker: Int) -> TokenBlob {
        TokenBlob(raw: Data([0xFA, 0xCE, UInt8(marker & 0xFF)]))
    }
}
