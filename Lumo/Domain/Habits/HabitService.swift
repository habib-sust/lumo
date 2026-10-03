import Foundation
import LumoCore
import LumoShieldKit
import Observation
import SwiftData

/// Habits, the running timer, and the transaction that turns a finished session into coins.
@MainActor
@Observable
final class HabitService {

    private(set) var habits: [HabitSpec] = []
    private(set) var timer: HabitTimer?
    /// The habit the running timer belongs to, resolved for display.
    var runningHabit: HabitSpec? {
        guard let timer else { return nil }
        return habits.first { $0.id == timer.habitID }
    }

    /// The last award, held so the UI can show competence feedback once and then drop it.
    private(set) var lastAward: AwardOutcome?

    func load() {
        habits = Self.fetchHabits()
        timer = LumoStack.stateStore(for: .app)?.loadTimer()
    }

    // MARK: - Habit management

    /// The user authors their own habits, including the target.
    ///
    /// Autonomy support is one of the few overjustification mitigations with real evidence behind
    /// it, and it is also what makes performance-contingent rewards fair: the standard a session is
    /// judged against is the user's own, not one Lumo imposed.
    func create(name: String, targetMinutes: Int, isMonetised: Bool) {
        guard let container = LumoPersistence.container else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let spec = HabitSpec(
            name: trimmedName,
            targetMinutes: max(1, targetMinutes),
            isMonetised: isMonetised
        )
        let context = ModelContext(container)
        context.insert(HabitRecord(spec, createdAt: Date()))
        try? context.save()
        load()
    }

