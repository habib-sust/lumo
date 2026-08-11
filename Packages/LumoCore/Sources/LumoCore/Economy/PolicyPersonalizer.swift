import Foundation

/// Turns a finished calibration into a repriced policy.
///
/// Exists as its own type because "should we reprice, and to what" is the decision the entire
/// baseline ladder was built to inform, and burying it in a view would make it untestable on macOS —
/// which is where the pricing maths has to be provable, since Family Controls will not run in the
/// Simulator at all.
public enum PolicyPersonalizer {

    public enum Outcome: Sendable, Equatable {
        /// Not enough observed days yet. `daysRemaining` is for honest UI, not a progress bar.
        case stillCalibrating(daysRemaining: Int)
        /// Calibration finished but produced no usable signal — nobody crossed the lowest rung, or
        /// there are no completed habit sessions to form the other half of the ratio.
        case noSignal
        /// Already priced against this measurement.
        case unchanged
        case repriced(Policy)
    }

    /// Decides whether to personalise.
    ///
    /// - Parameter habitMinutesPerDay: measured from real completed sessions, not estimated. Lumo
    ///   observes its own side of the ratio directly; only the scroll side has to be inferred.
    public static func evaluate(
        calibration: BaselineCalibration,
        current: Policy,
        habitMinutesPerDay: Double,
        now: Date
    ) -> Outcome {
        guard calibration.isReady else {
            return .stillCalibrating(daysRemaining: calibration.daysRemaining)
        }
        guard let measured = calibration.baseline(habitMinutesPerDay: habitMinutesPerDay, now: now)
        else {
            return .noSignal
        }

        let candidate = current.repriced(for: measured)
        // Compared on the fields that set the price, not on the whole value: `Baseline.observedAt`
        // moves every time this runs, so a plain `==` would report a change on every launch and
        // rewrite the policy forever.
        guard candidate.requiredRatio != current.requiredRatio
                || candidate.baseline.scrollMinutesPerDay != current.baseline.scrollMinutesPerDay
                || candidate.baseline.habitMinutesPerDay != current.baseline.habitMinutesPerDay
        else {
            return .unchanged
        }
        return .repriced(candidate)
    }

    /// Mean habit minutes per day over the observation window.
    ///
    /// Counts only **completed** sessions, and divides by elapsed days rather than by the number of
    /// sessions. Both matter: dividing by sessions would report a user who did one 40-minute session
    /// all week as averaging 40 minutes a day, and pricing off that inflates the habit side of the
    /// ratio, which makes unlocks *cheaper* — the punisher direction.
    public static func habitMinutesPerDay(
        completedSessionMinutes: [Double],
        overDays days: Int
    ) -> Double {
        guard days > 0, !completedSessionMinutes.isEmpty else { return 0 }
        return completedSessionMinutes.reduce(0, +) / Double(days)
    }
}
