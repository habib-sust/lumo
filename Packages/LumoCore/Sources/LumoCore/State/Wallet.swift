import Foundation

/// The coin balance, split into two pots that behave differently on purpose.
///
/// The split is structural rather than a policy flag, because the distinction is the
/// whole reason the economy is defensible:
///
/// - `granted` is house money — a weekly allowance Lumo issues. Deducting from it on a
///   missed day is a designed, anticipated, reference-point-resetting mechanic. This is
///   the ACTIVE REWARD structure, the only loss-framed design whose behavioural effect
///   survived after the incentive stopped.
/// - `earned` is the user's own, paid for with real effort. Clawing it back reads as
///   betrayal and specifically harms the most engaged users. Asking people to risk
///   something already theirs collapses acceptance from ~90% to ~14%.
///
/// So: misses touch `granted` only. `earned` decreases only when the user spends it.
/// That invariant is enforced by `Wallet`'s API and covered by a property test.
public struct Wallet: Codable, Sendable, Equatable {
    /// House money. Miss deductions land here, and only here.
    public private(set) var granted: Int

    /// The user's own coins. Never reduced except by their own spend.
    public private(set) var earned: Int

    public var total: Int { granted + earned }

    public init(granted: Int = 0, earned: Int = 0) {
        self.granted = max(0, granted)
        self.earned = max(0, earned)
    }

    public static let zero = Wallet()

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        granted = max(0, try c.decodeIfPresent(Int.self, forKey: .granted) ?? 0)
        earned = max(0, try c.decodeIfPresent(Int.self, forKey: .earned) ?? 0)
    }
}

// MARK: - Mutations
//
// Every mutation is a named method rather than a settable property, so that "who is
// allowed to reduce `earned`?" has exactly one answer that can be read off this file.

extension Wallet {

    /// Issues the weekly house allowance.
    public mutating func issueGrant(_ amount: Int) {
        guard amount > 0 else { return }
        granted += amount
    }

    /// Credits coins the user worked for.
    public mutating func credit(earned amount: Int) {
        guard amount > 0 else { return }
        earned += amount
    }

    /// Deducts for a missed day. Touches `granted` only, floored at zero.
    ///
    /// Returns how much was actually deducted, which may be less than requested — a user
    /// who has already run their grant down to zero cannot go negative, and must never be
    /// pushed into `earned`.
    @discardableResult
    public mutating func deductForMiss(_ amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        let taken = min(amount, granted)
        granted -= taken
        return taken
    }

    /// Spends `amount`, drawing from `granted` first.
    ///
    /// Granted-first matters: unspent grant expires at the end of the week, so spending it
    /// first means the user loses less. It also keeps hard-won `earned` coins on the books
    /// where the user can see them, which is the sunk-cost weight that makes deleting Lumo
    /// feel like a loss — the only real defence against uninstall, since no API prevents it.
    ///
    /// Returns `nil` and leaves the wallet untouched if the balance is insufficient, so a
    /// failed spend can never partially debit.
    public mutating func spend(_ amount: Int) -> Debit? {
        guard amount > 0 else { return Debit(granted: 0, earned: 0) }
        guard total >= amount else { return nil }

        let fromGranted = min(amount, granted)
        let fromEarned = amount - fromGranted
        granted -= fromGranted
        earned -= fromEarned
        return Debit(granted: fromGranted, earned: fromEarned)
    }

    /// Restores an exact debit. Used by spend rollback so a refund reproduces the original
    /// grant/earned shape rather than dumping everything into one pot.
    public mutating func refund(_ debit: Debit) {
        granted += max(0, debit.granted)
        earned += max(0, debit.earned)
    }

    /// Expires whatever is left of the weekly grant. `earned` is untouched.
    @discardableResult
    public mutating func expireGrant() -> Int {
        let expired = granted
        granted = 0
        return expired
    }

    /// How a spend was split across the two pots. Recorded on the spend intent so a
    /// rollback is exact.
    public struct Debit: Codable, Sendable, Equatable {
        public var granted: Int
        public var earned: Int

        public var total: Int { granted + earned }

        public init(granted: Int, earned: Int) {
            self.granted = granted
            self.earned = earned
        }

        public static let none = Debit(granted: 0, earned: 0)

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            granted = try c.decodeIfPresent(Int.self, forKey: .granted) ?? 0
            earned = try c.decodeIfPresent(Int.self, forKey: .earned) ?? 0
        }
    }
}

/// Per-week bookkeeping for the grant cycle.
public struct WeekLedger: Codable, Sendable, Equatable {
    /// Local midnight on Monday.
    public var weekStart: Date
    public var grantIssued: Int
    public var missesThisWeek: Int
    public var grantDeductedThisWeek: Int

    /// Set when a day is missed, consumed by the next completed session.
    ///
    /// A comeback bonus for returning after a lapse was the single most effective of 53
    /// interventions tested on 61,293 people — and the $0.09 version beat the $1.75 one.
    /// Recovery is built before streaks for that reason.
    public var comebackBonusArmed: Bool

    public init(
        weekStart: Date = Date(timeIntervalSince1970: 0),
        grantIssued: Int = 0,
        missesThisWeek: Int = 0,
        grantDeductedThisWeek: Int = 0,
        comebackBonusArmed: Bool = false
    ) {
        self.weekStart = weekStart
        self.grantIssued = grantIssued
        self.missesThisWeek = missesThisWeek
        self.grantDeductedThisWeek = grantDeductedThisWeek
        self.comebackBonusArmed = comebackBonusArmed
    }

    public static let empty = WeekLedger()

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weekStart = try c.decodeIfPresent(Date.self, forKey: .weekStart) ?? Date(timeIntervalSince1970: 0)
        grantIssued = try c.decodeIfPresent(Int.self, forKey: .grantIssued) ?? 0
        missesThisWeek = try c.decodeIfPresent(Int.self, forKey: .missesThisWeek) ?? 0
        grantDeductedThisWeek = try c.decodeIfPresent(Int.self, forKey: .grantDeductedThisWeek) ?? 0
        comebackBonusArmed = try c.decodeIfPresent(Bool.self, forKey: .comebackBonusArmed) ?? false
    }
}
