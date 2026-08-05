import Foundation
import LumoCore

/// A clock the tests can move by hand.
///
/// This is the workhorse fake for the whole suite: expiry, weekly grants, streak
/// pauses and the 3-day baseline calibration are all "advance the clock, reconcile,
/// assert" tests. Without it they would be real-time tests.
///
/// `@unchecked Sendable` with an `NSLock` rather than `Mutex` so the package floor can
/// stay at macOS 14 — the locking is trivial and entirely contained here.
final class MutableNow: NowProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date

    init(_ start: Date) {
        _now = start
    }

    var now: Date {
        lock.withLock { _now }
    }

    /// Moves the clock forward. Negative values are allowed on purpose — a user can set
    /// their device clock backwards, and the reconciler has to survive it.
    func advance(by interval: TimeInterval) {
        lock.withLock { _now += interval }
    }

    func set(to date: Date) {
        lock.withLock { _now = date }
    }
}

// MARK: - Shared fixtures

extension Date {
    /// A fixed, readable reference instant: 2026-01-05 09:00:00 UTC, a Monday.
    ///
    /// Monday matters — the weekly coin grant is issued at local Monday midnight, so
    /// grant tests need a known weekday to reason about.
    static let fixture = Date(timeIntervalSince1970: 1_767_603_600)
}
