import Foundation
import LumoCore
import LumoShieldKit

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
        if seedCoins > 0 {
            // Granted, never earned — the invariant holds even in a test hook, because `earned` is
            // the pot nothing may inflate.
            state.wallet.issueGrant(seedCoins)
        }

        try? store.saveBuckets(table, essential: .replaceBecauseUserEdited)
        try? store.saveState(state)
    }

    /// `FA CE` prefix so a synthetic token is recognisable at a glance in a state dump. If one ever
    /// leaked into real data it would be obvious rather than subtle.
    private static func syntheticToken(_ marker: Int) -> TokenBlob {
        TokenBlob(raw: Data([0xFA, 0xCE, UInt8(marker & 0xFF)]))
    }
}
