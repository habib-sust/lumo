import Foundation
import Testing
@testable import LumoCore

/// T-LEDGER-INGEST-01…14.
///
/// The ledger is what makes the corruption-recovery ladder honest. `DefaultsStateStore` is allowed to
/// THROW rather than invent an empty wallet precisely because these rows exist to rebuild from —
/// without them, refusing would just be a different way of losing the user's coins.
@Suite("Durable ledger and Tier1↔Tier2 reconciliation")
struct LedgerTests {

    private func rig(_ entries: [LedgerEntry] = []) -> (FakeLedgerStore, MutableNow, RecordingDiagnostics, LedgerReconciler) {
        let store = FakeLedgerStore(entries: entries)
        let clock = MutableNow(.fixture)
        let diag = RecordingDiagnostics()
        return (store, clock, diag, LedgerReconciler(ledger: store, clock: clock, diagnostics: diag))
    }

    private func settledIntent(
        id: UUID = UUID(),
        slot: Int = 0,
        granted: Int,
        earned: Int,
        phase: SpendPhase = .settled,
        origin: UnlockWindow.Origin = .purchased
    ) -> SpendIntent {
        SpendIntent(
            id: id, bucket: BucketID(slot: slot), phase: phase,
            createdAt: .fixture, activityName: "lumo.unlock.\(id.uuidString)",
            price: granted + earned, usageBudget: 900, windowSeconds: 900,
            tierIndex: 0, policyFingerprint: "fp-1",
            debit: .init(granted: granted, earned: earned),
            balanceBefore: .zero, ingestedIntoLedger: false, origin: origin
        )
    }

    // MARK: - Folding

    @Test("Folding an empty ledger yields a zero wallet")
    func foldEmpty() {
        #expect([LedgerEntry]().foldWallet() == .zero)
    }

    @Test("Folding reproduces a wallet exactly from deltas")
    func foldReproducesWallet() {
        let entries = [
            LedgerEntry(at: .fixture, kind: .grantIssued, grantedDelta: 140),
            LedgerEntry(at: .fixture, kind: .habitEarned, earnedDelta: 20),
            LedgerEntry(at: .fixture, kind: .missDeduction, grantedDelta: -20),
            LedgerEntry(at: .fixture, kind: .spend, grantedDelta: -30, earnedDelta: -5),
        ]
        #expect(entries.foldWallet() == Wallet(granted: 90, earned: 15))
    }

    @Test("A negative sum clamps rather than surfacing a negative balance")
    func foldClampsNegative() {
        // A negative wallet is meaningless to the user. Clamping loses information, but the
        // reconciler records the discrepancy as its own row, so nothing is hidden.
        let entries = [LedgerEntry(at: .fixture, kind: .spend, grantedDelta: -50, earnedDelta: -10)]
        #expect(entries.foldWallet() == .zero)
    }

    @Test("Lifetime earned counts only the user's own coins")
    func lifetimeEarnedExcludesHouseMoney() {
        // Conflating allowance with effort would quietly cheapen the number the hearth shows.
        let entries = [
            LedgerEntry(at: .fixture, kind: .grantIssued, grantedDelta: 500),
            LedgerEntry(at: .fixture, kind: .habitEarned, earnedDelta: 20),
            LedgerEntry(at: .fixture, kind: .habitEarned, earnedDelta: 30),
            LedgerEntry(at: .fixture, kind: .spend, earnedDelta: -40),
        ]
        #expect(entries.lifetimeEarned == 50, "spends must not reduce a lifetime total")
    }

    // MARK: - Ingestion

    @Test("A settled spend becomes a negated ledger row")
    func settledSpendIsIngested() {
        let (store, _, _, reconciler) = rig()
        var state = SharedState(wallet: Wallet(granted: 70, earned: 0))
        state.journal = [settledIntent(granted: 30, earned: 0)]

        let outcome = reconciler.reconcile(state: &state)

        #expect(outcome.ingestedIntents == 1)
        let row = store.rows(of: .spend).first
        // The intent records what was TAKEN; the ledger records the CHANGE.
        #expect(row?.grantedDelta == -30)
        #expect(state.journal.isEmpty, "an ingested intent is pruned")
    }

