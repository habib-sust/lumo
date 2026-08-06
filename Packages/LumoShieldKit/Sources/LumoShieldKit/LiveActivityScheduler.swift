#if os(iOS)

import DeviceActivity
import Foundation
import LumoCore
import ManagedSettings

/// `ActivityScheduling` over `DeviceActivityCenter`.
///
/// Arms the OS-side timers that guarantee a paid window re-locks. The wall clock is the primary
/// mechanism; the usage threshold is registered too but treated as advisory, because
/// `eventDidReachThreshold` is reported firing at +0 seconds on current iOS even with
/// `includesPastActivity: false`.
public struct LiveActivityScheduler: ActivityScheduling {

    /// All Lumo activity names start with this, so garbage collection can never stop another
    /// app's monitoring.
    public static let namePrefix = "lumo.unlock."

    /// iOS floors a `DeviceActivitySchedule` interval at 15 minutes and throws
    /// `intervalTooShort` below it. A window shorter than that is expressed as a 15-minute
    /// schedule plus a `warningTime` lead, so `intervalWillEndWarning` lands at the real expiry.
    public static let minimumScheduleSeconds: TimeInterval = 15 * 60

    private let diagnostics: any Diagnosing

    public init(diagnostics: any Diagnosing = NullDiagnostics()) {
        self.diagnostics = diagnostics
    }

    public enum SchedulerError: Error, Equatable {
        case tokenUnreadable(BucketID)
        /// Past the 20-activity cap. Surfaced rather than swallowed so the spend can be refused
        /// and refunded instead of granting access with no timer.
        case tooManyActivities
        case intervalRejected(String)
        case unauthorized
        case unknown(String)
    }

    public func arm(
        activityName: String,
        bucket: BucketID,
        token: TokenBlob,
        kind: BucketKind,
        wallClockSeconds: TimeInterval,
        usageBudgetSeconds: TimeInterval?
    ) throws {
        let center = DeviceActivityCenter()
        let calendar = Calendar.current
        let components: Set<Calendar.Component> = [.hour, .minute, .second]

        // Start a couple of seconds out. Apple documents that if `now` already falls inside the
        // interval, `intervalDidStart` fires immediately — which we do not want to race.
        let start = Date().addingTimeInterval(2)
        let scheduleLength = max(Self.minimumScheduleSeconds, wallClockSeconds)
        let end = start.addingTimeInterval(scheduleLength)

        // For a sub-15-minute window, lead the warning by the difference so the callback lands
        // at the real expiry. Apple documents no minimum for warningTime — the widely repeated
        // 15-minute figure is community lore — so SPIKE-2a has to measure whether short leads
        // fire dependably before we sell a tier that depends on this.
        var warning: DateComponents?
        if wallClockSeconds < Self.minimumScheduleSeconds {
            let leadMinutes = Int((scheduleLength - wallClockSeconds) / 60)
            warning = DateComponents(minute: max(1, leadMinutes))
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: start),
            intervalEnd: calendar.dateComponents(components, from: end),
            // One-shot. A repeating schedule would re-open the window next day for free.
            repeats: false,
            warningTime: warning
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        if let usageBudgetSeconds {
            let applications: Set<ApplicationToken>
            let categories: Set<ActivityCategoryToken>
            switch kind {
            case .application:
                guard let resolved = try? TokenCodec.applicationToken(from: token) else {
                    throw SchedulerError.tokenUnreadable(bucket)
                }
                applications = [resolved]
                categories = []
            case .category:
                guard let resolved = try? TokenCodec.categoryToken(from: token) else {
                    throw SchedulerError.tokenUnreadable(bucket)
                }
                applications = []
                categories = [resolved]
            }

            // Multiple events inside ONE activity cost nothing extra against the 20-activity
            // cap, which is why this is an events dictionary rather than chained schedules.
            events[.init("budget")] = DeviceActivityEvent(
                applications: applications,
                categories: categories,
                webDomains: [],
                threshold: DateComponents(minute: max(1, Int(usageBudgetSeconds / 60))),
                // Always false, never the legacy initialiser: the default is undocumented, and
                // past activity leaking in is one suspected cause of the +0s threshold reports.
                includesPastActivity: false
            )
        }

        do {
            try center.startMonitoring(.init(activityName), during: schedule, events: events)
        } catch let error as DeviceActivityCenter.MonitoringError {
            diagnostics.record("arm.failed", detail: "\(error)")
            throw Self.map(error)
        } catch {
            diagnostics.record("arm.failed", detail: error.localizedDescription)
            throw SchedulerError.unknown(error.localizedDescription)
        }
    }

    public func disarm(activityName: String) {
        // Never pass an empty array: `stopMonitoring([])` stops EVERYTHING this app monitors,
        // which would silently disarm every live window.
        guard !activityName.isEmpty else { return }
        DeviceActivityCenter().stopMonitoring([.init(activityName)])
    }

    /// Prefix-filtered so we only ever see and stop our own activities.
    public func activeActivityNames() -> Set<String> {
        Set(
            DeviceActivityCenter().activities
                .map(\.rawValue)
                .filter { $0.hasPrefix(Self.namePrefix) }
        )
    }

    /// Every case handled explicitly, with `@unknown default`: `MonitoringError` is a
    /// library-evolution enum and notably has NO token-count case, which is why the 50-token
    /// cliff has to be prevented in the picker rather than caught here.
    private static func map(_ error: DeviceActivityCenter.MonitoringError) -> SchedulerError {
        switch error {
        case .excessiveActivities: .tooManyActivities
        case .intervalTooShort: .intervalRejected("intervalTooShort")
        case .intervalTooLong: .intervalRejected("intervalTooLong")
        case .invalidDateComponents: .intervalRejected("invalidDateComponents")
        case .unauthorized: .unauthorized
        @unknown default: .unknown("\(error)")
        }
    }
}

#endif
