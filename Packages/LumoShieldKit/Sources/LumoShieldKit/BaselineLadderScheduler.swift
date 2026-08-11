#if os(iOS)

import DeviceActivity
import Foundation
import LumoCore
import ManagedSettings

/// Registers the usage thresholds whose firing pattern is Lumo's only view of how much the user
/// actually scrolls.
///
/// The direct route is closed. `DeviceActivityReport` renders inside a sandbox that blocks network
/// access *and* prevents data leaving the extension, so the host app can never read per-app minutes,
/// and `ApplicationToken`s are opaque. What remains is registering thresholds and observing which
/// ones fire — coarse, but a measurement rather than a guess, and the guess is what makes
/// response-deprivation pricing worthless.
///
/// **App-only, and deliberately not on the `ActivityScheduling` seam.** That protocol exists for the
/// spend path, which runs in three processes under a lock; this runs once when the blocklist
/// changes. Putting it there would have forced two dead methods onto every extension's seam and
/// every test fake.
///
/// All four rungs live inside ONE activity, so the whole ladder costs one slot against the
/// 20-activity cap.
public struct BaselineLadderScheduler {

    /// Deliberately NOT prefixed `lumo.unlock.` — `LiveActivityScheduler.activeActivityNames()`
    /// filters on that prefix for garbage collection, so the ladder is invisible to the collector
    /// and survives. A rename into that namespace would have the collector silently stop it.
    public static let activityName = "lumo.baseline"

    private let diagnostics: any Diagnosing

    public init(diagnostics: any Diagnosing = NullDiagnostics()) {
        self.diagnostics = diagnostics
    }

    /// Arms, or re-arms, the ladder over the given tokens.
    ///
    /// Safe to call repeatedly. `startMonitoring` on an existing name replaces the registration, and
    /// unlike the spend path a spurious `intervalDidEnd` here is harmless — the ladder owns no
    /// shield state, so the worst case is one extra no-op reconcile.
    ///
    /// Silently does nothing when there is nothing to observe. Registering an event with no
    /// applications and no categories would monitor *everything*, which is both wrong and a
    /// privacy overreach.
    public func arm(applications: Set<TokenBlob>, categories: Set<TokenBlob>) throws {
        let apps = Set(applications.compactMap { try? TokenCodec.applicationToken(from: $0) })
        let cats = Set(categories.compactMap { try? TokenCodec.categoryToken(from: $0) })

        guard !apps.isEmpty || !cats.isEmpty else {
            diagnostics.record("baseline.armSkipped", detail: "no readable tokens")
            disarm()
            return
        }

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for rung in BaselineCalibration.ladderMinutes {
            events[.init(BaselineCalibration.eventName(forRung: rung))] = DeviceActivityEvent(
                applications: apps,
                categories: cats,
                webDomains: [],
                threshold: DateComponents(minute: rung),
                // Always false, never the legacy initialiser: the default is undocumented, and past
                // activity leaking in would make every rung fire on the first day and report a
                // baseline of 120 minutes for everyone.
                includesPastActivity: false
            )
        }

        do {
            try DeviceActivityCenter().startMonitoring(
                .init(Self.activityName),
                during: Self.dailySchedule(),
                events: events
            )
            diagnostics.record(
                "baseline.armed",
                detail: "apps=\(apps.count) cats=\(cats.count) rungs=\(events.count)"
            )
        } catch {
            // Never fatal to the caller's flow. Losing the ladder costs personalised pricing, which
            // falls back to defaults; failing the blocklist commit over it would cost the user their
            // shields, which is the thing they actually asked for.
            diagnostics.record("baseline.armFailed", detail: "\(error)")
            throw error
        }
    }

    public func disarm() {
        // Never pass an empty array: `stopMonitoring([])` stops EVERYTHING this app monitors, which
        // here would silently disarm every live paid window as well.
        DeviceActivityCenter().stopMonitoring([.init(Self.activityName)])
    }

    public func isArmed() -> Bool {
        DeviceActivityCenter().activities.contains { $0.rawValue == Self.activityName }
    }

    /// A full local day, repeating.
    ///
    /// Repeating is what makes this a per-day measurement: thresholds reset with each interval, so
    /// the rungs that fire on Tuesday are Tuesday's usage rather than a running total. The end is
    /// 23:59 rather than midnight because an interval whose end equals the next interval's start is
    /// ambiguous and `invalidDateComponents` is a documented rejection.
    private static func dailySchedule() -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
    }
}

#endif
