import Foundation

/// A single self-reported enjoyment reading, 1–5.
public struct EnjoymentSample: Codable, Sendable, Equatable {
    public var at: Date
    public var score: Int

    public init(at: Date, score: Int) {
        self.at = at
        self.score = min(5, max(1, score))
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        at = try c.decodeIfPresent(Date.self, forKey: .at) ?? Date(timeIntervalSince1970: 0)
        score = min(5, max(1, try c.decodeIfPresent(Int.self, forKey: .score) ?? 3))
    }
}

/// Instrumentation for **harm**, not engagement.
///
/// The alarm bell in the literature is a study where an intervention measurably increased the target
/// behaviour and still *reduced* welfare. Separately: a week of blocked distractions raised focus but
/// produced lower enjoyment, less flow, and higher workload specifically for users who were already
/// high in self-control — and interrupted people compress rather than lose time, so throughput
/// metrics will never reveal any of it. Only stress and enjoyment measures will.
///
/// So Lumo tracks the things that would tell it to back off, with thresholds agreed in advance while
/// they are still abstract. It is much harder to turn a tier off once it has users.
///
/// Local only. No SDK, nothing leaves the device — and nothing here is used to drive engagement.
public struct HarmMetrics: Codable, Sendable, Equatable {

    public var sessionsStarted: Int
    public var sessionsCompleted: Int
    /// Started and neither completed nor still running.
    public var sessionsAbandoned: Int
    public var emergencyUnlocks: Int
    /// Weekly grant that expired unspent. High forfeiture means the economy is unreachable.
    public var grantForfeited: Int
    public var enjoymentSamples: [EnjoymentSample]
    public var windowStart: Date

    public init(
        sessionsStarted: Int = 0,
        sessionsCompleted: Int = 0,
        sessionsAbandoned: Int = 0,
        emergencyUnlocks: Int = 0,
        grantForfeited: Int = 0,
        enjoymentSamples: [EnjoymentSample] = [],
        windowStart: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.sessionsStarted = sessionsStarted
        self.sessionsCompleted = sessionsCompleted
        self.sessionsAbandoned = sessionsAbandoned
        self.emergencyUnlocks = emergencyUnlocks
        self.grantForfeited = grantForfeited
        self.enjoymentSamples = Array(enjoymentSamples.suffix(30))
        self.windowStart = windowStart
    }

    public static let empty = HarmMetrics()

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionsStarted = try c.decodeIfPresent(Int.self, forKey: .sessionsStarted) ?? 0
        sessionsCompleted = try c.decodeIfPresent(Int.self, forKey: .sessionsCompleted) ?? 0
        sessionsAbandoned = try c.decodeIfPresent(Int.self, forKey: .sessionsAbandoned) ?? 0
        emergencyUnlocks = try c.decodeIfPresent(Int.self, forKey: .emergencyUnlocks) ?? 0
        grantForfeited = try c.decodeIfPresent(Int.self, forKey: .grantForfeited) ?? 0
        enjoymentSamples = Array(
            (try c.decodeIfPresent([EnjoymentSample].self, forKey: .enjoymentSamples) ?? []).suffix(30))
        windowStart = try c.decodeIfPresent(Date.self, forKey: .windowStart) ?? Date(timeIntervalSince1970: 0)
    }

    // MARK: - Derived

    /// `nil` until there is enough data to mean anything.
    ///
    /// A floor rather than reporting 0/1 as "0% completion" — an early bad ratio would trip an alarm
    /// that says nothing.
    public var completionRate: Double? {
        guard sessionsStarted >= 5 else { return nil }
        return Double(sessionsCompleted) / Double(sessionsStarted)
    }

    public var averageEnjoyment: Double? {
        guard enjoymentSamples.count >= 3 else { return nil }
        return Double(enjoymentSamples.reduce(0) { $0 + $1.score }) / Double(enjoymentSamples.count)
    }

    /// Positive means enjoyment is rising. `nil` until there are two comparable halves.
    public var enjoymentTrend: Double? {
        guard enjoymentSamples.count >= 6 else { return nil }
        let sorted = enjoymentSamples.sorted { $0.at < $1.at }
        let half = sorted.count / 2
        let older = sorted.prefix(half)
        let newer = sorted.suffix(sorted.count - half)
        let a = Double(older.reduce(0) { $0 + $1.score }) / Double(older.count)
        let b = Double(newer.reduce(0) { $0 + $1.score }) / Double(newer.count)
        return b - a
    }
}

/// Something Lumo should act on.
public enum HarmConcern: String, Sendable, CaseIterable, Equatable {
    /// The user is failing the contracts they set themselves.
    ///
    /// The threshold is deliberate: in one study 55% of clients defaulted on self-designed
    /// commitment contracts and lost money — "a majority chose a harmful contract". If most sessions
    /// on the strictest tier are failing, Lumo has built that, not a working intervention.
    case failingOwnContracts
    /// Heavy reliance on the free unlock means the strictness tier is wrong for this user.
    case leaningOnEmergencyUnlocks
    /// Most of the grant expires unspent, so the economy is effectively unreachable.
    case economyUnreachable
    /// Enjoyment is falling. The metric throughput cannot show.
    case enjoymentDeclining

    public var explanation: String {
        switch self {
        case .failingOwnContracts:
            "More than half of started sessions are not finishing. The targets are probably too high."
        case .leaningOnEmergencyUnlocks:
            "Emergency unlocks are being used most days. The locked list is probably too strict."
        case .economyUnreachable:
            "Most of the weekly allowance is expiring unused. Earning is probably too slow."
        case .enjoymentDeclining:
            "Enjoyment has been trending down. Worth easing off rather than pushing harder."
        }
    }
}

public enum HarmThresholds {
    /// Below this completion rate, the user is failing their own contracts.
    public static let minimumCompletionRate = 0.5
    /// Emergency unlocks per day above which reliance is the signal, not the exception.
    public static let maximumDailyEmergencyUnlocks = 1.0
    /// Fraction of the weekly grant that may expire before the economy counts as unreachable.
    public static let maximumForfeitureRate = 0.6
    /// Drop in mean enjoyment that counts as a decline.
    public static let concerningEnjoymentDrop = -0.75

    /// Evaluates the metrics against every threshold.
    ///
    /// Returns concerns rather than a single boolean, because each one implies a different response —
    /// lowering targets, loosening the list, speeding up earning, or easing off entirely.
    public static func concerns(
        for metrics: HarmMetrics,
        grantIssued: Int,
        now: Date
    ) -> [HarmConcern] {
        var found: [HarmConcern] = []

        if let rate = metrics.completionRate, rate < minimumCompletionRate {
            found.append(.failingOwnContracts)
        }

        let days = max(1, now.timeIntervalSince(metrics.windowStart) / 86_400)
        if metrics.emergencyUnlocks > 0,
           Double(metrics.emergencyUnlocks) / days > maximumDailyEmergencyUnlocks {
            found.append(.leaningOnEmergencyUnlocks)
        }

        if grantIssued > 0,
           Double(metrics.grantForfeited) / Double(grantIssued) > maximumForfeitureRate {
            found.append(.economyUnreachable)
        }

        if let trend = metrics.enjoymentTrend, trend <= concerningEnjoymentDrop {
            found.append(.enjoymentDeclining)
        }

        return found
    }
}
