import Foundation

/// A habit the user defined.
///
/// The user authors these — name, target, and whether it earns at all. Autonomy support is one of
/// the few genuine mitigations for the overjustification effect, and unlike badges or points it is
/// the one thing no game layer can supply: the research found no gamification element affected
/// perceived decision freedom.
public struct HabitSpec: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    /// The standard. Awards are contingent on meeting it, not on showing up.
    public var targetMinutes: Int

    /// When false, this habit earns nothing — the explicit "for its own sake" list.
    ///
    /// Load-bearing rather than a nicety: undermining requires pre-existing intrinsic motivation
    /// to destroy, so anything the user already loves must be kept out of the economy. Attaching
    /// coins to something they do for pleasure is how the mechanic does harm.
    public var isMonetised: Bool

    public init(id: UUID = UUID(), name: String, targetMinutes: Int, isMonetised: Bool = true) {
        self.id = id
        self.name = name
        self.targetMinutes = max(1, targetMinutes)
        self.isMonetised = isMonetised
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        targetMinutes = max(1, try c.decodeIfPresent(Int.self, forKey: .targetMinutes) ?? 10)
        isMonetised = try c.decodeIfPresent(Bool.self, forKey: .isMonetised) ?? true
    }
}

/// One completed attempt.
public struct HabitSession: Codable, Sendable, Equatable {
    public var habitID: UUID
    public var startedAt: Date
    public var endedAt: Date
    /// Time actually spent, excluding pauses.
    public var activeSeconds: TimeInterval
    public var pausedSeconds: TimeInterval
    /// Logged after the fact rather than timed live.
    ///
    /// Supported because its absence drives churn — "if you forget to start a task you can't mark
    /// it later" is a recurring competitor complaint. Recorded rather than hidden so it can be
    /// weighted differently if it is ever abused.
    public var wasRetroactive: Bool

    public init(
        habitID: UUID,
        startedAt: Date,
        endedAt: Date,
        activeSeconds: TimeInterval,
        pausedSeconds: TimeInterval = 0,
        wasRetroactive: Bool = false
    ) {
        self.habitID = habitID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activeSeconds = max(0, activeSeconds)
        self.pausedSeconds = max(0, pausedSeconds)
        self.wasRetroactive = wasRetroactive
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        habitID = try c.decodeIfPresent(UUID.self, forKey: .habitID) ?? UUID()
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date(timeIntervalSince1970: 0)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt) ?? Date(timeIntervalSince1970: 0)
        activeSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .activeSeconds) ?? 0
        pausedSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .pausedSeconds) ?? 0
        wasRetroactive = try c.decodeIfPresent(Bool.self, forKey: .wasRetroactive) ?? false
    }

    public var activeMinutes: Int { Int(activeSeconds / 60) }
}

/// What the user is told alongside the number.
///
/// Every award carries this. A bare counter going up is the engagement-contingent shape the reward
/// literature identifies as most corrosive; pairing it with **informational competence feedback**
/// is one of the mitigations with a real effect size behind it (positive feedback improves
/// free-choice behaviour and interest, where a bare reward does not).
public struct CompetenceFeedback: Sendable, Equatable {
    /// What they did, in their own terms.
    public var headline: String
    /// Something true and specific about the doing of it — not praise.
    public var detail: String

    public init(headline: String, detail: String) {
        self.headline = headline
        self.detail = detail
    }
}

public struct AwardOutcome: Sendable, Equatable {
    public var coins: Int
    /// Extra coins for returning after a lapse.
    public var comebackBonus: Int
    /// An occasional unexpected top-up.
    ///
    /// Unexpected rewards showed **no undermining effect at all** (d ≈ 0.01), unlike the expected
    /// contingent kind. So a small unpredictable component is close to free upside.
    public var surpriseBonus: Int
    public var feedback: CompetenceFeedback
    /// False when the session did not meet the habit's standard.
    public var metStandard: Bool

    public var total: Int { coins + comebackBonus + surpriseBonus }
}

public enum CoinAward {

    /// Awards are **performance-contingent**, never engagement-contingent.
    ///
    /// Paying someone merely for showing up is the most harmful cell in the reward literature
    /// (d ≈ −0.40 versus −0.28 for meeting a standard), so a session that falls short of the
    /// habit's own target earns nothing — while still counting for the streak, and still getting
    /// honest feedback. The user sets the target themselves, which is what keeps that fair.
    public static func award(
        session: HabitSession,
        habit: HabitSpec,
        policy: Policy,
        streak: Streak,
        surpriseRoll: Int = 0
    ) -> AwardOutcome {
        let requiredSeconds = TimeInterval(habit.targetMinutes * 60)
        let metStandard = session.activeSeconds >= requiredSeconds

        guard metStandard else {
            return AwardOutcome(
                coins: 0,
                comebackBonus: 0,
                surpriseBonus: 0,
                feedback: CompetenceFeedback(
                    headline: "\(session.activeMinutes) min of \(habit.name)",
                    // Informational, not disappointed. Naming the gap is useful; implying failure
                    // is not.
                    detail: "Your target is \(habit.targetMinutes) min. This still counts toward today."
                ),
                metStandard: false
            )
        }

        // Un-monetised habits earn nothing by design, and say so plainly rather than looking broken.
        guard habit.isMonetised else {
            return AwardOutcome(
                coins: 0,
                comebackBonus: 0,
                surpriseBonus: 0,
                feedback: CompetenceFeedback(
                    headline: "\(session.activeMinutes) min of \(habit.name)",
                    detail: "You kept this one off the coin list. It's yours."
                ),
                metStandard: true
            )
        }

        // Deliberately small. In a 61,293-person megastudy $0.09 beat $1.75; reward magnitude
        // saturates almost immediately, and a large reward buys undermining rather than behaviour.
        let coins = session.activeMinutes * policy.coinsPerHabitMinute

        let comeback = streak.comebackArmed ? comebackBonusCoins(policy: policy) : 0
        // Roughly 1 in 8, driven by a caller-supplied roll so the award stays a pure function and
        // the tests stay deterministic.
        let surprise = (surpriseRoll % 8 == 0) ? max(1, policy.coinsPerHabitMinute) : 0

        return AwardOutcome(
            coins: coins,
            comebackBonus: comeback,
            surpriseBonus: surprise,
            feedback: feedback(for: session, habit: habit, streak: streak, comeback: comeback > 0),
            metStandard: true
        )
    }

    /// Small on purpose. The megastudy's cheapest comeback bonus outperformed the most expensive
    /// one, so this is about acknowledgement rather than compensation.
    public static func comebackBonusCoins(policy: Policy) -> Int {
        max(1, policy.coinsPerHabitMinute * 2)
    }

    private static func feedback(
        for session: HabitSession,
        habit: HabitSpec,
        streak: Streak,
        comeback: Bool
    ) -> CompetenceFeedback {
        let headline = "\(session.activeMinutes) min of \(habit.name)"

        if comeback {
            // The return itself is the thing worth naming, and pointedly not the gap that preceded
            // it. "You broke your streak" is the framing that produces a binge.
            return CompetenceFeedback(
                headline: headline,
                detail: "Back at it. That's the hard part done."
            )
        }
        if session.activeSeconds > TimeInterval(habit.targetMinutes * 60) * 1.5 {
            return CompetenceFeedback(
                headline: headline,
                detail: "Well past your target of \(habit.targetMinutes) min."
            )
        }
        if streak.current >= 2 {
            return CompetenceFeedback(
                headline: headline,
                detail: "\(streak.current) days running."
            )
        }
        return CompetenceFeedback(
            headline: headline,
            detail: "Target met."
        )
    }
}
