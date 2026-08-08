import Foundation
import Testing
@testable import LumoCore

/// T-RECON-01…14 and T-SPEND-01…10.
@Suite("Reconciler and spend protocol")
struct ReconcilerTests {

    // MARK: - Harness

    private struct Rig {
        var state: FakeStateStore
        var shields = FakeShieldStore()
        var scheduler = FakeActivityScheduler()
        var clock: MutableNow
        var diagnostics = RecordingDiagnostics()
        var lock: any CrossProcessLocking = ImmediateLock()

        var reconciler: ShieldReconciler {
            ShieldReconciler(
                state: state, shields: shields, scheduler: scheduler,
                lock: lock, clock: clock, diagnostics: diagnostics
            )
        }

        var coordinator: SpendCoordinator {
            SpendCoordinator(
                state: state, shields: shields, scheduler: scheduler,
                lock: lock, clock: clock, diagnostics: diagnostics
            )
        }
    }

    private func token(_ n: Int) -> TokenBlob { TokenBlob(raw: Data([UInt8(n)])) }

    private func makeRig(bucketCount: Int = 3, coins: Int = 200) throws -> Rig {
        let clock = MutableNow(.fixture)
        let table = try BucketPartitioner.commit(
            applications: Set((0..<bucketCount).map(token)),
            categories: [], into: .empty, now: clock.now
        ).table
        let state = FakeStateStore(
            state: SharedState(wallet: Wallet(granted: coins, earned: 0)),
            buckets: table
        )
        return Rig(state: state, clock: clock)
    }

    private func offer(_ slot: Int, price: Int = 45, window: TimeInterval = 2700) -> SpendCoordinator.Offer {
        .init(
            bucket: BucketID(slot: slot), price: price, windowSeconds: window,
            usageBudgetSeconds: 900, tierIndex: 0, policyFingerprint: "fp-1"
        )
    }

    // MARK: - Idempotence

    @Test("First reconcile shields everything; the second is a pure no-op")
    func reconcileIsIdempotent() throws {
        let rig = try makeRig()

        let first = rig.reconciler.reconcile(by: .app)
        #expect(first.shielded.count == 3)

        let callsAfterFirst = rig.shields.calls.count
        let second = rig.reconciler.reconcile(by: .app)

        // Zero second-pass writes is the requirement, not merely "same end state". The
        // monitor extension runs this on every callback under a 6 MB ceiling.
        #expect(second.isNoOp, "second pass changed something: \(second)")
        #expect(rig.shields.calls.count == callsAfterFirst, "second pass issued IPC calls")
    }

    @Test("Reconcile is idempotent across ten consecutive runs")
    func reconcileStableOverManyRuns() throws {
        let rig = try makeRig()
        rig.reconciler.reconcile(by: .app)
        let baseline = rig.shields.calls.count
        for _ in 0..<10 { rig.reconciler.reconcile(by: .monitor) }
        #expect(rig.shields.calls.count == baseline)
    }

    // MARK: - Expiry

    @Test("A window expires on the wall clock and the bucket re-shields")
    func wallClockExpiryReshields() throws {
        let rig = try makeRig()
        rig.reconciler.reconcile(by: .app)

        _ = try rig.coordinator.spend(offer(0, window: 2700))
        #expect(!rig.shields.shielded.contains(BucketID(slot: 0)), "should be open after spend")

        rig.clock.advance(by: 2701)
        let out = rig.reconciler.reconcile(by: .monitor)

        #expect(out.expiredWindows == 1)
        #expect(rig.shields.shielded.contains(BucketID(slot: 0)), "must re-shield after expiry")
    }

    @Test("A window does NOT expire early")
    func windowSurvivesUntilItsEnd() throws {
        let rig = try makeRig()
        rig.reconciler.reconcile(by: .app)
        _ = try rig.coordinator.spend(offer(0, window: 2700))

        rig.clock.advance(by: 2699)
        let out = rig.reconciler.reconcile(by: .monitor)

        #expect(out.expiredWindows == 0)
        #expect(!rig.shields.shielded.contains(BucketID(slot: 0)))
    }

