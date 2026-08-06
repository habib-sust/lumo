import Foundation
import Testing
@testable import LumoCore

/// T-TIMER-01…16.
///
/// The property under test throughout: **elapsed time is derived from timestamps**, so it is
/// correct after any interruption — backgrounding, suspension, or the app being killed outright.
/// A ticking counter would silently discard the user's work.
@Suite("Habit timer")
struct HabitTimerTests {

    private let habitID = UUID()

    private func timer(target: Int = 10) -> HabitTimer {
        HabitTimer(habitID: habitID, targetMinutes: target, startedAt: .fixture)
    }

    private func at(_ seconds: TimeInterval) -> Date {
        Date.fixture.addingTimeInterval(seconds)
    }

    // MARK: - Basic accrual

    @Test("A running timer accrues active time")
    func runningAccrues() {
        let t = timer()
        #expect(t.isRunning)
        #expect(t.activeSeconds(now: at(300)) == 300)
        #expect(t.pausedSeconds(now: at(300)) == 0)
    }

    @Test("Progress and remaining are consistent with the target")
    func progressIsConsistent() {
        let t = timer(target: 10)
        #expect(t.progress(now: at(300)) == 0.5)
        #expect(t.remainingSeconds(now: at(300)) == 300)
        #expect(!t.hasMetStandard(now: at(300)))

        #expect(t.hasMetStandard(now: at(600)))
        #expect(t.progress(now: at(600)) == 1)
        #expect(t.remainingSeconds(now: at(600)) == 0)
    }

    @Test("Progress caps at 1 rather than overflowing")
    func progressCaps() {
        let t = timer(target: 10)
        #expect(t.progress(now: at(6000)) == 1)
    }

    // MARK: - The force-quit property

    @Test("Active time is correct after a simulated force-quit")
    func survivesForceQuit() {
        // The reason none of this uses a ticking counter. Encode while running, decode later, and
        // the elapsed time must reflect real time passed — not time the process was alive for.
        let t = timer()
        let encoded = try! JSONEncoder().encode(t)

        // ... process dies, twenty minutes pass, app relaunches ...
        let restored = try! JSONDecoder().decode(HabitTimer.self, from: encoded)

        #expect(restored.isRunning)
        #expect(restored.activeSeconds(now: at(1200)) == 1200)
        #expect(restored.hasMetStandard(now: at(1200)))
    }

    @Test("A paused timer does NOT accrue while the app is dead")
    func pausedDoesNotAccrueAcrossDeath() {
        // The other half of the same property: a pause must survive too, or a force-quit while
        // paused would silently credit the user for time they did not work.
        var t = timer()
        t.pause(at: at(120))

        let restored = try! JSONDecoder().decode(HabitTimer.self, from: try! JSONEncoder().encode(t))

        #expect(restored.isPaused)
        #expect(restored.activeSeconds(now: at(9999)) == 120, "must stay at 120, not grow")
    }

    // MARK: - Pause and resume

    @Test("A pause gap counts as paused, not active")
    func pauseGapIsNotActive() {
        var t = timer()
        t.pause(at: at(120))
        t.resume(at: at(300)) // 180s paused

        #expect(t.activeSeconds(now: at(420)) == 240, "120 before + 120 after")
        #expect(t.pausedSeconds(now: at(420)) == 180)
    }

    @Test("Active plus paused always equals wall-clock elapsed")
    func activePlusPausedEqualsWallClock() {
        // The invariant that keeps the two figures honest against each other.
        var t = timer()
        t.pause(at: at(60))
        t.resume(at: at(200))
        t.pause(at: at(260))
        t.resume(at: at(500))

        let now = at(600)
        #expect(t.activeSeconds(now: now) + t.pausedSeconds(now: now) == 600)
    }

    @Test("Multiple pause cycles accumulate correctly")
    func multiplePauseCycles() {
        var t = timer()
        for i in 0..<5 {
            let base = TimeInterval(i * 200)
            t.pause(at: at(base + 60))    // 60s active
            t.resume(at: at(base + 200))  // 140s paused
        }
        // Five 60-second working stretches.
        #expect(t.activeSeconds(now: at(1000)) == 300)
    }

    @Test("Double pause is a no-op")
    func doublePauseIsNoOp() {
        // The UI and a lifecycle callback can both plausibly reach for this, and a double-pause
        // corrupting the segment list would lose time.
        var t = timer()
        t.pause(at: at(100))
        t.pause(at: at(200))
        #expect(t.activeSeconds(now: at(500)) == 100)
        #expect(t.segments.count == 1)
    }

    @Test("Double resume is a no-op")
    func doubleResumeIsNoOp() {
        var t = timer()
        t.pause(at: at(100))
        t.resume(at: at(200))
        t.resume(at: at(300))
        #expect(t.segments.count == 2)
        #expect(t.activeSeconds(now: at(400)) == 300)
    }

