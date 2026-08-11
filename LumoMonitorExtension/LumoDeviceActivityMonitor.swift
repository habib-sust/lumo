import DeviceActivity
import LumoCore
import LumoShieldKit
import os

/// The DeviceActivityMonitor extension entry point.
///
/// **This file must stay trivial.** It runs against a 6 MB high-watermark, and Jetsam kills
/// the process instantly past it — at which point the shield never re-applies, silently,
/// with no crash log a user would ever report. So every override is a one-line handoff into
/// LumoCore, where the logic is testable on macOS. A source file here longer than ~120
/// lines is a review flag.
///
/// **Callbacks are triggers, never data.** Nothing below branches on *which* activity or
/// event arrived; each one just asks the reconciler to recompute from persisted state plus
/// the current time. That is what makes spurious `intervalDidEnd`, phantom thresholds and
/// duplicate deliveries harmless by construction — and all three are documented to happen.
///
/// Note this class is `nonisolated` by necessity, not style: the target sets
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` because `DeviceActivityMonitor`'s overrides
/// are non-isolated, and a MainActor-isolated subclass will not compile under Swift 6.
///
/// This target must never link UIKit. It does not import it — but a transitive link through
/// LumoShieldKit is easy to reintroduce and impossible to see from here, so
/// `assert-link-graph.sh` checks the built binary rather than the source.
final class LumoDeviceActivityMonitor: DeviceActivityMonitor {

    private static let log = Logger(subsystem: "com.habib.Lumo.monitor", category: "monitor")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        reconcile(.intervalDidStart)
    }

    /// The primary expiry path: the wall clock ran out, so re-shield.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        reconcile(.intervalDidEnd)
    }

    /// Advisory only. The usage threshold is NOT trusted on its own — it is reported still
    /// firing at +0 seconds on iOS 26.5.2 even with `includesPastActivity: false`. The
    /// reconciler applies a sanity floor before honouring it, so a phantom fire costs a log
    /// line rather than the user's coins.
    ///
    /// The event name is forwarded — the single exception to "callbacks are triggers, never data",
    /// because the baseline ladder encodes its measurement in the name and has nowhere else to put
    /// it. The reconciler is the only reader; see `ShieldReconciler.recordBaseline`.
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        reconcile(.eventDidReachThreshold, observing: event.rawValue)
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        reconcile(.intervalWillStartWarning)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        reconcile(.intervalWillEndWarning)
    }

    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        reconcile(.eventWillReachThresholdWarning)
    }

    // MARK: - The single handoff

    private enum Trigger: String {
        case intervalDidStart, intervalDidEnd, eventDidReachThreshold
        case intervalWillStartWarning, intervalWillEndWarning, eventWillReachThresholdWarning
    }

    private func reconcile(_ trigger: Trigger, observing eventName: String? = nil) {
        // Synchronous, with no Task and no await: this extension can be suspended or killed at
        // any moment, so the work has to complete inline or not at all.
        //
        // Note the trigger is logged but never acted on. Every callback means the same thing —
        // "recompute from persisted state" — which is what makes phantom thresholds, spurious
        // intervalDidEnd and duplicate deliveries harmless. `eventName` is the lone exception and
        // reaches exactly one reader, the baseline ladder.
        let outcome = LumoStack.reconcileNow(.monitor, observing: eventName)
        Self.log.info(
            "trigger=\(trigger.rawValue, privacy: .public) shielded=\(outcome?.shielded.count ?? -1) expired=\(outcome?.expiredWindows ?? -1) rung=\(outcome?.recordedBaselineRung ?? -1)"
        )
    }
}
