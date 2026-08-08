import Foundation

/// Why coins moved.
///
/// Every kind carries its own sign convention, and the split between `granted` and `earned` is
/// preserved on every row — because the wallet's central invariant is that a miss may only consume
/// house money. A ledger that recorded a single total would make that invariant unauditable after
/// the fact.
public enum LedgerKind: String, Codable, Sendable, CaseIterable {
    /// Weekly house allowance issued.
    case grantIssued
    /// Unspent allowance expired at the week boundary.
    case grantExpired
    /// A missed day. Only ever reduces `granted`.
    case missDeduction
    /// Habit completed to its standard.
    case habitEarned
    /// Returning after a lapse.
    case comebackBonus
    /// Occasional unexpected top-up.
    case surpriseBonus
    /// The user bought an unlock window.
    case spend
    /// A spend rolled back — refunds restore the exact granted/earned shape.
    case refund
    /// A free emergency unlock. Records the event at zero cost, so reliance is visible.
    case emergencyUnlock
    /// Written when the folded ledger disagrees with the live wallet.
    ///
    /// Never silent: if the two ever diverge, the difference is recorded as a row rather than
    /// papered over, so the history stays a true account of how the balance got where it is.
    case recoveryAdjustment
}

/// One immutable row in the durable coin history.
///
/// This is the audit trail the corruption-recovery ladder depends on. When both the live state and
/// its backup fail to decode, the wallet is rebuilt by folding these rows — which is the only reason
/// the store is allowed to refuse rather than invent an empty balance. Losing the user's coins would
/// look exactly like a bug that ate them.
public struct LedgerEntry: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let at: Date
    public let kind: LedgerKind
    /// Change to the house-money pot. Negative for deductions and expiry.
    public let grantedDelta: Int
    /// Change to the user's own pot. Negative only for a spend.
    public let earnedDelta: Int
    /// Links a row to the spend that produced it, so ingestion is idempotent.
    public let intentID: UUID?
    /// Short human-readable context for the debug panel. Never used for logic.
    public let note: String

    public init(
        id: UUID = UUID(),
        at: Date,
        kind: LedgerKind,
        grantedDelta: Int = 0,
        earnedDelta: Int = 0,
        intentID: UUID? = nil,
        note: String = ""
    ) {
        self.id = id
        self.at = at
        self.kind = kind
        self.grantedDelta = grantedDelta
        self.earnedDelta = earnedDelta
        self.intentID = intentID
        self.note = String(note.prefix(120))
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        at = try c.decodeIfPresent(Date.self, forKey: .at) ?? Date(timeIntervalSince1970: 0)
        kind = try c.decodeIfPresent(LedgerKind.self, forKey: .kind) ?? .recoveryAdjustment
        grantedDelta = try c.decodeIfPresent(Int.self, forKey: .grantedDelta) ?? 0
        earnedDelta = try c.decodeIfPresent(Int.self, forKey: .earnedDelta) ?? 0
        intentID = try c.decodeIfPresent(UUID.self, forKey: .intentID)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

extension Array where Element == LedgerEntry {

    /// Rebuilds a wallet from the whole history.
    ///
    /// The clamp at zero is deliberate: a corrupt or partially-written history could sum negative,
    /// and a negative balance is meaningless to the user. Clamping loses information, but the
    /// alternative — surfacing a negative wallet — is worse, and `LedgerReconciler` records the
    /// discrepancy as its own row so nothing is hidden.
    public func foldWallet() -> Wallet {
        var granted = 0
        var earned = 0
        for entry in self {
            granted += entry.grantedDelta
            earned += entry.earnedDelta
        }
        return Wallet(granted: Swift.max(0, granted), earned: Swift.max(0, earned))
    }

    /// Total coins the user has ever genuinely earned.
    ///
    /// Excludes house money entirely, so it reads as a record of effort rather than of allowance.
    /// Intended for the hearth, where conflating the two would quietly cheapen the number.
    public var lifetimeEarned: Int {
        filter { $0.earnedDelta > 0 }.reduce(0) { $0 + $1.earnedDelta }
    }

    public func entries(for intentID: UUID) -> [LedgerEntry] {
        filter { $0.intentID == intentID }
    }
}
