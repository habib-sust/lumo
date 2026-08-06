import Foundation
import Testing
@testable import LumoCore

/// T-GRANT-01…10, T-STREAK-01…12, T-AWARD-01…10.
@Suite("Grant cycle, streaks, coin awards")
struct EconomyTests {

    /// UTC throughout, so week and day boundaries are deterministic rather than machine-dependent.
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func day(_ offset: Int) -> Date {
        Date.fixture.addingTimeInterval(TimeInterval(offset * 86_400))
    }

    // MARK: - Week boundaries

    @Test("The week starts on Monday regardless of locale first-weekday")
    func weekStartsMonday() {
        // Pinned rather than inherited: otherwise the grant would land on Sunday evening for a
        // large part of the world, and would move if the user changed region.
        var usCalendar = Calendar(identifier: .gregorian)
        usCalendar.timeZone = TimeZone(identifier: "UTC")!
        usCalendar.firstWeekday = 1 // Sunday, as in the US

        let start = GrantCycle.weekStart(for: .fixture, calendar: usCalendar)
        let weekday = calendar.component(.weekday, from: start)
        #expect(weekday == 2, "expected Monday, got weekday \(weekday)")
    }

    @Test("Every day of a week maps to the same week start")
    func daysWithinWeekShareStart() {
        let starts = (0..<7).map { GrantCycle.weekStart(for: day($0), calendar: calendar) }
        #expect(Set(starts).count == 1, "days 0-6 should share one week start: \(starts)")
    }

    // MARK: - Grant issuance

    @Test("The grant is issued once per week, not once per launch")
    func grantIssuedOncePerWeek() {
        var state = SharedState()
        let policy = Policy.default

        let first = GrantCycle.issueIfNeeded(state: &state, policy: policy, now: .fixture, calendar: calendar)
        #expect(first.issued == policy.weeklyGrant)
        #expect(state.wallet.granted == policy.weeklyGrant)

        // Same week, later in the day — must not top up again.
        let second = GrantCycle.issueIfNeeded(
            state: &state, policy: policy, now: Date.fixture.addingTimeInterval(3600), calendar: calendar)
        #expect(second.issued == 0)
        #expect(state.wallet.granted == policy.weeklyGrant)
    }

    @Test("Unspent grant expires at the week boundary; earned survives")
    func unspentGrantExpires() {
        var state = SharedState(wallet: Wallet(granted: 0, earned: 90))
        let policy = Policy.default

        GrantCycle.issueIfNeeded(state: &state, policy: policy, now: day(0), calendar: calendar)
        #expect(state.wallet.granted == policy.weeklyGrant)

        let next = GrantCycle.issueIfNeeded(state: &state, policy: policy, now: day(8), calendar: calendar)

        // Expiry is what stops the grant being hoarded, and it is why spending draws granted-first.
        #expect(next.expired == policy.weeklyGrant)
        #expect(next.issued == policy.weeklyGrant)
        #expect(state.wallet.granted == policy.weeklyGrant, "fresh grant, not accumulated")
        #expect(state.wallet.earned == 90, "earned is never expired")
    }

    @Test("A comeback owed on Sunday is still owed on Monday")
    func comebackSurvivesWeekRollover() {
        // Resetting this at the boundary would quietly delete the single most effective
        // intervention in the megastudy.
        var state = SharedState()
        GrantCycle.issueIfNeeded(state: &state, policy: .default, now: day(0), calendar: calendar)
        GrantCycle.recordMiss(state: &state, policy: .default, now: day(3), calendar: calendar)
        #expect(state.week.comebackBonusArmed)

        GrantCycle.issueIfNeeded(state: &state, policy: .default, now: day(8), calendar: calendar)
        #expect(state.week.comebackBonusArmed, "the comeback should carry across the week")
    }

    // MARK: - Miss deductions

    @Test("A miss deducts from granted only")
    func missDeductsGrantedOnly() {
        var state = SharedState(wallet: Wallet(granted: 0, earned: 500))
        let policy = Policy.default
        GrantCycle.issueIfNeeded(state: &state, policy: policy, now: .fixture, calendar: calendar)

        let outcome = GrantCycle.recordMiss(state: &state, policy: policy, now: .fixture, calendar: calendar)

        #expect(outcome.deducted == policy.missDeduction)
        #expect(state.wallet.earned == 500, "earned must be untouchable by a miss")
    }

