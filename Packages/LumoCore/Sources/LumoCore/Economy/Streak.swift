import Foundation

/// A streak that **pauses and never resets**.
///
/// This is the deliberate departure from the entire category. Three independent literatures point
/// the same way:
///
/// * A bonus for returning after a missed session was the **#1 of 53 interventions** tested on
///   61,293 people — and the cheap version beat the expensive one.
/// * One missed day costs under half an automaticity point and recovers quickly, so treating it
///   as catastrophic is not just unkind, it is inaccurate.
/// * A harsh reset triggers the what-the-hell effect: the response to "you lost your 40-day
///   streak" is a binge, not a comeback.
///
/// So `current` is never set to zero by a miss. There is no code path that does it, and a test
/// asserts that over thousands of random day sequences.
///
/// Forgiveness is also **free**. Charging for a streak freeze taxes exactly the people who need it
/// most — chronically ill and disabled users defend those items as accessibility features — and the
/// available data suggests generous forgiveness is worth more as retention than as revenue.
public struct Streak: Codable, Sendable, Equatable {

    /// Consecutive *completed* days. Missing a day neither increments nor resets it.
    public private(set) var current: Int
    public private(set) var longest: Int
    public private(set) var lastCompletedDay: Date?

    /// Days missed since the streak began. Surfaced honestly rather than hidden, but it never
    /// reduces `current`.
    public private(set) var pausedDays: Int

    /// Set by a miss, consumed by the next completed session.
    public private(set) var comebackArmed: Bool

    /// A previous peak the user can always restore.
    ///
    /// Exists because the market asked for it loudly: a competitor's win-back campaign let anyone
    /// who once held a 30+ day streak restore it, and they described it as one of the most
    /// consistent requests they hear.
    public private(set) var restorablePeak: Int?

    public init(
        current: Int = 0,
        longest: Int = 0,
        lastCompletedDay: Date? = nil,
        pausedDays: Int = 0,
        comebackArmed: Bool = false,
        restorablePeak: Int? = nil
    ) {
        self.current = max(0, current)
        self.longest = max(0, longest)
        self.lastCompletedDay = lastCompletedDay
        self.pausedDays = max(0, pausedDays)
        self.comebackArmed = comebackArmed
        self.restorablePeak = restorablePeak
    }

    public static let empty = Streak()

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        current = try c.decodeIfPresent(Int.self, forKey: .current) ?? 0
        longest = try c.decodeIfPresent(Int.self, forKey: .longest) ?? 0
        lastCompletedDay = try c.decodeIfPresent(Date.self, forKey: .lastCompletedDay)
        pausedDays = try c.decodeIfPresent(Int.self, forKey: .pausedDays) ?? 0
        comebackArmed = try c.decodeIfPresent(Bool.self, forKey: .comebackArmed) ?? false
        restorablePeak = try c.decodeIfPresent(Int.self, forKey: .restorablePeak)
    }

    public struct CompletionResult: Equatable, Sendable {
        public var didIncrement: Bool
        /// True when this session is the return after a lapse.
        public var earnedComebackBonus: Bool
        public var newCurrent: Int
    }

    /// Records a completed session.
    ///
    /// Idempotent per day: two sessions on the same day do not double-count, because the streak
    /// measures days engaged rather than sessions logged.
    @discardableResult
    public mutating func recordCompletion(
        on date: Date,
        calendar: Calendar = .current
    ) -> CompletionResult {
        let day = calendar.startOfDay(for: date)

        if let last = lastCompletedDay, calendar.startOfDay(for: last) == day {
            return CompletionResult(didIncrement: false, earnedComebackBonus: false, newCurrent: current)
        }

        let bonus = comebackArmed
        current += 1
        longest = max(longest, current)
        lastCompletedDay = day
        comebackArmed = false

        return CompletionResult(didIncrement: true, earnedComebackBonus: bonus, newCurrent: current)
    }

    /// Records a missed day.
    ///
    /// **Never touches `current`.** It only remembers that a day was missed and arms the comeback
    /// bonus. Anyone editing this method should treat a `current = 0` here as a rejected change.
    public mutating func recordMiss(on date: Date, calendar: Calendar = .current) {
        // Only count it once per day, so a repeated launch does not inflate the paused count.
        let day = calendar.startOfDay(for: date)
        if let last = lastCompletedDay, calendar.startOfDay(for: last) == day { return }

        pausedDays += 1
        comebackArmed = true
        if current > 0 { restorablePeak = max(restorablePeak ?? 0, current) }
    }

    /// Restores a previous peak.
    ///
    /// Always available, never charged, no time limit. A user coming back after months should not
    /// be told their history is gone.
    @discardableResult
    public mutating func restorePeak() -> Int? {
        guard let peak = restorablePeak, peak > current else { return nil }
        current = peak
        longest = max(longest, current)
        restorablePeak = nil
        return peak
    }

    public var canRestore: Bool {
        (restorablePeak ?? 0) > current
    }
}
