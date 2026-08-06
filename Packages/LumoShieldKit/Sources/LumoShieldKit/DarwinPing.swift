#if os(iOS)

import Foundation
import LumoCore

/// Cross-process "go and look" signals.
///
/// `CFNotificationCenterGetDarwinNotifyCenter` is public, documented API and the standard way
/// to poke another process on iOS, so it raises no Guideline 2.5.1 concern.
///
/// **Nothing may depend on delivery.** Two reasons, and both bite:
///   * There is no payload — only a name. So data always travels through the App Group; this
///     is purely a nudge to re-read it.
///   * It is not durable. If the observing process is not running, the signal is simply lost.
///
/// So this exists to make the app's UI refresh *promptly* when it happens to be alive. Every
/// correctness guarantee comes from `reconcile()` on activation instead. Deleting this file
/// should break no test — and that is asserted.
public enum DarwinPing: String, Sendable, CaseIterable {

    /// The shield-action extension settled a spend; the app should refresh if it is running.
    case spendSettled = "com.habib.Lumo.spendSettled"
    /// A window opened or closed.
    case windowsChanged = "com.habib.Lumo.windowsChanged"
    /// The user asked to unlock everything; other processes should stop fighting it.
    case teardownRequested = "com.habib.Lumo.teardownRequested"

    public func post() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue as CFString),
            nil,
            nil,
            true
        )
    }

    /// Observes until the returned token is released.
    @discardableResult
    public func observe(_ handler: @escaping @Sendable () -> Void) -> any AnyObject {
        DarwinObserver(name: rawValue, handler: handler)
    }
}

/// Holds one Darwin observer registration for its lifetime.
private final class DarwinObserver: NSObject, @unchecked Sendable {
    private let handler: @Sendable () -> Void

    init(name: String, handler: @escaping @Sendable () -> Void) {
        self.handler = handler
        super.init()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                Unmanaged<DarwinObserver>.fromOpaque(observer)
                    .takeUnretainedValue()
                    .handler()
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}

#endif