    @Test("A miss against an exhausted grant is a no-op, never a debt")
    func missCannotCreateDebt() {
        // Debt mechanics are a documented driver of shame spirals and uninstalls, so the floor is
        // zero rather than negative.
        var state = SharedState(wallet: Wallet(granted: 0, earned: 300))
        state.week = WeekLedger(weekStart: GrantCycle.weekStart(for: .fixture, calendar: calendar))

        let outcome = GrantCycle.recordMiss(state: &state, policy: .default, now: .fixture, calendar: calendar)

        #expect(outcome.deducted == 0)
        #expect(state.wallet.granted == 0)
        #expect(state.wallet.earned == 300)
    }

    @Test("Earned survives an entire punishing month", arguments: [1, 7, 30])
    func earnedSurvivesSustainedMisses(days: Int) {
        var state = SharedState(wallet: Wallet(granted: 0, earned: 1_000))
        for offset in 0..<days {
            GrantCycle.recordMiss(state: &state, policy: .default, now: day(offset), calendar: calendar)
        }
        #expect(state.wallet.earned == 1_000, "no sequence of misses may reduce earned")
    }

    // MARK: - Ramp

    @Test("Targets ramp from the user's own baseline and then cap")
    func targetRampsThenCaps() {
        let policy = Policy(baseline: Baseline(
            scrollMinutesPerDay: 120, habitMinutesPerDay: 20,
            source: .thresholdLadder, observedAt: .fixture))

        #expect(GrantCycle.rampedTarget(policy: policy, weeksElapsed: 0) == 20)
        #expect(GrantCycle.rampedTarget(policy: policy, weeksElapsed: 1) == 23) // +15%
        #expect(GrantCycle.rampedTarget(policy: policy, weeksElapsed: 4) > 30)

        // Capped, because an ever-compounding target walks straight into ratio strain — the top
        // churn risk in the model.
        let far = GrantCycle.rampedTarget(policy: policy, weeksElapsed: 200)
        #expect(far == 80, "should cap at 4x baseline, got \(far)")
    }

    @Test("Missed days are computed rather than counted, so a skipped launch loses nothing")
    func missedDaysAreComputed() {
        // If Lumo is not opened for three days, the next launch still resolves them.
        let weekStart = GrantCycle.weekStart(for: day(0), calendar: calendar)
        let completed: Set<Date> = [calendar.startOfDay(for: day(0))]

        let missed = GrantCycle.missedDays(
            completedDays: completed, weekStart: weekStart, now: day(4), calendar: calendar)
        #expect(missed >= 2, "days between the completed one and today should count")
    }

    @Test("Today is never counted as a miss")
    func todayIsNotAMiss() {
        // The day is not over yet.
        let weekStart = calendar.startOfDay(for: day(0))
        let missed = GrantCycle.missedDays(
            completedDays: [], weekStart: weekStart, now: day(0), calendar: calendar)
        #expect(missed == 0)
    }

    // MARK: - Streaks

    @Test("A completed day increments the streak")
    func completionIncrements() {
        var streak = Streak.empty
        let result = streak.recordCompletion(on: day(0), calendar: calendar)
        #expect(result.didIncrement)
        #expect(streak.current == 1)
        #expect(streak.longest == 1)
    }

    @Test("Two sessions on one day count once")
    func sameDayIsIdempotent() {
        // The streak measures days engaged, not sessions logged.
        var streak = Streak.empty
        streak.recordCompletion(on: day(0), calendar: calendar)
        let second = streak.recordCompletion(
            on: Date.fixture.addingTimeInterval(3600), calendar: calendar)
        #expect(!second.didIncrement)
        #expect(streak.current == 1)
    }

    @Test("A MISS NEVER RESETS THE STREAK")
    func missNeverResets() {
        // The single most important assertion in this file, and the deliberate departure from the
        // whole category. A harsh reset produces a binge, not a comeback.
        var streak = Streak.empty
        for offset in 0..<10 { streak.recordCompletion(on: day(offset), calendar: calendar) }
        #expect(streak.current == 10)

        streak.recordMiss(on: day(10), calendar: calendar)

        #expect(streak.current == 10, "a miss must pause, never reset")
        #expect(streak.pausedDays == 1)
        #expect(streak.comebackArmed)
    }

