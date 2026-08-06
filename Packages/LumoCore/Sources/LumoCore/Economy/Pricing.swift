import Foundation

/// A user's measured baselines, in minutes per day.
///
/// The economy is priced off these rather than a global table, which is the one genuinely
/// unoccupied position in this market — no competitor does it.
public struct Baseline: Codable, Sendable, Equatable {
    /// Time on the shielded apps before Lumo intervened. The contingent activity.
    public var scrollMinutesPerDay: Double
    /// Time on habits before Lumo intervened. The instrumental activity.
    public var habitMinutesPerDay: Double
    /// How the figures were obtained, so the debug panel can distinguish a measurement from a
    /// default and we never silently price against a guess.
    public var source: Source
    public var observedAt: Date

    public enum Source: String, Codable, Sendable {
        /// Global defaults, used for the first few days before enough is known.
        case defaults
        /// Inferred from DeviceActivityEvent threshold crossings — coarse buckets, but real.
        case thresholdLadder
        /// User-entered from Settings → Screen Time. Honest but under-reported.
        case selfReported
    }

    public init(
        scrollMinutesPerDay: Double,
        habitMinutesPerDay: Double,
        source: Source,
        observedAt: Date
    ) {
        self.scrollMinutesPerDay = max(0, scrollMinutesPerDay)
        self.habitMinutesPerDay = max(0, habitMinutesPerDay)
        self.source = source
        self.observedAt = observedAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scrollMinutesPerDay = try c.decodeIfPresent(Double.self, forKey: .scrollMinutesPerDay) ?? 120
        habitMinutesPerDay = try c.decodeIfPresent(Double.self, forKey: .habitMinutesPerDay) ?? 20
        source = try c.decodeIfPresent(Source.self, forKey: .source) ?? .defaults
        observedAt = try c.decodeIfPresent(Date.self, forKey: .observedAt) ?? Date(timeIntervalSince1970: 0)
    }

    /// Conservative starting point for a new user: ~2h scrolling, ~20min of habits.
    public static let conservativeDefault = Baseline(
        scrollMinutesPerDay: 120,
        habitMinutesPerDay: 20,
        source: .defaults,
        observedAt: Date(timeIntervalSince1970: 0)
    )

    /// The ratio the contingency must beat: habit minutes per scroll minute, as the user
    /// currently lives.
    public var ratio: Double {
        guard scrollMinutesPerDay > 0 else { return .infinity }
        return habitMinutesPerDay / scrollMinutesPerDay
    }
}

/// Response-deprivation pricing.
///
/// The disequilibrium model says a contingency only reinforces when the required ratio of
/// instrumental to contingent activity **exceeds** the user's own baseline ratio. Two failure
/// modes sit either side of that, and both are invisible without calibration:
///
/// * **Too generous** — below the baseline ratio there is no deprivation, so the contingency
///   stops reinforcing and becomes a *punisher*: it actively suppresses the habit it was meant
///   to build. A cheap price is worse than no app.
/// * **Too demanding** — far above baseline produces ratio strain, where the behaviour stops
///   just short of the reward. Around 6x baseline was rejected as unworkable in the source
///   literature, so that is treated as the ceiling.
public enum Pricing {

    /// Multiplier applied to the baseline ratio for the lower bound. Strictly above 1 so the
    /// boundary itself is excluded — sitting exactly on the baseline is not deprivation.
    public static let punisherMargin = 1.15

    /// Upper bound multiple. Beyond this, ratio strain is the dominant churn risk.
    public static let strainMultiple = 6.0

    /// The band of admissible required-habit-per-unlock-minute ratios.
    public static func admissibleBand(for baseline: Baseline) -> ClosedRange<Double> {
        let lower = baseline.ratio * punisherMargin
        let upper = baseline.ratio * strainMultiple
        // Guard against a degenerate baseline producing an inverted range.
        return lower <= upper ? lower...upper : lower...lower
    }

    /// Below the lower bound the contingency punishes rather than reinforces.
    public static func isPunisher(ratio: Double, baseline: Baseline) -> Bool {
        ratio < admissibleBand(for: baseline).lowerBound
    }

    /// Above the upper bound the user gives up before reaching the reward.
    public static func hasRatioStrain(ratio: Double, baseline: Baseline) -> Bool {
        ratio > admissibleBand(for: baseline).upperBound
    }

    /// Clamps a proposed ratio into the admissible band.
    ///
    /// Used for user-set prices: autonomy support matters — the user authoring their own economy
    /// is one of the few mitigations for the overjustification effect — but they must not be able
    /// to choose a price that makes the mechanic actively harmful.
    public static func clamp(ratio: Double, baseline: Baseline) -> Double {
        let band = admissibleBand(for: baseline)
        return min(max(ratio, band.lowerBound), band.upperBound)
    }
}