    @Test("Resuming a never-paused timer changes nothing")
    func resumeWhileRunningIsNoOp() {
        var t = timer()
        t.resume(at: at(50))
        #expect(t.segments.count == 1)
        #expect(t.activeSeconds(now: at(100)) == 100)
    }

    // MARK: - Clock hostility

    @Test("A backwards clock cannot produce negative active time")
    func backwardsClockIsClamped() {
        // The device clock is user-settable and can move backwards mid-session. A negative segment
        // would silently subtract from earned time.
        let t = timer()
        #expect(t.activeSeconds(now: at(-3600)) == 0)
        #expect(t.pausedSeconds(now: at(-3600)) == 0)
        #expect(t.progress(now: at(-3600)) == 0)
    }

    @Test("A backwards pause cannot close a segment before it opened")
    func backwardsPauseIsClamped() {
        var t = timer()
        t.pause(at: at(-500))
        #expect(t.activeSeconds(now: at(600)) == 0, "clamped to zero, never negative")
        #expect(t.isPaused)
    }

    @Test("Active time never decreases as the clock advances")
    func activeTimeIsMonotonic() {
        var t = timer()
        t.pause(at: at(100))
        t.resume(at: at(200))

        var previous: TimeInterval = 0
        for second in stride(from: 0.0, through: 1000.0, by: 7.0) {
            let value = t.activeSeconds(now: at(second))
            #expect(value >= previous, "dropped from \(previous) to \(value) at t=\(second)")
            previous = value
        }
    }

    // MARK: - Finishing

    @Test("Finishing produces a session with the right split")
    func finishProducesSession() {
        var t = timer()
        t.pause(at: at(300))
        t.resume(at: at(400))
        let session = t.finish(at: at(700))

        #expect(session.habitID == habitID)
        #expect(session.activeSeconds == 600)
        #expect(session.pausedSeconds == 100)
        #expect(!session.wasRetroactive)
        #expect(session.activeMinutes == 10)
    }

    @Test("Finishing while already paused keeps the paused total")
    func finishWhilePaused() {
        var t = timer()
        t.pause(at: at(300))
        let session = t.finish(at: at(900))

        #expect(session.activeSeconds == 300, "the pause gap must not become active time")
        #expect(session.pausedSeconds == 600)
    }

    @Test("A finished session earns exactly what the timer measured")
    func finishFeedsTheAward() {
        // End-to-end with the award path, so the two cannot drift apart.
        var t = timer(target: 10)
        let session = t.finish(at: at(600))
        let habit = HabitSpec(id: habitID, name: "Dishes", targetMinutes: 10)

        let outcome = CoinAward.award(
            session: session, habit: habit, policy: .default, streak: .empty)

        #expect(outcome.metStandard)
        #expect(outcome.coins == 10 * Policy.default.coinsPerHabitMinute)
    }

    @Test("The target is frozen at commencement")
    func targetIsFrozen() {
        // Editing a habit mid-session must not retroactively move the bar the user is already
        // working against.
        let t = timer(target: 10)
        #expect(t.targetMinutes == 10)
        // The type has no setter for it — asserted by the `let` and by this test's existence.
        #expect(t.hasMetStandard(now: at(600)))
    }

    // MARK: - Retroactive

    @Test("A retroactive session is flagged and correctly dated")
    func retroactiveSession() {
        let session = HabitTimer.retroactiveSession(
            habitID: habitID, minutes: 25, endedAt: at(0))

        #expect(session.wasRetroactive)
        #expect(session.activeSeconds == 1500)
        #expect(session.pausedSeconds == 0)
        #expect(session.startedAt == at(-1500))
    }

    @Test("A retroactive session earns like a timed one")
    func retroactiveEarns() {
        // Deliberate: refusing to pay for logged-after-the-fact work is how the missing-feature
        // complaint becomes a churn reason.
        let session = HabitTimer.retroactiveSession(habitID: habitID, minutes: 15, endedAt: at(0))
        let habit = HabitSpec(id: habitID, name: "Read", targetMinutes: 10)
        let outcome = CoinAward.award(
            session: session, habit: habit, policy: .default, streak: .empty)

        #expect(outcome.metStandard)
        #expect(outcome.coins > 0)
    }

    @Test("A negative retroactive duration is clamped rather than trusted")
    func retroactiveNegativeIsClamped() {
        let session = HabitTimer.retroactiveSession(habitID: habitID, minutes: -30, endedAt: at(0))
        #expect(session.activeSeconds == 0)
    }

    // MARK: - Codable

    @Test("A timer round-trips, and decodes from an empty object")
    func codable() throws {
        var t = timer()
        t.pause(at: at(100))
        t.resume(at: at(200))

        let round = try JSONDecoder().decode(
            HabitTimer.self, from: try JSONEncoder().encode(t))
        #expect(round == t)

        // Tolerant like every other payload: a decode failure here would lose a session in progress.
        let empty = try JSONDecoder().decode(HabitTimer.self, from: Data("{}".utf8))
        #expect(empty.segments.isEmpty)
        #expect(!empty.isRunning)
    }
}
