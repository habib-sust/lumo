import Foundation
import Testing
@testable import LumoCore

/// T-EMERGENCY-01…14.
///
/// The rule under test throughout: **never trap the user.** Competitor reviews include
/// "impossible to delete" and "one of the most dangerous applications I have ever installed".
@Suite("Emergency unlock and teardown")
struct EmergencyTests {

    private func token(_ n: Int) -> TokenBlob { TokenBlob(raw: Data([UInt8(n)])) }

    private struct Rig {
        var state: FakeStateStore
        var shields = FakeShieldStore()
        var scheduler = FakeActivityScheduler()
        var clock: MutableNow
        var diagnostics = RecordingDiagnostics()
        var lock: any CrossProcessLocking = ImmediateLock()

        var emergency: EmergencyUnlock {
            EmergencyUnlock(
                state: state, shields: shields, scheduler: scheduler,
                lock: lock, clock: clock, diagnostics: diagnostics
            )
        }
        var reconciler: ShieldReconciler {
            ShieldReconciler(
                state: state, shields: shields, scheduler: scheduler,
                lock: lock, clock: clock, diagnostics: diagnostics
            )
        }
    }

    private func makeRig(coins: Int = 0) throws -> Rig {
        let clock = MutableNow(.fixture)
        let table = try BucketPartitioner.commit(
            applications: [token(0), token(1)], categories: [], into: .empty, now: clock.now
        ).table
        return Rig(
            state: FakeStateStore(
                state: SharedState(wallet: Wallet(granted: coins, earned: 0)), buckets: table),
            clock: clock
        )
    }

    // MARK: - Friction schedule

    @Test("The delay escalates across the day and then plateaus")
    func delayEscalatesThenPlateaus() {
        let policy = FrictionPolicy(escalatingDelays: [20, 30, 45])
        #expect(policy.delaySeconds(priorUsesToday: 0) == 20)
        #expect(policy.delaySeconds(priorUsesToday: 1) == 30)
        #expect(policy.delaySeconds(priorUsesToday: 2) == 45)
        // Plateaus rather than growing without bound — escalation is meant to cost attention,
        // not to become a de facto refusal.
        #expect(policy.delaySeconds(priorUsesToday: 50) == 45)
    }

    @Test("The delay function is total, even for nonsense input")
    func delayIsTotal() {
        // This sits in front of a safety feature, so it must never trap.
        let policy = FrictionPolicy.default
        #expect(policy.delaySeconds(priorUsesToday: -5) == policy.escalatingDelays[0])
        #expect(policy.delaySeconds(priorUsesToday: Int.max) == policy.escalatingDelays.last)
    }

    @Test("A mis-ordered or negative config cannot make a later use cheaper")
    func configIsNormalised() {
        let policy = FrictionPolicy(escalatingDelays: [45, -10, 20])
        #expect(policy.escalatingDelays == [0, 20, 45])
        #expect(policy.delaySeconds(priorUsesToday: 0) <= policy.delaySeconds(priorUsesToday: 2))
    }

    @Test("Emergency access is always available, by construction")
    func alwaysAvailable() {
        // Named rather than implied, so any future attempt to add a cap has to delete this and
        // confront why it exists.
        #expect(FrictionPolicy.default.isAlwaysAvailable)
    }

    // MARK: - Day rollover

    @Test("The daily counter rolls over at local midnight")
    func counterRollsOver() {
        var log = EmergencyLog.empty
        let day1 = Date.fixture
        log.record(now: day1)
        log.record(now: day1)
        #expect(log.usesToday == 2)

        let day2 = day1.addingTimeInterval(26 * 3600)
        log.record(now: day2)
        #expect(log.usesToday == 1, "a new day starts fresh")
        #expect(log.lifetimeUses == 3, "lifetime keeps counting for harm telemetry")
    }

    @Test("Uses on another day read as zero")
    func usesOnOtherDayIsZero() {
        var log = EmergencyLog.empty
        log.record(now: .fixture)
        #expect(log.uses(on: .fixture) == 1)
        #expect(log.uses(on: Date.fixture.addingTimeInterval(-48 * 3600)) == 0)
    }

    // MARK: - Granting

    @Test("An emergency unlock costs nothing and opens the app")
    func grantIsFree() throws {
        let rig = try makeRig(coins: 0)
        rig.reconciler.reconcile(by: .app)
        #expect(rig.shields.shielded.contains(BucketID(slot: 0)))

        let window = try rig.emergency.grant(bucket: BucketID(slot: 0))

        #expect(window.origin == .emergency)
        #expect(rig.state.currentState.wallet.total == 0, "no coins were needed")
        #expect(!rig.shields.shielded.contains(BucketID(slot: 0)))
    }

    @Test("An emergency unlock works with an empty wallet")
    func worksWithZeroCoins() throws {
        // The entire point. Someone who needs Maps or a banking app must not be stranded by an
        // empty balance.
        let rig = try makeRig(coins: 0)
        rig.reconciler.reconcile(by: .app)
        _ = try rig.emergency.grant(bucket: BucketID(slot: 0))
        #expect(rig.state.currentState.windows.count == 1)
    }

    @Test("Earned coins are never touched")
    func earnedIsUntouched() throws {
        let clock = MutableNow(.fixture)
        let table = try BucketPartitioner.commit(
            applications: [token(0)], categories: [], into: .empty, now: clock.now).table
        let rig = Rig(
            state: FakeStateStore(
                state: SharedState(wallet: Wallet(granted: 10, earned: 250)), buckets: table),
            clock: clock)

        _ = try rig.emergency.grant(bucket: BucketID(slot: 0))
        #expect(rig.state.currentState.wallet == Wallet(granted: 10, earned: 250))
    }

