import Foundation

/// One continuous run of the timer. `endedAt == nil` means it is still going.
public struct RunSegment: Codable, Sendable, Equatable {
    public var startedAt: Date
    public var endedAt: Date?

    public init(startedAt: Date, endedAt: Date? = nil) {
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date(timeIntervalSince1970: 0)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
    }

    /// Duration, clamped at zero.
    ///
    /// Clamped because the device clock is user-settable and can move backwards mid-session. A
    /// negative segment would silently subtract from earned time.
    func duration(now: Date) -> TimeInterval {
        max(0, (endedAt ?? now).timeIntervalSince(startedAt))
    }
}

/// A running habit timer.
///
/// **Elapsed time is derived from timestamps, never accumulated in a ticking counter.** That is the
/// whole design: a counter incremented on a timer tick dies with the process, so a force-quit — or
/// simply a long suspension — would silently discard the user's work. Here the state is a list of
/// dates, so it is correct after any interruption, including the app being killed outright.
///
/// Pause exists because its absence is a competitor's single most-requested fix, and because
/// without it users report "cheating the system" to work around it.
public struct HabitTimer: Codable, Sendable, Equatable {

    public let habitID: UUID

    /// The standard, captured when the timer started.
    ///
    /// Frozen at commencement so that editing a habit mid-session cannot retroactively move the bar
    /// the user is already working against.
    public let targetMinutes: Int

    public private(set) var segments: [RunSegment]

    public init(habitID: UUID, targetMinutes: Int, startedAt: Date) {
        self.habitID = habitID
        self.targetMinutes = max(1, targetMinutes)
        segments = [RunSegment(startedAt: startedAt)]
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        habitID = try c.decodeIfPresent(UUID.self, forKey: .habitID) ?? UUID()
        targetMinutes = max(1, try c.decodeIfPresent(Int.self, forKey: .targetMinutes) ?? 10)
        segments = try c.decodeIfPresent([RunSegment].self, forKey: .segments) ?? []
    }

    // MARK: - Derived state

    public var isRunning: Bool {
        segments.last?.endedAt == nil && !segments.isEmpty
    }

    public var isPaused: Bool { !segments.isEmpty && !isRunning }

    public var startedAt: Date? { segments.first?.startedAt }

    /// Time actually worked. Sums the segments; the open one runs to `now`.
    public func activeSeconds(now: Date) -> TimeInterval {
        segments.reduce(0) { $0 + $1.duration(now: now) }
    }

    /// Time between segments — the gaps the user chose to pause for.
    public func pausedSeconds(now: Date) -> TimeInterval {
        guard let first = segments.first?.startedAt else { return 0 }
        let wall = max(0, now.timeIntervalSince(first))
        return max(0, wall - activeSeconds(now: now))
    }

    public func hasMetStandard(now: Date) -> Bool {
        activeSeconds(now: now) >= TimeInterval(targetMinutes * 60)
    }

    /// Fraction of the target completed, capped at 1 for progress display.
    public func progress(now: Date) -> Double {
        let target = TimeInterval(targetMinutes * 60)
        guard target > 0 else { return 1 }
        return min(1, activeSeconds(now: now) / target)
    }

    public func remainingSeconds(now: Date) -> TimeInterval {
        max(0, TimeInterval(targetMinutes * 60) - activeSeconds(now: now))
    }

    // MARK: - Transitions

    /// Pauses. A second call is a no-op rather than an error.
    ///
    /// Idempotent because the UI and a lifecycle callback can both plausibly reach for it, and a
    /// double-pause corrupting the segment list would lose time.
    public mutating func pause(at date: Date) {
        guard isRunning, var last = segments.last else { return }
        // Never allow a backwards clock to close a segment before it opened.
        last.endedAt = max(date, last.startedAt)
        segments[segments.count - 1] = last
    }

    /// Resumes. A second call is a no-op.
    public mutating func resume(at date: Date) {
        guard isPaused else { return }
        segments.append(RunSegment(startedAt: date))
    }

    /// Closes the timer and produces the session to be awarded.
    public mutating func finish(at date: Date) -> HabitSession {
        pause(at: date)
        let start = segments.first?.startedAt ?? date
        return HabitSession(
            habitID: habitID,
            startedAt: start,
            endedAt: max(date, start),
            activeSeconds: activeSeconds(now: date),
            pausedSeconds: pausedSeconds(now: date),
            wasRetroactive: false
        )
    }

    /// A session logged after the fact.
    ///
    /// Supported because its absence drives churn — "if you forget to start a task you can't mark
    /// it later" is a recurring competitor complaint. Flagged rather than disguised, so it can be
    /// weighted differently if it is ever abused, and so the user's own history stays honest.
    public static func retroactiveSession(
        habitID: UUID,
        minutes: Int,
        endedAt: Date
    ) -> HabitSession {
        let seconds = TimeInterval(max(0, minutes) * 60)
        return HabitSession(
            habitID: habitID,
            startedAt: endedAt.addingTimeInterval(-seconds),
            endedAt: endedAt,
            activeSeconds: seconds,
            pausedSeconds: 0,
            wasRetroactive: true
        )
    }
}
