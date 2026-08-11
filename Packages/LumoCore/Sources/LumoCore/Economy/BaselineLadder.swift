import Foundation

/// One day's highest observed usage rung.
public struct DailyRung: Codable, Sendable, Equatable {
    /// Local midnight of the day observed.
    public var day: Date
    /// Highest ladder rung whose threshold fired, in minutes. `nil` means none fired.
    public var minutes: Int?

    public init(day: Date, minutes: Int?) {
        self.day = day
        self.minutes = minutes
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decodeIfPresent(Date.self, forKey: .day) ?? Date(timeIntervalSince1970: 0)
        minutes = try c.decodeIfPresent(Int.self, forKey: .minutes)
    }
}

/// Infers each user's baseline scroll time from which usage thresholds fire.
///
/// The direct route is closed: `DeviceActivityReport` renders inside a sandbox that blocks network
/// access *and* prevents data leaving the extension, so the host app can never read per-app minutes.
/// What it CAN do is register `DeviceActivityEvent` thresholds and observe which ones fire — a
/// coarse ladder rather than a number, but a real measurement rather than a guess.
///
/// This matters because response-deprivation pricing is the one genuinely unoccupied position in
/// this market, and it is worthless against a baseline nobody measured.
///
/// All four rungs live inside ONE activity, so the ladder costs nothing against the 20-activity cap.
public struct BaselineCalibration: Codable, Sendable, Equatable {

    /// Thresholds registered, in minutes. Chosen to bracket the plausible range of daily use on a
    /// handful of shielded apps without wasting rungs at either extreme.
    public static let ladderMinutes = [15, 30, 60, 120]

    /// Days of observation before prices personalise.
    ///
    /// Three, because a single day is dominated by whatever that day happened to be, and waiting a
    /// week means a week of pricing against a number that is probably wrong for this user.
    public static let requiredDays = 3

    /// Most recent days first is NOT assumed anywhere; order is normalised on insert.
    public private(set) var days: [DailyRung]
    public var startedAt: Date

    public init(startedAt: Date = Date(timeIntervalSince1970: 0), days: [DailyRung] = []) {
        self.startedAt = startedAt
        self.days = days
    }