    @Test("Ingestion is idempotent across repeated reconciles")
    func ingestionIsIdempotent() {
        let (store, _, _, reconciler) = rig()
        var state = SharedState(wallet: Wallet(granted: 100, earned: 0))
        state.journal = [settledIntent(granted: 10, earned: 0)]

        reconciler.reconcile(state: &state)
        let afterFirst = store.entries.count
        reconciler.reconcile(state: &state)

        #expect(store.entries.count == afterFirst, "a second pass must not double-write")
    }

    @Test("Ingestion is idempotent even if the intent flag was never persisted")
    func ingestionSurvivesACrashBetweenWriteAndFlag() {
        // The realistic crash window: rows land, then the process dies before the intent is marked.
        // Without the intentID check this would double-charge the user on next launch.
        let intentID = UUID()
        let existing = LedgerEntry(
            at: .fixture, kind: .spend, grantedDelta: -25, intentID: intentID)
        let (store, _, _, reconciler) = rig([existing])

        var state = SharedState(wallet: Wallet(granted: 75, earned: 0))
        state.journal = [settledIntent(id: intentID, granted: 25, earned: 0)]

        reconciler.reconcile(state: &state)

        #expect(store.rows(of: .spend).count == 1, "must not write a second row for the same spend")
    }

    @Test("A rolled-back spend with a real debit becomes a refund row")
    func rollbackBecomesRefund() {
        let (store, _, _, reconciler) = rig()
        var state = SharedState(wallet: Wallet(granted: 100, earned: 0))
        state.journal = [settledIntent(granted: 20, earned: 5, phase: .rolledBack)]

        reconciler.reconcile(state: &state)

        let refund = store.rows(of: .refund).first
        #expect(refund?.grantedDelta == 20)
        #expect(refund?.earnedDelta == 5, "a refund must restore the exact split")
    }

    @Test("A rolled-back spend that never charged writes NO row")
    func zeroValueRollbackWritesNothing() {
        // An intent that never reached `armed` has a zero debit. A zero-value row would be noise in
        // an audit trail whose whole value is being readable.
        let (store, _, _, reconciler) = rig()
        var state = SharedState()
        state.journal = [settledIntent(granted: 0, earned: 0, phase: .rolledBack)]

        reconciler.reconcile(state: &state)

        #expect(store.rows(of: .refund).isEmpty)
        #expect(state.journal.isEmpty, "but it is still pruned")
    }

    @Test("An emergency unlock is recorded as its own kind")
    func emergencyIsDistinguishable() {
        // Free, but visible. Heavy reliance means the strictness tier is wrong for this user, which
        // is a signal to act on rather than hide.
        let (store, _, _, reconciler) = rig()
        var state = SharedState()
        state.journal = [settledIntent(granted: 0, earned: 0, origin: .emergency)]

        reconciler.reconcile(state: &state)
        #expect(store.rows(of: .emergencyUnlock).count == 1)
    }

    @Test("In-flight intents are neither ingested nor pruned")
    func inFlightIntentsSurvive() {
        // `armed` means coins are taken and a timer exists but the user has not received access.
        // Recording or pruning it here would lose the only evidence needed to finish or refund it.
        let (store, _, _, reconciler) = rig()
        var state = SharedState()
        state.journal = [
            settledIntent(granted: 5, earned: 0, phase: .armed),
            settledIntent(granted: 5, earned: 0, phase: .intended),
        ]

        reconciler.reconcile(state: &state)

        #expect(store.entries.isEmpty)
        #expect(state.journal.count == 2, "in-flight work must not be pruned")
    }

    // MARK: - Divergence

    @Test("The ledger wins when it disagrees with the live wallet")
    func ledgerWinsOnDivergence() {
        // The live blob is mutable and rewritten by four processes; the ledger is append-only. So on
        // disagreement the ledger is the record of truth.
        let entries = [
            LedgerEntry(at: .fixture, kind: .grantIssued, grantedDelta: 100),
            LedgerEntry(at: .fixture, kind: .habitEarned, earnedDelta: 40),
        ]
        let (store, _, diag, reconciler) = rig(entries)
        // A wallet that has drifted, as a torn write or a lost update would leave it.
        var state = SharedState(wallet: Wallet(granted: 10, earned: 0))

        let outcome = reconciler.reconcile(state: &state)

        #expect(state.wallet == Wallet(granted: 100, earned: 40))
        #expect(outcome.didCorrect)
        #expect(outcome.earnedCorrection == 40)
        #expect(diag.contains("ledger.corrected"))
        #expect(store.rows(of: .recoveryAdjustment).count == 1, "the correction is itself recorded")
    }

