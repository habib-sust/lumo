import Foundation
import LumoCore
import LumoShieldKit
import SwiftData

/// `CoinLedgerStore` backed by SwiftData.
///
/// `@MainActor` because `ModelContext` is not `Sendable` and this is only ever used from the app's
/// foreground path. The protocol it satisfies is synchronous, which SwiftData supports natively —
/// nothing here suspends, so the reconciler's no-await guarantee is preserved.
@MainActor
final class SwiftDataLedgerStore: CoinLedgerStore {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    nonisolated func allEntries() throws -> [LedgerEntry] {
        try MainActor.assumeIsolated {
            let descriptor = FetchDescriptor<LedgerEntryRecord>(
                sortBy: [SortDescriptor(\.at, order: .forward)]
            )
            return try context.fetch(descriptor).map(\.value)
        }
    }

    nonisolated func append(_ entries: [LedgerEntry]) throws {
        try MainActor.assumeIsolated {
            for entry in entries {
                context.insert(LedgerEntryRecord(entry))
            }
            // One save for the batch, so a partially-written spend/refund pair cannot be persisted.
            // The reconciler's contract is that append is atomic across the batch.
            try context.save()
        }
    }

    nonisolated func hasEntries(forIntent intentID: UUID) throws -> Bool {
        try MainActor.assumeIsolated {
            // Predicate on the optional intentID. Deliberately a count-limited fetch rather than
            // loading rows we do not need.
            var descriptor = FetchDescriptor<LedgerEntryRecord>(
                predicate: #Predicate { $0.intentID == intentID }
            )
            descriptor.fetchLimit = 1
            return try !context.fetch(descriptor).isEmpty
        }
    }
}

/// Owns the SwiftData stack.
///
/// Two decisions worth stating, because both are the opposite of the template default:
///
/// * **The container lives in the App Group**, so the debug panel and any future in-app history can
///   read it from the same place everything else lives.
/// * **A failure to open is NOT fatal.** `fatalError` here would mean a corrupt history bricks the
///   app — including the teardown path, which must always work. Instead the ledger becomes
///   unavailable, `LedgerReconciler` skips folding, and shielding continues to work correctly
///   because it never depended on this store.
///
/// One honest limitation: SwiftData can *trap* rather than throw on a malformed configuration, and a
/// trap cannot be caught. The catch below therefore covers genuine open failures — a corrupt or
/// unreadable store — but not programmer error in the schema itself. That distinction cost a
/// launch-crash here, caught by the UI suite.
@MainActor
enum LumoPersistence {

    private(set) static var container: ModelContainer?

    /// Non-throwing on purpose. See the note above about not bricking the app.
    static func start() {
        guard container == nil else { return }
        let schema = Schema(LumoSchemaV1.models)

        // Only ask for the App Group container if it actually exists. SwiftData TRAPS rather than
        // throwing when the group container is unavailable, so `do/catch` cannot rescue it — and it
        // is genuinely unavailable in an unsigned Simulator build, where entitlements are not
        // applied. UserDefaults suites keep working in that situation, which is why nothing else
        // noticed and this crashed on launch.
        //
        // Falling back to the app-local container is also the right behaviour on device: a ledger
        // in the wrong place is recoverable, whereas an app that cannot start is not — and the
        // teardown path must always work.
        let hasGroupContainer = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil

        let configuration: ModelConfiguration = hasGroupContainer
            ? ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(AppGroup.identifier),
                // No CloudKit: SwiftData+CloudKit forces every property optional and bans unique
                // constraints, and the product has no account or sync story to justify that cost.
                cloudKitDatabase: .none
            )
            : ModelConfiguration(schema: schema, cloudKitDatabase: .none)

        if !hasGroupContainer {
            LumoStackDiagnostics.record(
                "persistence.noGroupContainer", detail: "using app-local store")
        }
        do {
            // No migrationPlan until a v2 actually exists. Passing a plan with one schema and zero
            // stages makes SwiftData TRAP inside ModelContainer.init — and a trap cannot be caught,
            // which defeats the whole point of the do/catch below. The VersionedSchema type is kept
            // so v1's shape is frozen and the plan can be reintroduced alongside a real stage.
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            container = nil
            LumoStackDiagnostics.record(
                "persistence.openFailed",
                detail: String(describing: error).prefix(100).description
            )
        }
    }

    /// `nil` when the store could not be opened, so callers must handle its absence rather than
    /// assume a working ledger.
    static func ledgerStore() -> SwiftDataLedgerStore? {
        start()
        guard let container else { return nil }
        return SwiftDataLedgerStore(context: ModelContext(container))
    }
}


// MARK: - Launch-time reconciliation

@MainActor
extension LumoPersistence {

    /// Ingests the spend journal into the durable ledger and reconciles the two tiers.
    ///
    /// **App only**, and after `LumoStack.startUp()`. An extension can settle a spend while the app
    /// is not running, so the journal is the only durable record of that transaction until this runs —
    /// which is exactly why only the app prunes it.
    ///
    /// Runs under the same cross-process lock as everything else that mutates shared state, or a
    /// concurrent monitor callback could overwrite the corrected wallet.
    @discardableResult
    static func reconcileLedger() -> LedgerReconciler.Outcome? {
        guard let ledger = ledgerStore(), let store = LumoStack.stateStore(for: .app) else {
            // No ledger means no fold, and shielding is unaffected because it never depended on it.
            return nil
        }
        let diagnostics = LumoStack.diagnostics(for: .app)
        let reconciler = LedgerReconciler(
            ledger: ledger, clock: SystemNow(), diagnostics: diagnostics)

        return LumoStack.lock(for: .app).withLock {
            guard var state = try? store.loadState() else { return nil }
            let outcome = reconciler.reconcile(state: &state)
            // Only write when something actually changed, so a steady-state launch stays a pure read.
            if outcome.rowsWritten > 0 || outcome.didCorrect || outcome.prunedJournalEntries > 0 {
                try? store.saveState(state)
                diagnostics.record(
                    "ledger.reconciled",
                    detail: "rows \(outcome.rowsWritten) pruned \(outcome.prunedJournalEntries) corrected \(outcome.didCorrect)"
                )
            }
            return outcome
        } ?? nil
    }
}

