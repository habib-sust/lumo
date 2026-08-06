import Foundation

/// The weekly house allowance.
///
/// This is the loss-framed half of the economy, and it is modelled on the one design in the
/// literature whose behavioural effect **survived after the incentive stopped**: a weekly
/// house-funded account with deductions for missed days, plus goals ramped from the participant's
/// own measured baseline. Fixed-goal designs lost their effect at follow-up.
///
/// The critical asymmetry, enforced by `Wallet` rather than by convention: a miss can only consume
/// **granted** coins. House money is a designed, anticipated, reference-point-resetting mechanic.
/// Clawing back coins the user earned is a different thing entirely — asking people to risk what
/// is already theirs collapses acceptance from roughly 90% to 14%, and removing earned points
/// specifically harms the most engaged users.
public enum GrantCycle {

    /// Local midnight on Monday of the week containing `date`.
    ///
    /// Local rather than UTC on purpose: "this week" has to mean what the user's calendar says, or
    /// the grant lands on a Sunday evening for half the world.
    public static func weekStart(for date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        // Monday. `firstWeekday` varies by locale, so it is pinned rather than inherited —
        // otherwise the week boundary would move when the user changes region.
        cal.firstWeekday = 2
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? cal.startOfDay(for: date)
    }

    public struct Outcome: Equatable, Sendable {
        public var issued: Int = 0
        public var expired: Int = 0
        public var deducted: Int = 0
        public var rolledIntoNewWeek = false
        /// Target for the new week, ramped from the user's own baseline.
        public var rampedTargetMinutes: Int?
    }

    /// Issues the allowance if a new week has begun, expiring whatever was left of the old one.
    ///
    /// Expiry is what makes the grant feel like something to use rather than hoard, and it is also
    /// why spending draws granted-first: the user loses less that way.
    @discardableResult
    public static func issueIfNeeded(
        state: inout SharedState,
        policy: Policy,
        now: Date,
        calendar: Calendar = .current
    ) -> Outcome {
        var outcome = Outcome()
        let currentWeek = weekStart(for: now, calendar: calendar)

        guard state.week.weekStart != currentWeek else { return outcome }

        // Expire the remainder of the old grant. `earned` is untouched.
        let expired = state.wallet.expireGrant()
        if expired > 0 { outcome.expired = expired }

        state.week = WeekLedger(
            weekStart: currentWeek,
            grantIssued: policy.weeklyGrant,
            missesThisWeek: 0,
            grantDeductedThisWeek: 0,
            // Deliberately preserved across the week boundary: a comeback owed from Sunday is
            // still owed on Monday. Resetting it would quietly delete the single most effective
            // intervention in the megastudy.
            comebackBonusArmed: state.week.comebackBonusArmed
        )
        state.wallet.issueGrant(policy.weeklyGrant)

        outcome.issued = policy.weeklyGrant
        outcome.rolledIntoNewWeek = true
        outcome.rampedTargetMinutes = rampedTarget(policy: policy, weeksElapsed: 1)
        return outcome
    }

    /// Records a missed day.
    ///
    /// Returns how much was actually taken, which may be less than the configured deduction — a
    /// user whose grant is already spent cannot go negative, and must never be pushed into their
    /// earned balance. Debt mechanics are a documented driver of shame spirals and uninstalls.
    @discardableResult
    public static func recordMiss(
        state: inout SharedState,
        policy: Policy,
        now: Date,
        calendar: Calendar = .current
    ) -> Outcome {
        var outcome = issueIfNeeded(state: &state, policy: policy, now: now, calendar: calendar)

        let earnedBefore = state.wallet.earned
        let taken = state.wallet.deductForMiss(policy.missDeduction)

        state.week.missesThisWeek += 1
        state.week.grantDeductedThisWeek += taken
        // Arm the comeback. The single most effective of 53 interventions tested on 61,293 people
        // was a bonus for returning after a lapse — and the $0.09 version beat the $1.75 one.
        state.week.comebackBonusArmed = true

        outcome.deducted = taken
        // Belt and braces around the invariant that matters most.
        assert(state.wallet.earned == earnedBefore, "a miss must never touch earned coins")
        return outcome
    }

    /// Target minutes for a given week, ramped from the user's own baseline.
    ///
    /// +15%/week compounding, from the baseline Lumo measured rather than a global number — the
    /// ramp and the personalisation are both load-bearing in the design that persisted.
    public static func rampedTarget(policy: Policy, weeksElapsed: Int) -> Int {
        let base = max(1.0, policy.baseline.habitMinutesPerDay)
        let weeks = max(0, weeksElapsed)
        let ramped = base * pow(policy.weeklyRampFactor, Double(weeks))
        // Capped so a long-running user is not eventually asked for an impossible day. Ratio
        // strain is the top churn risk, and an ever-compounding target walks straight into it.
        let ceiling = base * 4
        return Int(min(ramped, ceiling).rounded())
    }

    /// Days in the current week with no completed session, given the days that had one.
    ///
    /// Computed rather than counted incrementally so a missed launch cannot lose a day: if Lumo is
    /// not opened for three days, the next launch still resolves them correctly.
    public static func missedDays(
        completedDays: Set<Date>,
        weekStart: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        let today = calendar.startOfDay(for: now)
        var missed = 0
        var cursor = calendar.startOfDay(for: weekStart)
        // Today is excluded: the day is not over, so it is not yet a miss.
        while cursor < today {
            if !completedDays.contains(cursor) { missed += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return missed
    }
}