    @Test("No correction is written when the two agree")
    func agreementWritesNothing() {
        let entries = [LedgerEntry(at: .fixture, kind: .grantIssued, grantedDelta: 60)]
        let (store, _, _, reconciler) = rig(entries)
        var state = SharedState(wallet: Wallet(granted: 60, earned: 0))

        let outcome = reconciler.reconcile(state: &state)

        #expect(!outcome.didCorrect)
        #expect(store.rows(of: .recoveryAdjustment).isEmpty)
    }

    @Test("An EMPTY ledger never zeroes a wallet that has coins")
    func emptyLedgerDoesNotZeroWallet() {
        // The single most dangerous case. A first run, or a ledger that failed to open, must not be
        // read as "this user has never had any coins" — that is exactly the betrayal the recovery
        // ladder exists to prevent.
        let (store, _, _, reconciler) = rig([])
        var state = SharedState(wallet: Wallet(granted: 140, earned: 260))

        let outcome = reconciler.reconcile(state: &state)

        #expect(state.wallet == Wallet(granted: 140, earned: 260), "must not be zeroed")
        #expect(!outcome.didCorrect)
        #expect(store.entries.isEmpty)
    }

    @Test("Ingestion happens BEFORE folding")
    func ingestionPrecedesFolding() {
        // Folding first would compare the wallet against a knowingly incomplete history and
        // "correct" it to a stale number.
        let existing = [LedgerEntry(at: .fixture, kind: .grantIssued, grantedDelta: 100)]
        let (_, _, _, reconciler) = rig(existing)

        // Wallet already reflects a spend of 30 that is only in the journal so far.
        var state = SharedState(wallet: Wallet(granted: 70, earned: 0))
        state.journal = [settledIntent(granted: 30, earned: 0)]

        let outcome = reconciler.reconcile(state: &state)

        // 100 - 30 == 70, so once ingested the two agree and nothing is corrected.
        #expect(state.wallet == Wallet(granted: 70, earned: 0))
        #expect(!outcome.didCorrect, "correcting here would mean folding ran against a stale history")
    }

    // MARK: - Failure handling

    @Test("A failed append leaves intents un-ingested so the next launch retries")
    func failedAppendRetriesLater() {
        let (store, _, diag, reconciler) = rig()
        store.appendError = FakeError.unavailable
        var state = SharedState(wallet: Wallet(granted: 50, earned: 0))
        state.journal = [settledIntent(granted: 10, earned: 0)]

        reconciler.reconcile(state: &state)

        #expect(state.journal.count == 1, "must not prune what was never recorded")
        #expect(state.journal[0].ingestedIntoLedger == false)
        #expect(diag.contains("ledger.appendFailed"))
    }

    @Test("An unreadable ledger skips reconciliation rather than corrupting the wallet")
    func unreadableLedgerIsSafe() {
        let (store, _, diag, reconciler) = rig()
        store.readError = FakeError.unavailable
        var state = SharedState(wallet: Wallet(granted: 33, earned: 44))

        reconciler.reconcile(state: &state)

        #expect(state.wallet == Wallet(granted: 33, earned: 44))
        #expect(diag.contains("ledger.unreadable"))
    }

    @Test("A full spend-then-rollback cycle nets to zero in the ledger")
    func spendThenRefundNetsToZero() {
        // End-to-end arithmetic check: the audit trail must balance.
        let (store, _, _, reconciler) = rig()
        var state = SharedState(wallet: Wallet(granted: 100, earned: 0))

        let id = UUID()
        state.journal = [settledIntent(id: id, granted: 25, earned: 0)]
        reconciler.reconcile(state: &state)

        state.journal = [settledIntent(id: UUID(), granted: 25, earned: 0, phase: .rolledBack)]
        reconciler.reconcile(state: &state)

        let net = store.entries
            .filter { $0.kind == .spend || $0.kind == .refund }
            .reduce(0) { $0 + $1.grantedDelta }
        #expect(net == 0)
    }
}
