#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

/// `CrossProcessLocking` via `flock` on a file.
///
/// `flock` rather than an actor, because an actor cannot span processes and `await`ing one
/// would break the synchronous guarantee `reconcile()` depends on. It also has the property
/// that matters most here: **the kernel releases the lock when the holder dies**, including a
/// Jetsam kill. So a monitor extension killed at its 6 MB ceiling cannot deadlock the app.
///
/// Portable POSIX, so it lives in LumoCore and the two-process behaviour is testable on macOS
/// rather than device-only.
public struct FileLock: CrossProcessLocking {

    let url: URL
    let attempts: Int
    let retryInterval: TimeInterval
    let diagnostics: any Diagnosing

    /// - Parameters:
    ///   - attempts: how many non-blocking tries before giving up.
    ///   - retryInterval: pause between tries. Defaults give up after ~50 ms total.
    public init(
        url: URL,
        attempts: Int = 10,
        retryInterval: TimeInterval = 0.005,
        diagnostics: any Diagnosing = NullDiagnostics()
    ) {
        self.url = url
        self.attempts = max(1, attempts)
        self.retryInterval = max(0, retryInterval)
        self.diagnostics = diagnostics
    }

    /// Runs `body` under an exclusive lock, or returns `nil` if the lock could not be taken.
    ///
    /// Deliberately **never blocks indefinitely**. The shield-config extension calls into this
    /// on a latency-sensitive render path: if it stalls, the system substitutes Apple's generic
    /// grey shield, silently replacing Lumo's only conversion surface with an anonymous wall.
    /// Giving up and rendering from last-known state is strictly better than being slow.
    public func withLock<T>(_ body: () throws -> T) rethrows -> T? {
        guard let handle = open() else {
            diagnostics.record("lock.openFailed", detail: url.lastPathComponent)
            return nil
        }
        defer { Darwin.close(handle) }

        guard acquire(handle) else {
            diagnostics.record("lock.contended", detail: url.lastPathComponent)
            return nil
        }
        // LOCK_UN before the fd closes. Closing would release it anyway, but being explicit
        // keeps the pairing visible.
        defer { flock(handle, LOCK_UN) }

        return try body()
    }

    /// Opens (creating if needed) the lock file. `nil` on failure.
    private func open() -> Int32? {
        // O_CREAT so first run works without a setup step. 0o644 because only this app's own
        // processes need it, and the App Group container is already sandboxed.
        let fd = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return Darwin.open(path, O_RDWR | O_CREAT, 0o644)
        }
        return fd < 0 ? nil : fd
    }

    private func acquire(_ handle: Int32) -> Bool {
        for attempt in 0..<attempts {
            if flock(handle, LOCK_EX | LOCK_NB) == 0 { return true }
            // EWOULDBLOCK means someone else holds it — worth retrying. Anything else is a
            // real error and retrying will not help.
            if errno != EWOULDBLOCK { return false }
            if attempt < attempts - 1, retryInterval > 0 {
                usleep(UInt32(retryInterval * 1_000_000))
            }
        }
        return false
    }
}

/// A lock that is never contended. For single-process contexts and tests.
public struct NoOpLock: CrossProcessLocking {
    public init() {}
    public func withLock<T>(_ body: () throws -> T) rethrows -> T? { try body() }
}
