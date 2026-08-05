import Foundation

/// Supplies the current instant.
///
/// Every expiry, grant, streak and pricing decision in Lumo is a function of `now`, so
/// `now` is injected rather than read from the environment. That is what makes the
/// reconciler testable: a window that expires "in 15 minutes" is otherwise a 15-minute
/// test.
///
/// Deliberately synchronous. `ShieldReconciler` must not `await` — an async gap in the
/// foreground path lets the user background the app mid-reconcile and leaves shields
/// half-applied — so nothing it depends on may be async either.
public protocol NowProviding: Sendable {
    var now: Date { get }
}

/// Production implementation: the system clock.
///
/// Note the clock is user-settable, which is why wall-clock expiry is a *cap* rather
/// than the only defence. See `ShieldReconciler` for the layered design.
public struct SystemNow: NowProviding {
    public init() {}
    public var now: Date { Date() }
}

/// A clock frozen at a fixed instant. Use in tests when time must not move.
public struct FixedNow: NowProviding {
    public let now: Date

    public init(_ now: Date) {
        self.now = now
    }
}