    @Test("Completing after a miss resumes and pays the comeback")
    func comebackAfterMiss() {
        var streak = Streak.empty
        for offset in 0..<5 { streak.recordCompletion(on: day(offset), calendar: calendar) }
        streak.recordMiss(on: day(5), calendar: calendar)

        let result = streak.recordCompletion(on: day(6), calendar: calendar)

        #expect(result.earnedComebackBonus)
        #expect(streak.current == 6, "resumes rather than restarting")
        #expect(!streak.comebackArmed, "consumed exactly once")
    }

    @Test("current is never zero under ANY random sequence of days")
    func currentNeverZeroesProperty() {
        // Property test rather than illustration: the invariant has to hold for sequences nobody
        // thought to write a case for. Seeded so a failure is reproducible.
        var rng = SeededRNG(seed: 0xC0FFEE)
        var streak = Streak.empty
        streak.recordCompletion(on: day(0), calendar: calendar)

        for offset in 1..<3_000 {
            if rng.next(upperBound: 2) == 0 {
                streak.recordCompletion(on: day(offset), calendar: calendar)
            } else {
                streak.recordMiss(on: day(offset), calendar: calendar)
            }
            #expect(streak.current >= 1, "streak hit \(streak.current) at day \(offset)")
        }
    }

    @Test("A previous peak stays restorable, free and untimed")
    func peakIsRestorable() {
        // A competitor described restoring a lapsed streak as one of the most consistent requests
        // they hear. It is free here, and never expires.
        var streak = Streak.empty
        for offset in 0..<30 { streak.recordCompletion(on: day(offset), calendar: calendar) }
        streak.recordMiss(on: day(30), calendar: calendar)
        #expect(streak.canRestore == false, "nothing to restore while current still holds")

        // Simulate a long lapse where current was reduced by an external migration or import.
        var lapsed = Streak(current: 1, longest: 30, restorablePeak: 30)
        #expect(lapsed.canRestore)
        #expect(lapsed.restorePeak() == 30)
        #expect(lapsed.current == 30)
        #expect(!lapsed.canRestore, "restoring is not repeatable")
    }

    @Test("Repeated misses on the same day count once")
    func repeatedMissSameDayCountsOnce() {
        var streak = Streak.empty
        streak.recordCompletion(on: day(0), calendar: calendar)
        streak.recordMiss(on: day(0), calendar: calendar)
        streak.recordMiss(on: day(0), calendar: calendar)
        #expect(streak.pausedDays == 0, "the day already had a completion")
    }

    // MARK: - Awards

    private var habit: HabitSpec {
        HabitSpec(name: "Dishes", targetMinutes: 10)
    }

    private func session(minutes: Int, retroactive: Bool = false) -> HabitSession {
        HabitSession(
            habitID: habit.id, startedAt: .fixture,
            endedAt: Date.fixture.addingTimeInterval(TimeInterval(minutes * 60)),
            activeSeconds: TimeInterval(minutes * 60),
            wasRetroactive: retroactive
        )
    }

    @Test("Meeting the standard earns coins")
    func meetingStandardEarns() {
        let outcome = CoinAward.award(
            session: session(minutes: 10), habit: habit, policy: .default, streak: .empty)
        #expect(outcome.metStandard)
        #expect(outcome.coins == 10 * Policy.default.coinsPerHabitMinute)
    }

    @Test("Falling short earns NOTHING but is not framed as failure")
    func shortSessionEarnsNothing() {
        // Paying for mere participation is the most harmful cell in the reward literature
        // (d ≈ −0.40 vs −0.28 for meeting a standard), so a short session earns zero — while still
        // getting honest, non-disappointed feedback.
        let outcome = CoinAward.award(
            session: session(minutes: 4), habit: habit, policy: .default, streak: .empty)

        #expect(!outcome.metStandard)
        #expect(outcome.total == 0)
        let text = (outcome.feedback.headline + " " + outcome.feedback.detail).lowercased()
        for word in ["failed", "not enough", "try harder", "only"] {
            #expect(!text.contains(word), "feedback contains discouraging '\(word)'")
        }
        #expect(outcome.feedback.detail.contains("still counts"))
    }

    @Test("An un-monetised habit earns nothing and says so plainly")
    func unmonetisedHabitEarnsNothing() {
        // Undermining requires pre-existing intrinsic motivation to destroy, so anything the user
        // already loves must stay out of the economy.
        let forItsOwnSake = HabitSpec(name: "Guitar", targetMinutes: 10, isMonetised: false)
        let outcome = CoinAward.award(
            session: session(minutes: 30), habit: forItsOwnSake, policy: .default, streak: .empty)

        #expect(outcome.metStandard)
        #expect(outcome.total == 0)
        #expect(!outcome.feedback.detail.isEmpty, "must not look broken")
    }