    @Test("A free window still arms a timer, so it closes on its own")
    func freeWindowStillHasATimer() throws {
        // "Free" must not mean "unbounded". Access with no armed timer never re-locks.
        let rig = try makeRig()
        rig.reconciler.reconcile(by: .app)
        _ = try rig.emergency.grant(bucket: BucketID(slot: 0))

        #expect(rig.scheduler.armed.count == 1)

        rig.clock.advance(by: TimeInterval(FrictionPolicy.default.windowMinutes * 60) + 1)
        let out = rig.reconciler.reconcile(by: .monitor)
        #expect(out.expiredWindows == 1)
        #expect(rig.shields.shielded.contains(BucketID(slot: 0)), "must re-shield like any window")
    }

    @Test("Repeated use is never refused, only slower")
    func repeatedUseIsNeverRefused() throws {
        let rig = try makeRig()
        rig.reconciler.reconcile(by: .app)

        // Ten in a row. Every one succeeds; only the required delay grows.
        for i in 0..<10 {
            let bucket = BucketID(slot: i % 2)
            rig.clock.advance(by: 60 * 60)
            _ = rig.reconciler.reconcile(by: .app) // expire the previous window
            let window = try rig.emergency.grant(bucket: bucket)
            #expect(window.origin == .emergency)
        }
        #expect(rig.state.currentState.emergency.lifetimeUses == 10)
    }

    @Test("The required delay reflects prior uses today")
    func delayReflectsPriorUses() throws {
        let rig = try makeRig()
        let policy = FrictionPolicy(escalatingDelays: [20, 30, 45])
        #expect(rig.emergency.requiredDelaySeconds(policy: policy) == 20)

        _ = try rig.emergency.grant(bucket: BucketID(slot: 0), policy: policy)
        #expect(rig.emergency.requiredDelaySeconds(policy: policy) == 30)
    }

    @Test("Unreadable state still yields a usable delay rather than trapping")
    func unreadableStateStillGrantsADelay() throws {
        let rig = try makeRig()
        rig.state.loadStateError = FakeError.unavailable
        // Erring toward the user: corrupt data must not strand someone.
        #expect(rig.emergency.requiredDelaySeconds() == FrictionPolicy.default.escalatingDelays[0])
    }

    @Test("Granting is recorded as a harm metric, not an engagement one")
    func grantIsRecorded() throws {
        // Heavy reliance here means the strictness tier is wrong for this user — a signal to act
        // on rather than hide.
        let rig = try makeRig()
        _ = try rig.emergency.grant(bucket: BucketID(slot: 0))
        #expect(rig.diagnostics.contains("emergency.granted"))
    }

    // MARK: - Teardown

    @Test("Unlock everything destroys every shield and stops every timer")
    func teardownReleasesEverything() throws {
        let rig = try makeRig(coins: 50)
        rig.reconciler.reconcile(by: .app)
        _ = try rig.emergency.grant(bucket: BucketID(slot: 0))
        #expect(!rig.scheduler.armed.isEmpty)

        let released = rig.emergency.unlockEverything()

        #expect(released == 2)
        #expect(rig.shields.shielded.isEmpty)
        #expect(rig.scheduler.armed.isEmpty, "a leftover timer would re-shield after the user left")
        #expect(rig.state.currentState.windows.isEmpty)
    }

    @Test("Teardown preserves the wallet and history")
    func teardownPreservesProgress() throws {
        // Someone stepping away should be able to come back to their coins and streak intact.
        // Wiping them would punish the act of leaving.
        let clock = MutableNow(.fixture)
        let table = try BucketPartitioner.commit(
            applications: [token(0)], categories: [], into: .empty, now: clock.now).table
        let rig = Rig(
            state: FakeStateStore(
                state: SharedState(wallet: Wallet(granted: 40, earned: 160)), buckets: table),
            clock: clock)

        rig.emergency.unlockEverything()
        #expect(rig.state.currentState.wallet == Wallet(granted: 40, earned: 160))
    }

    @Test("Teardown succeeds even when the lock is contended")
    func teardownSurvivesContention() throws {
        // Asymmetric failure modes: a racy teardown might redundantly clear a store, whereas
        // refusing to release leaves someone locked out of their own phone.
        var rig = try makeRig()
        rig.reconciler.reconcile(by: .app)
        rig.lock = ContendedLock()

        let released = rig.emergency.unlockEverything()

        #expect(released == 2, "the user asked to be released; contention is not a reason to refuse")
        #expect(rig.shields.shielded.isEmpty)
        #expect(rig.diagnostics.contains("teardown.forced"))
    }

    @Test("Teardown is idempotent")
    func teardownIsIdempotent() throws {
        let rig = try makeRig()
        rig.reconciler.reconcile(by: .app)
        rig.emergency.unlockEverything()
        rig.emergency.unlockEverything()
        #expect(rig.shields.shielded.isEmpty)
    }

    // MARK: - Schema compatibility

    @Test("The new emergency field decodes from a payload that predates it")
    func emergencyFieldDecodesFromOlderPayload() throws {
        // Adding a field with a decodeIfPresent default is what lets this ship without a schema
        // bump — and the guarantee is worth asserting rather than assuming.
        let legacy = #"{"wallet":{"granted":5,"earned":5},"windows":[]}"#
        let decoded = try JSONDecoder().decode(SharedState.self, from: Data(legacy.utf8))
        #expect(decoded.emergency == .empty)
        #expect(decoded.wallet.total == 10)
    }
}