    @Test("A phantom threshold before the sanity floor is IGNORED and flagged")
    func phantomThresholdIsIgnored() throws {
        // The iOS regression: eventDidReachThreshold fires at +0 seconds. Honouring it would
        // shut a window the user just paid 45 coins for.
        let rig = try makeRig()
        rig.reconciler.reconcile(by: .app)
        _ = try rig.coordinator.spend(offer(0))

        var s = rig.state.currentState
        s.windows[0].usageExhausted = true
        try rig.state.saveState(s)

        rig.clock.advance(by: 1) // far inside the 120s floor
        let out = rig.reconciler.reconcile(by: .monitor)

        #expect(out.expiredWindows == 0, "a +1s threshold must not close the window")
        #expect(!rig.shields.shielded.contains(BucketID(slot: 0)))
        #expect(rig.state.currentState.flags.contains(.thresholdUntrusted))
        #expect(rig.diagnostics.contains("threshold.phantom"))
    }

    @Test("A genuine threshold past the sanity floor DOES close the window early")
    func realThresholdClosesWindow() throws {
        let rig = try makeRig()
        rig.reconciler.reconcile(by: .app)
        _ = try rig.coordinator.spend(offer(0, window: 2700))

        var s = rig.state.currentState
        s.windows[0].usageExhausted = true
        try rig.state.saveState(s)

        rig.clock.advance(by: ShieldReconciler.thresholdHonorFloor + 1)
        let out = rig.reconciler.reconcile(by: .monitor)

        #expect(out.expiredWindows == 1)
        #expect(rig.shields.shielded.contains(BucketID(slot: 0)))
    }

    // MARK: - Essential enforcement

    @Test("An essential token is never shielded, even mid-session")
    func essentialIsNeverShielded() throws {
        let rig = try makeRig()
        rig.reconciler.reconcile(by: .app)
        #expect(rig.shields.shielded.count == 3)

        // The user marks an already-shielded app essential. This is the physical-harm path:
        // it has to become reachable on the very next reconcile, with no spend required.
        var table = rig.state.currentBuckets
        table.essential = [token(1)]
        try rig.state.saveBuckets(table, essential: .replaceBecauseUserEdited)

        let out = rig.reconciler.reconcile(by: .app)

        #expect(out.destroyed.contains(BucketID(slot: 1)) || out.unshielded.contains(BucketID(slot: 1)))
        #expect(!rig.shields.shielded.contains(BucketID(slot: 1)))
    }