// MARK: - Pricing personalisation

@MainActor
extension LumoPersistence {

    /// Reprices the economy once the baseline ladder has enough to say.
    ///
    /// Lives here rather than in a view because it needs both halves of the ratio, and they come
    /// from different tiers: the scroll side is inferred from threshold firings in shared state,
    /// while the habit side is measured directly from completed sessions in SwiftData. Only the app
    /// can see both.
    ///
    /// Runs on foreground, and is a no-op on almost every run — `PolicyPersonalizer` compares the
    /// price-setting fields rather than the whole value, so a policy that has already absorbed this
    /// measurement is left alone instead of being rewritten (and its fingerprint churned) on every
    /// launch. The extensions validate against that fingerprint.
    @discardableResult
    static func personalisePricing(now: Date = Date()) -> PolicyPersonalizer.Outcome? {
        guard let store = LumoStack.stateStore(for: .app),
              let state = try? store.loadState()
        else { return nil }

        let calibration = state.baseline
        guard calibration.isReady else {
            return .stillCalibrating(daysRemaining: calibration.daysRemaining)
        }

        let outcome = PolicyPersonalizer.evaluate(
            calibration: calibration,
            current: store.loadPolicy(),
            habitMinutesPerDay: habitMinutesPerDay(over: calibration.observedDays, now: now),
            now: now
        )

        if case let .repriced(policy) = outcome {
            try? store.savePolicy(policy)
            LumoStackDiagnostics.record(
                "policy.personalised",
                detail: "scroll \(Int(policy.baseline.scrollMinutesPerDay))m habit \(Int(policy.baseline.habitMinutesPerDay))m ratio \(String(format: "%.2f", policy.requiredRatio))"
            )
        }
        return outcome
    }

    /// Mean completed-habit minutes per day over the calibration window.
    ///
    /// Only sessions inside the window count. Including older history would pair a habit average
    /// from one period with a scroll measurement from another, and the ratio between two different
    /// weeks is not a ratio of anything.
    private static func habitMinutesPerDay(over days: Int, now: Date) -> Double {
        guard days > 0, let container else { return 0 }
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SessionRecord>(
            predicate: #Predicate { $0.endedAt >= cutoff }
        )
        guard let sessions = try? context.fetch(descriptor) else { return 0 }
        return PolicyPersonalizer.habitMinutesPerDay(
            completedSessionMinutes: sessions.map { $0.activeSeconds / 60 },
            overDays: days
        )
    }
}

// MARK: - The weekly grant

@MainActor
extension LumoPersistence {

    /// Issues the weekly house allowance if a new week has started.
    ///
    /// **This had no caller until now**, which meant the granted half of the wallet was always
    /// zero and the economy had no floor. The grant is what makes "never trap the user" true in the
    /// economy rather than only in the teardown button: there is always some way out of a shield,
    /// even in a week where nothing got done.
    ///
    /// Rolling a week also EXPIRES the unspent remainder. That is the loss-framed half of ACTIVE
    /// REWARD — the only design in the literature whose effect survived after incentives stopped —
    /// and it is only defensible because it touches house money exclusively. Earned coins are never
    /// expired, never deducted, never clawed back.
    @discardableResult
    static func issueWeeklyGrantIfNeeded(now: Date = Date()) -> GrantCycle.Outcome? {
        guard let store = LumoStack.stateStore(for: .app) else { return nil }
        let policy = store.loadPolicy()

        var outcome: GrantCycle.Outcome?
        LumoStack.lock(for: .app).withLock {
            guard var state = try? store.loadState() else { return }
            let result = GrantCycle.issueIfNeeded(state: &state, policy: policy, now: now)
            // A no-op on all but one launch a week, so nothing is written on the other six days.
            guard result.issued > 0 || result.expired > 0 else {
                outcome = result
                return
            }
            try? store.saveState(state)

            var rows: [LedgerEntry] = []
            if result.expired > 0 {
                rows.append(LedgerEntry(
                    at: now, kind: .grantExpired, grantedDelta: -result.expired,
                    note: "unspent allowance"))
            }
            if result.issued > 0 {
                rows.append(LedgerEntry(
                    at: now, kind: .grantIssued, grantedDelta: result.issued, note: "weekly"))
            }
            if let ledger = ledgerStore(), !rows.isEmpty { try? ledger.append(rows) }

            // Forfeiture is a harm signal, not a revenue one: most of the allowance expiring unused
            // means the economy is unreachable for this user and earning is too slow.
            if result.expired > 0 {
                var metrics = store.loadHarm()
                metrics.grantForfeited += result.expired
                try? store.saveHarm(metrics)
            }

            LumoStackDiagnostics.record(
                "grant.cycled", detail: "issued \(result.issued) expired \(result.expired)")
            outcome = result
        }
        return outcome
    }
}