/// Prices and window lengths. App-write-only, read by every process.
public struct Policy: Codable, Sendable, Equatable {
    public var baseline: Baseline

    /// Coins credited per minute of completed habit. Kept small on purpose: in a
    /// 61,293-person megastudy $0.09 beat $1.75, and reward magnitude saturates almost
    /// immediately.
    public var coinsPerHabitMinute: Int

    /// Required habit minutes per unlock minute. Must sit inside the admissible band.
    public var requiredRatio: Double

    /// Wall-clock window lengths offered, in minutes, cheapest first.
    public var tierMinutes: [Int]

    /// Weekly house allowance. The loss-framed half of the economy.
    public var weeklyGrant: Int

    /// Coins removed per missed day. Only ever from the granted portion.
    public var missDeduction: Int

    /// Weekly target escalation, from the user's own baseline.
    ///
    /// +15%/week is the ACTIVE REWARD figure — the only loss-framed design whose effect
    /// survived after the incentive stopped.
    public var weeklyRampFactor: Double

    public init(
        baseline: Baseline = .conservativeDefault,
        coinsPerHabitMinute: Int = 2,
        requiredRatio: Double? = nil,
        tierMinutes: [Int] = [15, 30, 60],
        weeklyGrant: Int = 140,
        missDeduction: Int = 20,
        weeklyRampFactor: Double = 1.15
    ) {
        self.baseline = baseline
        self.coinsPerHabitMinute = max(1, coinsPerHabitMinute)
        // Default to the bottom of the admissible band: the gentlest price that still
        // reinforces rather than punishes.
        self.requiredRatio = Pricing.clamp(
            ratio: requiredRatio ?? Pricing.admissibleBand(for: baseline).lowerBound,
            baseline: baseline
        )
        self.tierMinutes = tierMinutes.filter { $0 > 0 }.sorted()
        self.weeklyGrant = max(0, weeklyGrant)
        self.missDeduction = max(0, missDeduction)
        self.weeklyRampFactor = max(1.0, weeklyRampFactor)
    }

    public static let `default` = Policy()

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        baseline = try c.decodeIfPresent(Baseline.self, forKey: .baseline) ?? .conservativeDefault
        coinsPerHabitMinute = try c.decodeIfPresent(Int.self, forKey: .coinsPerHabitMinute) ?? 2
        requiredRatio = try c.decodeIfPresent(Double.self, forKey: .requiredRatio)
            ?? Pricing.admissibleBand(for: baseline).lowerBound
        tierMinutes = try c.decodeIfPresent([Int].self, forKey: .tierMinutes) ?? [15, 30, 60]
        weeklyGrant = try c.decodeIfPresent(Int.self, forKey: .weeklyGrant) ?? 140
        missDeduction = try c.decodeIfPresent(Int.self, forKey: .missDeduction) ?? 20
        weeklyRampFactor = try c.decodeIfPresent(Double.self, forKey: .weeklyRampFactor) ?? 1.15
    }

    /// Coin cost of an unlock of `minutes`.
    ///
    /// `requiredRatio` habit-minutes per unlock-minute, converted to coins at
    /// `coinsPerHabitMinute`. Always at least 1, so nothing is ever free by rounding.
    public func price(forMinutes minutes: Int) -> Int {
        let habitMinutes = Double(minutes) * requiredRatio
        return max(1, Int((habitMinutes * Double(coinsPerHabitMinute)).rounded()))
    }

    /// Whether the cheapest tier can be afforded more than once from a day's honest effort.
    ///
    /// The heuristic from the contingency-management literature is that a reinforcer should be
    /// reachable roughly four times per session. Saving for three days to buy one unlock does
    /// not build a habit — it builds resentment and then an uninstall.
    public func supportsMultipleDailyCycles(minimumCycles: Int = 2) -> Bool {
        guard let cheapest = tierMinutes.first else { return false }
        let dailyEarnings = Double(baseline.habitMinutesPerDay) * Double(coinsPerHabitMinute)
        return dailyEarnings >= Double(price(forMinutes: cheapest) * minimumCycles)
    }

    /// Order-sensitive identity for this policy.
    ///
    /// The shield submenu hands back a *position*, not an identity, so the action extension has
    /// to recompute the ladder and confirm it is pricing against the same policy the config
    /// extension rendered. Order matters because position IS the reference.
    public var fingerprint: String {
        var parts: [String] = [
            "r:\(String(format: "%.4f", requiredRatio))",
            "c:\(coinsPerHabitMinute)",
            "b:\(String(format: "%.2f", baseline.scrollMinutesPerDay))",
            "h:\(String(format: "%.2f", baseline.habitMinutesPerDay))",
        ]
        parts.append("t:" + tierMinutes.map(String.init).joined(separator: "-"))
        return parts.joined(separator: "|")
    }
}