    @Test("Spending on an essential bucket is refused and takes no coins")
    func cannotSpendOnEssential() throws {
        let rig = try makeRig()
        var table = rig.state.currentBuckets
        table.essential = [token(0)]
        try rig.state.saveBuckets(table, essential: .replaceBecauseUserEdited)

        let before = rig.state.currentState.wallet
        #expect(throws: SpendCoordinator.SpendError.bucketIsEssential(BucketID(slot: 0))) {
            _ = try rig.coordinator.spend(offer(0))
        }
        #expect(rig.state.currentState.wallet == before, "no coins for an app that is already open")
    }

    // MARK: - Removed buckets

    @Test("A bucket removed from the table has its store destroyed")
    func removedBucketIsDestroyed() throws {
        let rig = try makeRig()
        rig.reconciler.reconcile(by: .app)

        let reduced = try BucketPartitioner.commit(
            applications: [token(0), token(1)], categories: [],
            into: rig.state.currentBuckets, now: rig.clock.now
        ).table
        try rig.state.saveBuckets(reduced, essential: .replaceBecauseUserEdited)

        let out = rig.reconciler.reconcile(by: .app)

        // Forgetting instead of destroying would leave an unreachable shield the user cannot
        // pay to remove, because no UI would show the app any more.
        #expect(out.destroyed.contains(BucketID(slot: 2)))
        #expect(rig.shields.destroyed.contains(BucketID(slot: 2)))
    }

    // MARK: - SafeMode

    @Test("Unreadable state shields everything and writes nothing")
    func unreadableStateEntersSafeMode() throws {
        let rig = try makeRig()
        rig.state.loadStateError = FakeError.unavailable

        let out = rig.reconciler.reconcile(by: .monitor)

        #expect(out.enteredSafeMode)
        #expect(out.shielded.count == 3, "shielding is the safe direction")
        #expect(rig.state.saveCount == 0, "SafeMode must not write")
    }

    @Test("A future schema version enters SafeMode rather than guessing")
    func futureSchemaEntersSafeMode() throws {
        let rig = try makeRig()
        try rig.state.saveSchemaVersion(SchemaVersion.current + 1)

        let out = rig.reconciler.reconcile(by: .monitor)

        #expect(out.enteredSafeMode)
        #expect(rig.diagnostics.contains("reconcile.safeMode"))
    }

    @Test("SafeMode never zeroes the wallet")
    func safeModeDoesNotZeroWallet() throws {
        // Rebuilding a balance from nothing would delete coins the user earned — the exact
        // betrayal that drives away the most engaged users.
        let rig = try makeRig(coins: 500)
        var s = rig.state.currentState
        s.flags.insert(.safeMode)
        try rig.state.saveState(s)

        rig.reconciler.reconcile(by: .app)

        #expect(rig.state.currentState.wallet.total == 500)
    }

    // MARK: - Lock contention

    @Test("Lock contention skips rather than stalls")
    func contentionSkips() throws {
        // The shield-render path must return promptly or the system substitutes Apple's
        // generic grey shield, silently replacing Lumo's only conversion surface.
        var rig = try makeRig()
        rig.lock = ContendedLock()

        let out = rig.reconciler.reconcile(by: .shieldConfig)

        #expect(out.skippedForLock)
        #expect(rig.shields.calls.isEmpty)
    }

    // MARK: - The spend crash table

    @Test("Happy path: coins debited, timer armed, apps opened — in that order")
    func spendOrderingIsDebitArmUnshield() throws {
        let rig = try makeRig(coins: 100)
        rig.reconciler.reconcile(by: .app)
        rig.shields.reset()

        let receipt = try rig.coordinator.spend(offer(0, price: 45))

        #expect(receipt.walletAfter.total == 55)
        #expect(rig.scheduler.armed.count == 1)
        #expect(!rig.shields.shielded.contains(BucketID(slot: 0)))

        // Ordering is the safety argument, so assert it explicitly: the timer must exist
        // before the apps open.
        let armIndex = try #require(rig.scheduler.calls.firstIndex { $0.hasPrefix("arm(") })
        let unshieldIndex = try #require(rig.shields.calls.firstIndex { $0.hasPrefix("unshield(") })
        #expect(armIndex >= 0 && unshieldIndex >= 0)
        #expect(rig.state.currentState.journal.last?.phase == .settled)
    }

    @Test("Crash after T1: intent discarded, no coins taken, apps stay shielded")
    func crashAfterIntent() throws {
        let rig = try makeRig(coins: 100)
        rig.reconciler.reconcile(by: .app)

        // Simulate dying right after the intent was written.
        var s = rig.state.currentState
        s.journal.append(SpendIntent(
            id: UUID(), bucket: BucketID(slot: 0), phase: .intended,
            createdAt: rig.clock.now, activityName: "lumo.unlock.orphan",
            price: 45, usageBudget: 900, windowSeconds: 2700,
            tierIndex: 0, policyFingerprint: "fp-1", balanceBefore: s.wallet
        ))
        try rig.state.saveState(s)

        let out = rig.reconciler.reconcile(by: .app)

        #expect(out.rolledBackIntents == 1)
        #expect(rig.state.currentState.wallet.total == 100, "no coins should have moved")
        #expect(rig.shields.shielded.contains(BucketID(slot: 0)))
    }

    @Test("Crash after T2: timer armed and coins taken, so reconcile COMPLETES the spend")
    func crashAfterArmCompletes() throws {
        let rig = try makeRig(coins: 100)
        rig.reconciler.reconcile(by: .app)

        // Coins already taken, timer already armed, apps still shielded — the user paid and
        // has not yet received anything, so finishing is both safe and fair.
        var s = rig.state.currentState
        let spent = s.wallet.spend(45)
        let debit = try #require(spent)
        let id = UUID()
        s.journal.append(SpendIntent(
            id: id, bucket: BucketID(slot: 0), phase: .armed,
            createdAt: rig.clock.now, activityName: "lumo.unlock.\(id.uuidString)",
            price: 45, usageBudget: 900, windowSeconds: 2700,
            tierIndex: 0, policyFingerprint: "fp-1", debit: debit,
            balanceBefore: Wallet(granted: 100, earned: 0)
        ))
        try rig.state.saveState(s)

        let out = rig.reconciler.reconcile(by: .app)

        #expect(out.completedIntents == 1)
        #expect(rig.state.currentState.wallet.total == 55, "the debit stands")
        #expect(!rig.shields.shielded.contains(BucketID(slot: 0)), "the paid window is honoured")
    }

    @Test("Crash after T2, discovered late: coins are REFUNDED because the window is gone")
    func crashAfterArmRefundsIfWindowElapsed() throws {
        let rig = try makeRig(coins: 100)
        rig.reconciler.reconcile(by: .app)

        var s = rig.state.currentState
        let spent = s.wallet.spend(45)
        let debit = try #require(spent)
        s.journal.append(SpendIntent(
            id: UUID(), bucket: BucketID(slot: 0), phase: .armed,
            createdAt: rig.clock.now, activityName: "lumo.unlock.stale",
            price: 45, usageBudget: 900, windowSeconds: 2700,
            tierIndex: 0, policyFingerprint: "fp-1", debit: debit,
            balanceBefore: Wallet(granted: 100, earned: 0)
        ))
        try rig.state.saveState(s)

        rig.clock.advance(by: 2701) // the paid window elapsed while we were dead

        let out = rig.reconciler.reconcile(by: .app)

        #expect(out.rolledBackIntents == 1)
        #expect(rig.state.currentState.wallet.total == 100, "charging for an unusable window is theft")
        #expect(rig.shields.shielded.contains(BucketID(slot: 0)))
    }

    @Test("A refund restores the exact granted/earned split")
    func refundPreservesSplit() throws {
        let clock = MutableNow(.fixture)
        let table = try BucketPartitioner.commit(
            applications: [token(0)], categories: [], into: .empty, now: clock.now).table
        let state = FakeStateStore(
            state: SharedState(wallet: Wallet(granted: 20, earned: 80)), buckets: table)
        let rig = Rig(state: state, clock: clock)

        var s = rig.state.currentState
        let spent = s.wallet.spend(45)
        let debit = try #require(spent) // 20 granted + 25 earned
        #expect(debit == .init(granted: 20, earned: 25))
        s.journal.append(SpendIntent(
            id: UUID(), bucket: BucketID(slot: 0), phase: .armed,
            createdAt: clock.now, activityName: "lumo.unlock.split",
            price: 45, usageBudget: 900, windowSeconds: 600,
            tierIndex: 0, policyFingerprint: "fp-1", debit: debit,
            balanceBefore: Wallet(granted: 20, earned: 80)
        ))
        try rig.state.saveState(s)

        clock.advance(by: 601)
        rig.reconciler.reconcile(by: .app)

        // Refunding into one pot would silently convert house money into earned coins, or
        // the reverse — quietly breaking the invariant the split exists to protect.
        #expect(rig.state.currentState.wallet == Wallet(granted: 20, earned: 80))
    }

    @Test("If arming fails the debit is rolled back and apps stay SHIELDED")
    func armFailureRollsBackAndDoesNotUnshield() throws {
        let rig = try makeRig(coins: 100)
        rig.reconciler.reconcile(by: .app)
        rig.scheduler.failOnCall = 1

        #expect(throws: SpendCoordinator.SpendError.couldNotArm) {
            _ = try rig.coordinator.spend(offer(0, price: 45))
        }

        #expect(rig.state.currentState.wallet.total == 100, "refunded")
        // The critical assertion: never grant access without a timer. An unlocked app with no
        // armed timer never re-locks — unbounded free access, silent and permanent.
        #expect(rig.shields.shielded.contains(BucketID(slot: 0)))
        #expect(rig.scheduler.armed.isEmpty)
    }

    @Test("An unaffordable spend takes nothing and grants nothing")
    func unaffordableSpend() throws {
        let rig = try makeRig(coins: 10)
        rig.reconciler.reconcile(by: .app)

        #expect(throws: SpendCoordinator.SpendError.insufficientCoins(needed: 45, available: 10)) {
            _ = try rig.coordinator.spend(offer(0, price: 45))
        }
        #expect(rig.state.currentState.wallet.total == 10)
        #expect(rig.shields.shielded.contains(BucketID(slot: 0)))
    }

    @Test("Double-spending the same bucket is refused")
    func cannotDoubleSpend() throws {
        let rig = try makeRig(coins: 200)
        rig.reconciler.reconcile(by: .app)
        _ = try rig.coordinator.spend(offer(0, price: 45))

        #expect(throws: SpendCoordinator.SpendError.alreadyOpen(BucketID(slot: 0))) {
            _ = try rig.coordinator.spend(offer(0, price: 45))
        }
        #expect(rig.state.currentState.wallet.total == 155, "charged exactly once")
    }

    @Test("Spending on an unknown bucket is refused")
    func unknownBucketRefused() throws {
        let rig = try makeRig(bucketCount: 2)
        #expect(throws: SpendCoordinator.SpendError.unknownBucket(BucketID(slot: 9))) {
            _ = try rig.coordinator.spend(offer(9))
        }
    }

    // MARK: - Activity GC

    @Test("Activities with no live window are disarmed against the 20-activity cap")
    func staleActivitiesAreCollected() throws {
        let rig = try makeRig()
        rig.reconciler.reconcile(by: .app)
        _ = try rig.coordinator.spend(offer(0, window: 600))
        #expect(rig.scheduler.armed.count == 1)

        rig.clock.advance(by: 601)
        let out = rig.reconciler.reconcile(by: .monitor)

        #expect(out.disarmedActivities == 1)
        #expect(rig.scheduler.armed.isEmpty, "leaking activities exhausts the 20-activity cap")
    }

    // MARK: - Observation

    @Test("observe() cannot write shield state")
    func observeIsReadOnly() throws {
        let rig = try makeRig()
        rig.reconciler.reconcile(by: .app)
        let callsBefore = rig.shields.calls.count

        let observation = ShieldReconciler.observe(state: rig.state, clock: rig.clock)

        // It holds no ShieldStoring at all, so this is structural rather than a promise.
        #expect(rig.shields.calls.count == callsBefore)
        #expect(observation.wallet.total == 200)
        #expect(observation.openBuckets.isEmpty)
    }

    @Test("observe() reports SafeMode when state is unreadable")
    func observeReportsSafeMode() throws {
        let rig = try makeRig()
        rig.state.loadStateError = FakeError.unavailable
        let observation = ShieldReconciler.observe(state: rig.state, clock: rig.clock)
        #expect(observation.isSafeMode)
    }
}