    @Test("Every award carries informational feedback, never a bare number")
    func everyAwardHasFeedback() {
        // A bare counter going up is the engagement-contingent shape; pairing it with competence
        // feedback is one of the mitigations with a real effect size behind it.
        for minutes in [1, 5, 10, 25, 60] {
            let outcome = CoinAward.award(
                session: session(minutes: minutes), habit: habit, policy: .default, streak: .empty)
            #expect(!outcome.feedback.headline.isEmpty)
            #expect(!outcome.feedback.detail.isEmpty)
        }
    }

    @Test("A comeback session pays a bonus and names the return, not the lapse")
    func comebackFeedbackNamesTheReturn() {
        var streak = Streak.empty
        streak.recordCompletion(on: day(0), calendar: calendar)
        streak.recordMiss(on: day(1), calendar: calendar)

        let outcome = CoinAward.award(
            session: session(minutes: 10), habit: habit, policy: .default, streak: streak)

        #expect(outcome.comebackBonus > 0)
        // "You broke your streak" is the framing that produces a binge.
        let text = outcome.feedback.detail.lowercased()
        #expect(!text.contains("broke"))
        #expect(!text.contains("lost"))
    }

    @Test("The comeback bonus is small relative to what effort earns")
    func comebackBonusIsSmall() {
        // The megastudy's cheapest comeback bonus ($0.09) outperformed the most expensive ($1.75),
        // so this is acknowledgement rather than compensation.
        //
        // Compared against what a SESSION earns, not against a tier price. An earlier version of
        // this test used "half the cheapest unlock" — an arbitrary threshold that happens to be
        // tiny, because unlock prices are deliberately low relative to earnings. The principle is
        // that returning must not out-pay doing the work.
        let policy = Policy.default
        let bonus = CoinAward.comebackBonusCoins(policy: policy)
        let typicalSession = 10 * policy.coinsPerHabitMinute

        #expect(bonus >= 1, "must be a real acknowledgement, not zero")
        #expect(
            bonus <= typicalSession / 4,
            "bonus \(bonus) is more than a quarter of a session's \(typicalSession) — returning should not out-pay the work"
        )
    }

    @Test("Surprise bonuses are occasional and deterministic given a roll")
    func surpriseBonusIsDeterministic() {
        // Unexpected rewards showed no undermining effect at all, unlike the expected contingent
        // kind — so a small unpredictable component is close to free upside. Driven by a supplied
        // roll so the award stays pure and the tests stay reproducible.
        let hit = CoinAward.award(
            session: session(minutes: 10), habit: habit, policy: .default,
            streak: .empty, surpriseRoll: 0)
        let miss = CoinAward.award(
            session: session(minutes: 10), habit: habit, policy: .default,
            streak: .empty, surpriseRoll: 3)

        #expect(hit.surpriseBonus > 0)
        #expect(miss.surpriseBonus == 0)
    }

    @Test("Retroactive logging is honoured and recorded")
    func retroactiveIsHonoured() {
        // Its absence is a recurring competitor complaint — "if you forget to start a task you
        // can't mark it later" — and it drives churn. Recorded rather than hidden so it can be
        // weighted differently if abused.
        let logged = session(minutes: 15, retroactive: true)
        let outcome = CoinAward.award(
            session: logged, habit: habit, policy: .default, streak: .empty)
        #expect(outcome.metStandard)
        #expect(outcome.coins > 0)
        #expect(logged.wasRetroactive)
    }

    @Test("Paused time does not earn")
    func pausedTimeDoesNotEarn() {
        // Pause exists because it is a competitor's most-requested missing feature and users
        // currently "cheat the system" without it — but paused minutes are not worked minutes.
        let paused = HabitSession(
            habitID: habit.id, startedAt: .fixture,
            endedAt: Date.fixture.addingTimeInterval(3600),
            activeSeconds: 5 * 60, pausedSeconds: 55 * 60
        )
        let outcome = CoinAward.award(
            session: paused, habit: habit, policy: .default, streak: .empty)
        #expect(!outcome.metStandard, "5 active minutes should not meet a 10-minute target")
    }
}
