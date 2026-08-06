import Foundation

/// Per-day record of emergency unlocks.
///
/// Counted only to escalate the delay and to feed harm telemetry — never to deny access.
public struct EmergencyLog: Codable, Sendable, Equatable {
    /// Local midnight of the day being counted.
    public var dayStart: Date
    public var usesToday: Int
    /// Lifetime total, for the harm metrics. A user leaning on this constantly is telling us the
    /// strictness tier is wrong for them, which is a signal worth having.
    public var lifetimeUses: Int

    public init(dayStart: Date = Date(timeIntervalSince1970: 0), usesToday: Int = 0, lifetimeUses: Int = 0) {
        self.dayStart = dayStart
        self.usesToday = usesToday
        self.lifetimeUses = lifetimeUses
    }

    public static let empty = EmergencyLog()

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dayStart = try c.decodeIfPresent(Date.self, forKey: .dayStart) ?? Date(timeIntervalSince1970: 0)
        usesToday = try c.decodeIfPresent(Int.self, forKey: .usesToday) ?? 0
        lifetimeUses = try c.decodeIfPresent(Int.self, forKey: .lifetimeUses) ?? 0
    }

    /// Records a use, rolling the counter when the day has changed.
    public mutating func record(now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        if today != dayStart {
            dayStart = today
            usesToday = 0
        }
        usesToday += 1
        lifetimeUses += 1
    }

    public func uses(on day: Date, calendar: Calendar = .current) -> Int {
        calendar.startOfDay(for: day) == dayStart ? usesToday : 0
    }
}

/// The delay in front of a free emergency unlock.
///
/// Grounded in the one published decomposition of this mechanic: the **dismiss option was the
/// strongest component and the time delay also worked, while the deliberation message did
/// nothing measurable.** So this is a delay plus a prominent way out — and deliberately *no*
/// motivational text, because adding it is a real temptation that the evidence says buys nothing.
///
/// Never a gate. Access is always granted eventually, and the count never denies it: someone who
/// genuinely needs Maps or a banking app must not be stranded by an empty wallet. Escalation
/// exists so that habitual use costs a little more attention, not so that it can be refused.
public struct FrictionPolicy: Codable, Sendable, Equatable {

    /// Delay for the 1st, 2nd, 3rd+ use in a day. The last value repeats.
    public var escalatingDelays: [Int]

    /// How long the granted window lasts.
    public var windowMinutes: Int

    public init(escalatingDelays: [Int] = [20, 30, 45], windowMinutes: Int = 15) {
        // Sorted and floored so a mis-ordered config cannot make the third use cheaper than the
        // first, and so no delay can be negative.
        let cleaned = escalatingDelays.map { max(0, $0) }.sorted()
        self.escalatingDelays = cleaned.isEmpty ? [20] : cleaned
        self.windowMinutes = max(1, windowMinutes)
    }

    public static let `default` = FrictionPolicy()

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let delays = try c.decodeIfPresent([Int].self, forKey: .escalatingDelays) ?? [20, 30, 45]
        let window = try c.decodeIfPresent(Int.self, forKey: .windowMinutes) ?? 15
        self.init(escalatingDelays: delays, windowMinutes: window)
    }

    /// Delay for the next use, given how many have already happened today.
    ///
    /// Total for every input, including negative and absurd counts — this sits in front of a
    /// safety feature and must never trap.
    public func delaySeconds(priorUsesToday: Int) -> Int {
        guard !escalatingDelays.isEmpty else { return 0 }
        let index = min(max(0, priorUsesToday), escalatingDelays.count - 1)
        return escalatingDelays[index]
    }

    /// Always true. Present as a named property so that any future attempt to add a cap has to
    /// delete this and confront the reason it exists.
    ///
    /// Capping emergency unlocks trades a bounded product concern against an unbounded user one:
    /// the worst case for us is someone scrolling more than we would like, and the worst case for
    /// them is being locked out of something they urgently need.
    public var isAlwaysAvailable: Bool { true }
}