    public static let empty = BaselineCalibration()

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date(timeIntervalSince1970: 0)
        days = try c.decodeIfPresent([DailyRung].self, forKey: .days) ?? []
    }

    /// Records the highest rung that fired on a given day.
    ///
    /// Idempotent per day and monotonic within a day: thresholds fire in ascending order as usage
    /// accrues, so a later, higher rung replaces an earlier one rather than appending.
    public mutating func record(
        highestRung minutes: Int?,
        on date: Date,
        calendar: Calendar = .current
    ) {
        let day = calendar.startOfDay(for: date)
        if let index = days.firstIndex(where: { calendar.startOfDay(for: $0.day) == day }) {
            let existing = days[index].minutes ?? -1
            if (minutes ?? -1) > existing {
                days[index] = DailyRung(day: day, minutes: minutes)
            }
        } else {
            days.append(DailyRung(day: day, minutes: minutes))
        }
        // Bounded: only the calibration window plus a little history is ever useful, and this lives
        // in a blob the monitor extension decodes under a 6 MB ceiling.
        days.sort { $0.day < $1.day }
        if days.count > 14 { days.removeFirst(days.count - 14) }
    }

    public var observedDays: Int { days.count }

    public var isReady: Bool { observedDays >= Self.requiredDays }

    /// The inferred daily scroll minutes, or `nil` when there is not enough signal.
    ///
    /// Two deliberate choices:
    ///
    /// **The low end of each bucket is used, not the midpoint.** A rung tells us usage was *at least*
    /// that much. Underestimating scroll time makes the baseline ratio larger, which makes the
    /// required price *higher* — the safe direction. Overestimating makes the contingency cheaper,
    /// and below the baseline ratio it stops reinforcing and becomes a punisher that actively
    /// suppresses the habit. A too-generous price is worse than no app at all.
    ///
    /// **`nil` when no rung ever fired**, rather than inventing a small number. A user who never
    /// reaches 15 minutes on their shielded apps has given us no signal to personalise from, and
    /// guessing would price their economy off a fabrication. Defaults are the honest fallback.
    public func inferredScrollMinutes() -> Double? {
        guard isReady else { return nil }
        let fired = days.compactMap(\.minutes)
        guard !fired.isEmpty else { return nil }

        // Median rather than mean: one unusual day — a flight, a sick day — should not move the
        // price the user lives with for a week.
        let sorted = fired.sorted()
        let median: Int
        if sorted.count % 2 == 1 {
            median = sorted[sorted.count / 2]
        } else {
            median = min(sorted[sorted.count / 2 - 1], sorted[sorted.count / 2])
        }
        return Double(median)
    }

    /// A personalised baseline, or `nil` to keep using defaults.
    ///
    /// `habitMinutesPerDay` comes from real logged sessions rather than the ladder — Lumo measures
    /// its own side directly, and only the scroll side needs inferring.
    public func baseline(
        habitMinutesPerDay: Double,
        now: Date
    ) -> Baseline? {
        guard let scroll = inferredScrollMinutes() else { return nil }
        // Guard the habit side too: a user with no completed sessions has no measurable
        // instrumental behaviour, and a zero would make the ratio zero and the price free.
        guard habitMinutesPerDay > 0 else { return nil }
        return Baseline(
            scrollMinutesPerDay: scroll,
            habitMinutesPerDay: habitMinutesPerDay,
            source: .thresholdLadder,
            observedAt: now
        )
    }

    /// Days remaining before prices personalise, for honest UI.
    public var daysRemaining: Int {
        max(0, Self.requiredDays - observedDays)
    }

    // MARK: - Event naming

    /// DeviceActivityEvent name for a ladder rung.
    ///
    /// The rung is encoded IN THE NAME because the callback carries nothing else — this is the only
    /// channel through which the measurement can travel.
    public static func eventName(forRung minutes: Int) -> String {
        "lumo.baseline.\(minutes)"
    }

    /// Parses a rung back out, or `nil` if this is not a baseline event.
    ///
    /// This is the ONE place the codebase reads meaning from an event name, and it is deliberately
    /// narrow. Elsewhere the rule holds absolutely: callbacks are triggers, never data — nothing
    /// about SHIELD state may depend on which event arrived, because spurious and duplicate
    /// deliveries are documented behaviour.
    ///
    /// The exception is legitimate because here the event's identity IS the measurement: a threshold
    /// firing at 60 minutes is the observation. A spurious fire inflates a baseline estimate
    /// slightly; it cannot open or close a shield.
    public static func rung(fromEventName name: String) -> Int? {
        let prefix = "lumo.baseline."
        guard name.hasPrefix(prefix) else { return nil }
        guard let value = Int(name.dropFirst(prefix.count)) else { return nil }
        return ladderMinutes.contains(value) ? value : nil
    }
}

extension Policy {

    /// Returns a copy repriced against a freshly measured baseline.
    ///
    /// The required ratio is re-clamped into the admissible band for the NEW baseline, so
    /// personalisation can never move a price below the punisher boundary — which is the entire
    /// point of measuring in the first place.
    public func repriced(for baseline: Baseline) -> Policy {
        Policy(
            baseline: baseline,
            coinsPerHabitMinute: coinsPerHabitMinute,
            // Deliberately re-derived rather than carried over: a ratio that was admissible against
            // the old baseline may be a punisher against the new one.
            requiredRatio: Pricing.admissibleBand(for: baseline).lowerBound,
            tierMinutes: tierMinutes,
            weeklyGrant: weeklyGrant,
            missDeduction: missDeduction,
            weeklyRampFactor: weeklyRampFactor
        )
    }
}
