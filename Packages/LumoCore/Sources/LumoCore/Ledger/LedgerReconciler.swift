import Foundation

/// The durable coin history.
///
/// Synchronous, like every seam in this package — `reconcile()` runs on the app's foreground path
/// and nothing it depends on may suspend. SwiftData's `ModelContext` operations are synchronous, so
/// this costs nothing.
public protocol CoinLedgerStore: Sendable {
    /// All rows, oldest first.
    func allEntries() throws -> [LedgerEntry]
    /// Appends rows. Must be atomic across the batch.
    func append(_ entries: [LedgerEntry]) throws
    /// Whether any row already references this spend, so ingestion can be idempotent.
    func hasEntries(forIntent intentID: UUID) throws -> Bool
}

/// Bridges the hot cross-process state (Tier 1) and the durable ledger (Tier 2).
///
/// The two tiers exist for different reasons and neither can replace the other. Tier 1 is a small
/// blob that four processes read on every callback under a 6 MB ceiling. Tier 2 is a full audit
/// trail that only the app opens. The spend journal is the write-ahead log that connects them: an
/// extension can settle a spend while the app is not running, so the journal is the *only* durable
/// record of that transaction until the app next launches and ingests it.
///
/// This is why only the app may prune the journal — pruning on settle would destroy the record
/// before it was ever written down.
public struct LedgerReconciler: Sendable {

    let ledger: any CoinLedgerStore
    let clock: any NowProviding
    let diagnostics: any Diagnosing

    public init(
        ledger: any CoinLedgerStore,
        clock: any NowProviding = SystemNow(),
        diagnostics: any Diagnosing = NullDiagnostics()
    ) {
        self.ledger = ledger
        self.clock = clock
        self.diagnostics = diagnostics
    }

    public struct Outcome: Equatable, Sendable {
        public var ingestedIntents: Int = 0
        public var rowsWritten: Int = 0
        /// Non-zero when the folded ledger disagreed with the live wallet.
        public var grantedCorrection: Int = 0
        public var earnedCorrection: Int = 0
        public var prunedJournalEntries: Int = 0

        public var didCorrect: Bool { grantedCorrection != 0 || earnedCorrection != 0 }
    }

    /// Ingest, then fold, then compare — in that order.
    ///
    /// Ordering matters: folding before ingestion would compare the wallet against a history that is
    /// knowingly incomplete, and "correct" it to a number that is simply out of date.
    ///
    /// On divergence **the ledger wins**, because it is the only append-only record; the live blob is
    /// mutable, cached and rewritten by four processes. The correction is written as its own
    /// `recoveryAdjustment` row rather than applied silently, so the history remains a truthful
    /// account of how the balance reached its current value.
    @discardableResult
    public func reconcile(state: inout SharedState) -> Outcome {
        var outcome = Outcome()
        let now = clock.now

        // ---- Ingest settled and rolled-back journal entries ----
        //
        // Rows are built first and the intents are marked ONLY after a successful append. Marking
        // before writing meant a failed append still flagged the intent as ingested, so the retry
        // never happened and the spend vanished from the audit trail permanently.
        var rows: [LedgerEntry] = []
        var indicesToMark: [Int] = []

        for index in state.journal.indices {
            let intent = state.journal[index]
            guard intent.phase == .settled || intent.phase == .rolledBack else { continue }
            guard !intent.ingestedIntoLedger else { continue }

            // Idempotent even across a crash between writing rows and marking the intent — the
            // realistic window, and without this check the user would be charged twice.
            if (try? ledger.hasEntries(forIntent: intent.id)) == true {
                state.journal[index].ingestedIntoLedger = true
                continue
            }

            switch intent.phase {
            case .settled:
                rows.append(LedgerEntry(
                    at: intent.createdAt,
                    kind: intent.origin == .emergency ? .emergencyUnlock : .spend,
                    // Negated: the intent records what was TAKEN, the ledger records the change.
                    grantedDelta: -intent.debit.granted,
                    earnedDelta: -intent.debit.earned,
                    intentID: intent.id,
                    note: "slot \(intent.bucket.slot), \(Int(intent.windowSeconds / 60))m"
                ))
            case .rolledBack:
                // Only write a refund if coins actually moved. An intent that never reached `armed`
                // has a zero debit, and a zero-value row would be noise in the audit trail.
                if intent.debit.total > 0 {
                    rows.append(LedgerEntry(
                        at: intent.createdAt,
                        kind: .refund,
                        grantedDelta: intent.debit.granted,
                        earnedDelta: intent.debit.earned,
                        intentID: intent.id,
                        note: "rolled back slot \(intent.bucket.slot)"
                    ))
                }
            case .intended, .armed:
                continue
            }
            indicesToMark.append(index)
        }

        if rows.isEmpty {
            // Nothing to write, but there may still be zero-value rollbacks to acknowledge.
            for index in indicesToMark {
                state.journal[index].ingestedIntoLedger = true
                outcome.ingestedIntents += 1
            }
        } else {
            guard (try? ledger.append(rows)) != nil else {
                // Leave the intents un-ingested so the next launch retries. Losing the record would
                // be worse than repeating the attempt.
                diagnostics.record("ledger.appendFailed", detail: "\(rows.count) row(s)")
                return outcome
            }
            outcome.rowsWritten = rows.count
            for index in indicesToMark {
                state.journal[index].ingestedIntoLedger = true
                outcome.ingestedIntents += 1
            }
        }

        // ---- Fold and compare ----
        if let all = try? ledger.allEntries() {
            // An empty ledger is a legitimate first run, not a reason to zero a wallet that already
            // has coins in it — that would be the exact betrayal the ladder exists to prevent.
            if !all.isEmpty {
                let folded = all.foldWallet()
                if folded != state.wallet {
                    outcome.grantedCorrection = folded.granted - state.wallet.granted
                    outcome.earnedCorrection = folded.earned - state.wallet.earned

                    let correction = LedgerEntry(
                        at: now,
                        kind: .recoveryAdjustment,
                        note: "live g\(state.wallet.granted)/e\(state.wallet.earned) → ledger g\(folded.granted)/e\(folded.earned)"
                    )
                    try? ledger.append([correction])
                    state.wallet = folded
                    diagnostics.record("ledger.corrected", detail: correction.note)
                }
            }
        } else {
            diagnostics.record("ledger.unreadable", detail: "skipping fold")
        }

        // ---- Prune, app-only ----
        outcome.prunedJournalEntries = pruneJournal(&state)
        return outcome
    }

    /// Drops journal entries that are finished AND recorded.
    ///
    /// Both conditions are required. Pruning on settle alone would destroy the only durable trace of
    /// an extension-side spend before the app ever wrote it down.
    private func pruneJournal(_ state: inout SharedState) -> Int {
        let before = state.journal.count
        state.journal.removeAll { intent in
            (intent.phase == .settled || intent.phase == .rolledBack) && intent.ingestedIntoLedger
        }
        return before - state.journal.count
    }
}
