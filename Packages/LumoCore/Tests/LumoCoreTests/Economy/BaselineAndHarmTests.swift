import Foundation
import Testing
@testable import LumoCore

/// T-BASELINE-01…12 and T-HARM-01…10.
@Suite("Baseline ladder and harm telemetry")
struct BaselineAndHarmTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func day(_ offset: Int) -> Date {
        Date.fixture.addingTimeInterval(TimeInterval(offset * 86_400))
    }

    // MARK: - Ladder recording

    @Test("Recording is idempotent and monotonic within a day")
    func recordIsMonotonicPerDay() {
        // Thresholds fire in ascending order as usage accrues, so a later higher rung replaces the
        // earlier one rather than appending a second entry for the same day.
        var cal = BaselineCalibration()
        cal.record(highestRung: 15, on: day(0), calendar: calendar)
        cal.record(highestRung: 60, on: day(0), calendar: calendar)
        cal.record(highestRung: 30, on: day(0), calendar: calendar)

        #expect(cal.observedDays == 1)
        #expect(cal.days.first?.minutes == 60, "a lower rung must not overwrite a higher one")
    }

    @Test("A day where nothing fired is still an observation")
    func nilRungStillCountsAsADay() {
        // Otherwise a light user would never reach `isReady` and would sit on defaults forever with
        // no explanation.
        var cal = BaselineCalibration()
        for offset in 0..<3 { cal.record(highestRung: nil, on: day(offset), calendar: calendar) }
        #expect(cal.observedDays == 3)
        #expect(cal.isReady)
    }

    @Test("History is bounded")
    func historyIsBounded() {
        // This lives in a blob the monitor extension decodes under a 6 MB ceiling.
        var cal = BaselineCalibration()
        for offset in 0..<40 { cal.record(highestRung: 30, on: day(offset), calendar: calendar) }
        #expect(cal.observedDays <= 14)
    }

    // MARK: - Inference

    @Test("Nothing is inferred before the calibration window closes")
    func notReadyBeforeThreeDays() {
        var cal = BaselineCalibration()
        cal.record(highestRung: 60, on: day(0), calendar: calendar)
        cal.record(highestRung: 60, on: day(1), calendar: calendar)

        #expect(!cal.isReady)
        #expect(cal.inferredScrollMinutes() == nil, "must stay on defaults until measured")
        #expect(cal.daysRemaining == 1)
    }

    @Test("The median rung is used, so one unusual day cannot move the price")
    func medianResistsOutliers() {
        var cal = BaselineCalibration()
        cal.record(highestRung: 30, on: day(0), calendar: calendar)
        cal.record(highestRung: 30, on: day(1), calendar: calendar)
        // A flight, a sick day, a holiday.
        cal.record(highestRung: 120, on: day(2), calendar: calendar)

        #expect(cal.inferredScrollMinutes() == 30, "the outlier must not dominate")
    }

    @Test("The LOW end of a bucket is used, which is the safe direction")
    func inferenceErrsLow() {
        // A rung means usage was AT LEAST that much. Underestimating scroll makes the baseline ratio
        // larger and the price HIGHER. Overestimating makes it cheaper — and below the baseline
        // ratio the contingency stops reinforcing and becomes a punisher.
        var cal = BaselineCalibration()
        for offset in 0..<3 { cal.record(highestRung: 60, on: day(offset), calendar: calendar) }

        // 60 means "somewhere between 60 and 120". We take 60.
        #expect(cal.inferredScrollMinutes() == 60)
    }

    @Test("No signal yields NO baseline rather than a fabricated one")
    func noSignalMeansNoPersonalisation() {
        // A user who never reaches 15 minutes on their shielded apps has given us nothing to
        // personalise from. Guessing would price their economy off a fabrication.
        var cal = BaselineCalibration()
        for offset in 0..<4 { cal.record(highestRung: nil, on: day(offset), calendar: calendar) }

        #expect(cal.isReady)
        #expect(cal.inferredScrollMinutes() == nil)
        #expect(cal.baseline(habitMinutesPerDay: 20, now: .fixture) == nil)
    }

    @Test("No measured habit time also blocks personalisation")
    func zeroHabitMinutesBlocksBaseline() {
        // A zero would make the ratio zero and every unlock free.
        var cal = BaselineCalibration()
        for offset in 0..<3 { cal.record(highestRung: 60, on: day(offset), calendar: calendar) }
        #expect(cal.baseline(habitMinutesPerDay: 0, now: .fixture) == nil)
    }

    @Test("A measured baseline is marked as measured, not defaulted")
    func baselineRecordsItsProvenance() {
        // The debug panel has to be able to tell a measurement from a default, or we can never know
        // whether a user's prices were ever personalised.
        var cal = BaselineCalibration()
        for offset in 0..<3 { cal.record(highestRung: 120, on: day(offset), calendar: calendar) }

        let baseline = cal.baseline(habitMinutesPerDay: 25, now: .fixture)
        #expect(baseline?.source == .thresholdLadder)
        #expect(baseline?.scrollMinutesPerDay == 120)
        #expect(baseline?.habitMinutesPerDay == 25)
    }

    // MARK: - Repricing

    @Test("Repricing can never drop below the punisher boundary")
    func repricingStaysAdmissible() {
        // The whole reason for measuring. Personalisation that produced a punisher price would be
        // worse than not personalising at all.
        let measured = Baseline(
            scrollMinutesPerDay: 240, habitMinutesPerDay: 10,
            source: .thresholdLadder, observedAt: .fixture)
        let policy = Policy.default.repriced(for: measured)

        #expect(!Pricing.isPunisher(ratio: policy.requiredRatio, baseline: measured))
        #expect(!Pricing.hasRatioStrain(ratio: policy.requiredRatio, baseline: measured))
        #expect(policy.baseline == measured)
    }

    @Test("Repricing re-derives the ratio rather than carrying the old one over")
    func repricingRederivesRatio() {
        // A ratio admissible against the old baseline may be a punisher against the new one.
        let heavy = Baseline(scrollMinutesPerDay: 300, habitMinutesPerDay: 20,
                             source: .thresholdLadder, observedAt: .fixture)
        let light = Baseline(scrollMinutesPerDay: 30, habitMinutesPerDay: 20,
                             source: .thresholdLadder, observedAt: .fixture)

        let a = Policy.default.repriced(for: heavy)
        let b = Policy.default.repriced(for: light)
        #expect(a.requiredRatio != b.requiredRatio)
        #expect(a.requiredRatio < b.requiredRatio, "a heavier scroller needs a gentler ratio")
    }

    @Test("Repricing preserves everything that is not price-derived")
    func repricingPreservesOtherPolicy() {
        let custom = Policy(coinsPerHabitMinute: 5, tierMinutes: [10, 20], weeklyGrant: 200,
                            missDeduction: 15, weeklyRampFactor: 1.2)
        let measured = Baseline(scrollMinutesPerDay: 90, habitMinutesPerDay: 15,
                                source: .thresholdLadder, observedAt: .fixture)
        let repriced = custom.repriced(for: measured)

        #expect(repriced.coinsPerHabitMinute == 5)
        #expect(repriced.tierMinutes == [10, 20])
        #expect(repriced.weeklyGrant == 200)
        #expect(repriced.weeklyRampFactor == 1.2)
    }

    // MARK: - Harm telemetry

    @Test("Rates stay nil until there is enough data to mean anything")
    func ratesRequireAFloor() {
        // Reporting "0% completion" off one abandoned session would trip an alarm that says nothing.
        var m = HarmMetrics(windowStart: .fixture)
        m.sessionsStarted = 2
        m.sessionsCompleted = 0
        #expect(m.completionRate == nil)
        #expect(m.averageEnjoyment == nil)
        #expect(m.enjoymentTrend == nil)
    }

    @Test("Failing your own contracts is flagged")
    func failingContractsIsFlagged() {
        // In one study 55% of clients defaulted on self-designed commitment contracts and lost
        // money. If most sessions are failing, Lumo built that.
        var m = HarmMetrics(windowStart: .fixture)
        m.sessionsStarted = 10
        m.sessionsCompleted = 3

        let concerns = HarmThresholds.concerns(for: m, grantIssued: 140, now: day(7))
        #expect(concerns.contains(.failingOwnContracts))
    }

    @Test("A healthy user trips nothing")
    func healthyUserHasNoConcerns() {
        var m = HarmMetrics(windowStart: .fixture)
        m.sessionsStarted = 10
        m.sessionsCompleted = 9
        m.emergencyUnlocks = 1
        m.grantForfeited = 10
        m.enjoymentSamples = (0..<6).map { EnjoymentSample(at: day($0), score: 4) }

        #expect(HarmThresholds.concerns(for: m, grantIssued: 140, now: day(7)).isEmpty)
    }

    @Test("Daily reliance on the emergency unlock is flagged")
    func emergencyRelianceIsFlagged() {
        // Not to restrict it — it stays unlimited — but because it means the strictness tier is
        // wrong for this user.
        var m = HarmMetrics(windowStart: .fixture)
        m.emergencyUnlocks = 12

        let concerns = HarmThresholds.concerns(for: m, grantIssued: 140, now: day(7))
        #expect(concerns.contains(.leaningOnEmergencyUnlocks))
    }

    @Test("An unreachable economy is flagged")
    func forfeitureIsFlagged() {
        // Most of the allowance expiring unused means earning is too slow, not that the user is
        // uninterested.
        var m = HarmMetrics(windowStart: .fixture)
        m.grantForfeited = 130

        let concerns = HarmThresholds.concerns(for: m, grantIssued: 140, now: day(7))
        #expect(concerns.contains(.economyUnreachable))
    }

    @Test("Declining enjoyment is flagged even when completion looks healthy")
    func enjoymentDeclineIsFlaggedIndependently() {
        // The whole point of tracking it: interrupted people compress rather than lose time, so
        // throughput metrics cannot reveal this harm. Only enjoyment can.
        var m = HarmMetrics(windowStart: .fixture)
        m.sessionsStarted = 20
        m.sessionsCompleted = 19
        m.enjoymentSamples =
            (0..<3).map { EnjoymentSample(at: day($0), score: 5) }
            + (3..<6).map { EnjoymentSample(at: day($0), score: 3) }

        let concerns = HarmThresholds.concerns(for: m, grantIssued: 140, now: day(7))
        #expect(concerns.contains(.enjoymentDeclining))
        #expect(!concerns.contains(.failingOwnContracts), "compliance was fine — that is the point")
    }

    @Test("Every concern explains what to do about it")
    func everyConcernIsActionable() {
        for concern in HarmConcern.allCases {
            #expect(!concern.explanation.isEmpty)
            // Aimed at easing off, never at pushing harder.
            let text = concern.explanation.lowercased()
            #expect(!text.contains("try harder"))
        }
    }

    @Test("Enjoyment samples are clamped and bounded")
    func enjoymentIsClampedAndBounded() {
        let out = EnjoymentSample(at: .fixture, score: 99)
        #expect(out.score == 5)
        let low = EnjoymentSample(at: .fixture, score: -3)
        #expect(low.score == 1)

        let many = HarmMetrics(
            enjoymentSamples: (0..<200).map { EnjoymentSample(at: day($0), score: 3) })
        #expect(many.enjoymentSamples.count <= 30)
    }

    @Test("Metrics round-trip and decode from an empty object")
    func metricsCodable() throws {
        var m = HarmMetrics(windowStart: .fixture)
        m.sessionsStarted = 4
        m.enjoymentSamples = [EnjoymentSample(at: .fixture, score: 4)]

        let round = try JSONDecoder().decode(
            HarmMetrics.self, from: try JSONEncoder().encode(m))
        #expect(round == m)

        let empty = try JSONDecoder().decode(HarmMetrics.self, from: Data("{}".utf8))
        #expect(empty == .empty)
    }

    @Test("Calibration round-trips and decodes from an empty object")
    func calibrationCodable() throws {
        var cal = BaselineCalibration(startedAt: .fixture)
        cal.record(highestRung: 30, on: day(0), calendar: calendar)

        let round = try JSONDecoder().decode(
            BaselineCalibration.self, from: try JSONEncoder().encode(cal))
        #expect(round == cal)

        let empty = try JSONDecoder().decode(BaselineCalibration.self, from: Data("{}".utf8))
        #expect(empty.observedDays == 0)
    }

    // MARK: - T-BASELINE-13…18: the wiring, not just the maths
    //
    // The logic above is pure and easy to test. What actually ships is the PATH — a threshold fires
    // in the monitor extension, the event name survives to the reconciler, and the measurement
    // reaches disk. Every device bug so far has been in a seam like this one, not in the maths.

    private struct Rig {
        var state: FakeStateStore
        var clock: MutableNow
        var diagnostics = RecordingDiagnostics()

        var reconciler: ShieldReconciler {
            ShieldReconciler(
                state: state, shields: FakeShieldStore(), scheduler: FakeActivityScheduler(),
                lock: ImmediateLock(), clock: clock, diagnostics: diagnostics
            )
        }
    }

    private func makeRig() -> Rig {
        Rig(state: FakeStateStore(state: .initial, buckets: .empty), clock: MutableNow(.fixture))
    }

    @Test("A ladder threshold reaching the monitor is recorded in shared state")
    func ladderEventIsRecorded() throws {
        let rig = makeRig()
        let outcome = rig.reconciler.reconcile(
            by: .monitor,
            observing: BaselineCalibration.eventName(forRung: 60)
        )

        #expect(outcome.recordedBaselineRung == 60)
        // Persisted, not merely returned. The monitor is a separate process that dies immediately
        // after; a measurement it kept in memory is a measurement nobody has.
        let stored = try rig.state.loadState()
        #expect(stored.baseline.observedDays == 1)
        #expect(stored.baseline.days.first?.minutes == 60)
    }

    @Test("A duplicate delivery of the same rung is a pure no-op")
    func duplicateLadderEventWritesNothing() throws {
        let rig = makeRig()
        rig.reconciler.reconcile(by: .monitor, observing: BaselineCalibration.eventName(forRung: 30))
        let writesAfterFirst = rig.state.saveCount

        let second = rig.reconciler.reconcile(
            by: .monitor,
            observing: BaselineCalibration.eventName(forRung: 30)
        )

        // Thresholds are documented to deliver spuriously and repeatedly. If each redelivery cost a
        // write, the monitor would be doing IPC under a 6 MB ceiling for no information at all.
        #expect(second.recordedBaselineRung == nil)
        #expect(second.isNoOp, "duplicate rung was not a no-op: \(second)")
        #expect(rig.state.saveCount == writesAfterFirst, "duplicate rung issued a write")
    }

    @Test("A higher rung the same day replaces the lower one and does write")
    func higherRungSameDayIsRecorded() throws {
        let rig = makeRig()
        rig.reconciler.reconcile(by: .monitor, observing: BaselineCalibration.eventName(forRung: 15))
        let outcome = rig.reconciler.reconcile(
            by: .monitor,
            observing: BaselineCalibration.eventName(forRung: 120)
        )

        #expect(outcome.recordedBaselineRung == 120)
        let stored = try rig.state.loadState()
        #expect(stored.baseline.observedDays == 1, "a second rung on one day created a second day")
        #expect(stored.baseline.days.first?.minutes == 120)
    }

    @Test("Non-ladder event names are ignored", arguments: [
        "budget", "lumo.unlock.ABC", "lumo.baseline", "lumo.baseline.", "lumo.baseline.7",
        "lumo.baseline.60.5", "lumo.baseline.sixty", "",
    ])
    func nonLadderEventsRecordNothing(name: String) throws {
        let rig = makeRig()
        let outcome = rig.reconciler.reconcile(by: .monitor, observing: name)

        // "lumo.baseline.7" is the interesting one: a well-formed name carrying a rung we never
        // registered. Accepting it would let any future event name silently become a measurement.
        #expect(outcome.recordedBaselineRung == nil)
        #expect(try rig.state.loadState().baseline.observedDays == 0)
    }

    @Test("A reconcile with no event at all records nothing")
    func absentEventRecordsNothing() throws {
        let rig = makeRig()
        let outcome = rig.reconciler.reconcile(by: .monitor)
        #expect(outcome.recordedBaselineRung == nil)
        #expect(try rig.state.loadState().baseline.observedDays == 0)
    }

    @Test("Three days of thresholds produce a usable baseline through the reconciler")
    func threeDaysThroughTheReconcilerPersonalises() throws {
        let rig = makeRig()
        for day in 0..<3 {
            rig.clock.set(to: Date.fixture.addingTimeInterval(TimeInterval(day) * 86_400))
            rig.reconciler.reconcile(
                by: .monitor,
                observing: BaselineCalibration.eventName(forRung: 60)
            )
        }

        let stored = try rig.state.loadState()
        #expect(stored.baseline.isReady)
        #expect(stored.baseline.inferredScrollMinutes() == 60)

        // And the whole point: that measurement reprices, above the punisher boundary.
        let baseline = try #require(
            stored.baseline.baseline(habitMinutesPerDay: 20, now: rig.clock.now))
        let repriced = Policy.default.repriced(for: baseline)
        #expect(Pricing.admissibleBand(for: baseline).contains(repriced.requiredRatio))
    }

    // MARK: - T-HARM-11…13: storage

    private func scratchDefaults(_ name: String) -> UserDefaults {
        let d = UserDefaults(suiteName: "lumo.tests.\(name)")!
        for key in StateKey.all { d.removeObject(forKey: key) }
        return d
    }

    @Test("Harm metrics round trip through the store")
    func harmRoundTrips() throws {
        let defaults = scratchDefaults("harm-roundtrip")
        let store = DefaultsStateStore(defaults: defaults)

        #expect(store.loadHarm() == .empty, "a first launch is not corruption")

        var metrics = HarmMetrics(windowStart: .fixture)
        metrics.sessionsStarted = 9
        metrics.sessionsCompleted = 3
        metrics.enjoymentSamples = [EnjoymentSample(at: .fixture, score: 2)]
        try store.saveHarm(metrics)

        #expect(store.loadHarm() == metrics)
    }

    @Test("A corrupt harm payload resets to empty instead of throwing")
    func corruptHarmResetsToEmpty() throws {
        let defaults = scratchDefaults("harm-corrupt")
        defaults.set(Data("{ not json".utf8), forKey: StateKey.harm)
        let diagnostics = RecordingDiagnostics()
        let store = DefaultsStateStore(defaults: defaults, diagnostics: diagnostics)

        // Deliberately the OPPOSITE of loadState, which must never fabricate. Instrumentation is
        // ours; the wallet is the user\'s. Losing a measurement is a nuisance, losing coins is a
        // betrayal — so only one of them is allowed to reset itself.
        #expect(store.loadHarm() == .empty)
        #expect(diagnostics.events.contains { $0.event == "harm.corrupt" })
    }

    @Test("Harm telemetry stays out of the blob the monitor decodes")
    func harmIsNotInTheHotBlob() throws {
        var state = SharedState.initial
        state.baseline.record(highestRung: 60, on: .fixture)
        let json = try #require(String(data: try JSONEncoder().encode(state), encoding: .utf8))

        // The monitor extension decodes this on every callback under a 6 MB ceiling, and has no
        // business reading self-reported enjoyment. Keeping it in a separate key is what makes that
        // structural rather than a matter of nobody having added it yet.
        #expect(!json.contains("enjoyment"))
        #expect(!json.contains("sessionsStarted"))
        #expect(StateKey.all.contains(StateKey.harm), "harm would survive teardown")
    }

    // MARK: - T-POLICY-01…06: personalisation reaches the price

    @Test("Personalising is refused until calibration is ready")
    func personalisationWaitsForCalibration() {
        var calibration = BaselineCalibration.empty
        calibration.record(highestRung: 60, on: .fixture)

        let outcome = PolicyPersonalizer.evaluate(
            calibration: calibration, current: .default, habitMinutesPerDay: 20, now: .fixture)

        #expect(outcome == .stillCalibrating(daysRemaining: 2))
    }

    @Test("No fired rung means no personalisation, not a fabricated baseline")
    func noSignalKeepsDefaults() {
        var calibration = BaselineCalibration.empty
        for day in 0..<3 {
            calibration.record(
                highestRung: nil, on: Date.fixture.addingTimeInterval(TimeInterval(day) * 86_400))
        }

        let outcome = PolicyPersonalizer.evaluate(
            calibration: calibration, current: .default, habitMinutesPerDay: 20, now: .fixture)

        #expect(outcome == .noSignal)
    }

    @Test("No completed habit sessions means no personalisation")
    func zeroHabitMinutesKeepsDefaults() {
        var calibration = BaselineCalibration.empty
        for day in 0..<3 {
            calibration.record(
                highestRung: 60, on: Date.fixture.addingTimeInterval(TimeInterval(day) * 86_400))
        }

        // A zero habit side would make the ratio zero and every unlock free — the exact punisher
        // boundary the whole pricing model exists to stay above.
        let outcome = PolicyPersonalizer.evaluate(
            calibration: calibration, current: .default, habitMinutesPerDay: 0, now: .fixture)

        #expect(outcome == .noSignal)
    }

    @Test("A measured baseline reprices, and stays inside the admissible band")
    func measurementReprices() throws {
        var calibration = BaselineCalibration.empty
        for day in 0..<3 {
            calibration.record(
                highestRung: 120, on: Date.fixture.addingTimeInterval(TimeInterval(day) * 86_400))
        }

        let outcome = PolicyPersonalizer.evaluate(
            calibration: calibration, current: .default, habitMinutesPerDay: 15, now: .fixture)

        guard case let .repriced(policy) = outcome else {
            Issue.record("expected a reprice, got \(outcome)")
            return
        }
        #expect(Pricing.admissibleBand(for: policy.baseline).contains(policy.requiredRatio))
        #expect(policy.baseline.source == .thresholdLadder)
    }

    @Test("Re-running against the same measurement does not rewrite the policy")
    func repricingIsStable() throws {
        var calibration = BaselineCalibration.empty
        for day in 0..<3 {
            calibration.record(
                highestRung: 60, on: Date.fixture.addingTimeInterval(TimeInterval(day) * 86_400))
        }

        let first = PolicyPersonalizer.evaluate(
            calibration: calibration, current: .default, habitMinutesPerDay: 20, now: .fixture)
        guard case let .repriced(policy) = first else {
            Issue.record("expected a reprice, got \(first)")
            return
        }

        // This runs on every foreground. Baseline.observedAt moves each time, so a naive equality
        // check would report a change forever and rewrite the policy on every launch — which would
        // also churn the fingerprint the shield extensions validate against.
        let second = PolicyPersonalizer.evaluate(
            calibration: calibration,
            current: policy,
            habitMinutesPerDay: 20,
            now: Date.fixture.addingTimeInterval(9_999)
        )
        #expect(second == .unchanged)
    }

    @Test("Habit minutes are averaged over days, not over sessions")
    func habitMinutesAveragePerDay() {
        // One 40-minute session in a week is ~5.7 min/day, not 40. Dividing by sessions would
        // inflate the habit side of the ratio, which makes unlocks cheaper — the punisher
        // direction, and invisible unless it is asserted.
        let perDay = PolicyPersonalizer.habitMinutesPerDay(
            completedSessionMinutes: [40], overDays: 7)
        #expect(abs(perDay - 40.0 / 7.0) < 0.001)

        #expect(PolicyPersonalizer.habitMinutesPerDay(completedSessionMinutes: [], overDays: 7) == 0)
        #expect(PolicyPersonalizer.habitMinutesPerDay(
            completedSessionMinutes: [10], overDays: 0) == 0)
    }

    @Test("All processes read one policy, and a corrupt one falls back to a usable price")
    func policyRoundTripsAndFallsBack() throws {
        let defaults = scratchDefaults("policy")
        let diagnostics = RecordingDiagnostics()
        let store = DefaultsStateStore(defaults: defaults, diagnostics: diagnostics)

        #expect(store.loadPolicy() == .default)

        var policy = Policy.default
        policy.tierMinutes = [20, 45]
        try store.savePolicy(policy)
        #expect(store.loadPolicy().tierMinutes == [20, 45])

        defaults.set(Data("{ not json".utf8), forKey: StateKey.policy)
        // A shield with no price on it is a dead end the user cannot act on, so this defaults
        // rather than failing — unlike the wallet, which must never be fabricated.
        #expect(store.loadPolicy() == .default)
        #expect(diagnostics.events.contains { $0.event == "policy.corrupt" })
    }
}