    func archive(_ habit: HabitSpec) {
        guard let container = LumoPersistence.container else { return }
        let context = ModelContext(container)
        let id = habit.id
        let descriptor = FetchDescriptor<HabitRecord>(predicate: #Predicate { $0.habitID == id })
        guard let record = try? context.fetch(descriptor).first else { return }
        // Archived, never deleted. Sessions reference the habit, and a deleted habit would orphan
        // the history the ledger and the baseline both read from.
        record.isArchived = true
        try? context.save()
        load()
    }

    // MARK: - Timer lifecycle

    func start(_ habit: HabitSpec) {
        guard timer == nil else { return }
        let startedTimer = HabitTimer(
            habitID: habit.id,
            targetMinutes: habit.targetMinutes,
            startedAt: Date()
        )
        persistTimer(startedTimer)
    }

    func pause() {
        guard var timer, timer.isRunning else { return }
        timer.pause(at: Date())
        persistTimer(timer)
    }

    func resume() {
        guard var timer, timer.isPaused else { return }
        timer.resume(at: Date())
        persistTimer(timer)
    }

    /// Abandons without awarding. Recorded, because abandonment rate is a harm signal.
    func abandon() {
        guard timer != nil else { return }
        var metrics = LumoStack.stateStore(for: .app)?.loadHarm() ?? .empty
        metrics.sessionsAbandoned += 1
        try? LumoStack.stateStore(for: .app)?.saveHarm(metrics)
        persistTimer(nil)
    }

    /// Finishes the session, awards coins, and writes the audit trail.
    ///
    /// The wallet update and the streak increment happen in ONE locked write, because a tear
    /// between them either pays for a day that did not count or counts a day that was not paid.
    @discardableResult
    func finish() -> AwardOutcome? {
        guard var running = timer, let habit = runningHabit else { return nil }
        let session = running.finish(at: Date())
        persistTimer(nil)
        return settle(session: session, habit: habit)
    }

    /// Logs a session the user did without the timer running.
    ///
    /// Supported deliberately: a timer that must be running to count punishes people for forgetting
    /// to open an app, which measures app-opening rather than the habit. Flagged in the record so it
    /// can be weighted differently if it is ever abused.
    @discardableResult
    func logRetroactive(_ habit: HabitSpec, minutes: Int) -> AwardOutcome? {
        let session = HabitTimer.retroactiveSession(
            habitID: habit.id,
            minutes: max(1, minutes),
            endedAt: Date()
        )
        return settle(session: session, habit: habit)
    }

    func clearLastAward() {
        lastAward = nil
    }

    // MARK: - Settlement

    private func settle(session: HabitSession, habit: HabitSpec) -> AwardOutcome? {
        guard let store = LumoStack.stateStore(for: .app) else { return nil }
        let policy = store.loadPolicy()
        let now = Date()

        var outcome: AwardOutcome?
        LumoStack.lock(for: .app).withLock {
            guard var state = try? store.loadState() else { return }

            // The grant boundary first: a session on the first day of a new week must be paid into
            // the new week's ledger, not the expired one.
            GrantCycle.issueIfNeeded(state: &state, policy: policy, now: now)

            // Keep the existing session-derived roll; hashValue is stable only within this process.
            let surpriseRoll = abs(Int(session.endedAt.timeIntervalSince1970) &+ session.habitID.hashValue)
            let award = CoinAward.award(
                session: session,
                habit: habit,
                policy: policy,
                streak: state.streak,
                surpriseRoll: surpriseRoll
            )
            let completion = state.streak.recordCompletion(on: now)

            if award.total > 0 {
                state.wallet.credit(earned: award.total)
            }
            state.week.comebackBonusArmed = false

            try? store.saveState(state)
            appendLedger(award: award, habit: habit, at: now)
            recordSessionMetrics(metStandard: award.metStandard, store: store, now: now)

            LumoStackDiagnostics.record(
                "habit.settled",
                detail: "\(session.activeMinutes)m \(habit.name) +\(award.total)c streak \(completion.newCurrent)"
            )
            outcome = award
        }

        saveSession(session, coinsAwarded: outcome?.total ?? 0)
        lastAward = outcome
        return outcome
    }

    /// Every coin movement gets a row, split by kind.
    ///
    /// Separate rows rather than one lump: the ledger is what rebuilds the wallet when both the live
    /// state and its backup fail to decode, and "23 coins from somewhere" is not an audit trail.
    private func appendLedger(award: AwardOutcome, habit: HabitSpec, at now: Date) {
        guard let ledger = LumoPersistence.ledgerStore() else { return }
        var rows: [LedgerEntry] = []
        if award.coins > 0 {
            rows.append(LedgerEntry(
                at: now,
                kind: .habitEarned,
                earnedDelta: award.coins,
                note: habit.name
            ))
        }
        if award.comebackBonus > 0 {
            rows.append(LedgerEntry(
                at: now,
                kind: .comebackBonus,
                earnedDelta: award.comebackBonus,
                note: "back after a lapse"
            ))
        }
        if award.surpriseBonus > 0 {
            rows.append(LedgerEntry(
                at: now,
                kind: .surpriseBonus,
                earnedDelta: award.surpriseBonus,
                note: "unexpected"
            ))
        }
        guard !rows.isEmpty else { return }
        try? ledger.append(rows)
    }

    private func recordSessionMetrics(
        metStandard: Bool,
        store: DefaultsStateStore,
        now: Date
    ) {
        var metrics = store.loadHarm()
        if metrics.windowStart == Date(timeIntervalSince1970: 0) {
            metrics.windowStart = now
        }
        metrics.sessionsStarted += 1
        if metStandard {
            metrics.sessionsCompleted += 1
        }
        try? store.saveHarm(metrics)
    }

    private func saveSession(_ session: HabitSession, coinsAwarded: Int) {
        guard let container = LumoPersistence.container else { return }
        let context = ModelContext(container)
        context.insert(SessionRecord(session, coinsAwarded: coinsAwarded))
        try? context.save()
    }

    // MARK: - Persistence

    private func persistTimer(_ value: HabitTimer?) {
        try? LumoStack.stateStore(for: .app)?.saveTimer(value)
        timer = value
    }

    private static func fetchHabits() -> [HabitSpec] {
        guard let container = LumoPersistence.container else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<HabitRecord>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor))?.map(\.value) ?? []
    }
}
