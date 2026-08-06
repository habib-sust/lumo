#if os(iOS)

import Foundation
import LumoCore

/// The composition root. Builds a reconciler or spend coordinator wired to real iOS services.
///
/// Every process constructs its own — the app, the monitor extension, and the shield-action
/// extension — and they coordinate purely through the App Group container plus the file lock.
/// There is no shared object graph and nothing long-lived, because an extension can be launched
/// and killed at any moment.
public enum LumoStack {

    /// Shared defaults for the App Group.
    ///
    /// `nil` when the App Group entitlement is missing or mis-typed. That is a build/signing
    /// failure rather than a runtime condition, but it must be *detectable* rather than silently
    /// papered over: falling back to `.standard` would give each process its own private copy of
    /// the state, so shields would appear to work in the app and do nothing at all in the
    /// extensions — the worst kind of bug to diagnose.
    ///
    /// `nonisolated(unsafe)` is required, not lazy: `UserDefaults`' Sendable conformance is
    /// explicitly marked unavailable (`@_nonSendable(_assumed)`), so it cannot be added
    /// retroactively and a plain `static let` will not compile under Swift 6. Apple documents
    /// the class as thread-safe, and this reference is assigned once and never mutated, so the
    /// unsafety is confined to the annotation itself. This is the only one in the codebase.
    public nonisolated(unsafe) static let defaults = UserDefaults(suiteName: AppGroup.identifier)

    public static var isAppGroupAvailable: Bool { defaults != nil }

    /// Lock file inside the shared container, so all four processes contend on one inode.
    public static var lockURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent("lumo.state.lock")
    }

    public static func diagnostics(for process: ProcessTag) -> any Diagnosing {
        guard let defaults else { return NullDiagnostics() }
        return RingBufferDiagnostics(defaults: defaults, process: process)
    }

    public static func stateStore(for process: ProcessTag) -> DefaultsStateStore? {
        guard let defaults else { return nil }
        return DefaultsStateStore(defaults: defaults, diagnostics: diagnostics(for: process))
    }

    public static func lock(for process: ProcessTag) -> any CrossProcessLocking {
        guard let lockURL else {
            // No shared container means no cross-process contention to manage either, so a
            // no-op lock is honest rather than dangerous — and `stateStore` will already be nil.
            return NoOpLock()
        }
        return FileLock(url: lockURL, diagnostics: diagnostics(for: process))
    }

    /// Returns `nil` when the App Group is unavailable, so callers must handle it explicitly
    /// rather than operate on a private state store they think is shared.
    public static func reconciler(for process: ProcessTag) -> ShieldReconciler? {
        guard let store = stateStore(for: process) else { return nil }
        let diag = diagnostics(for: process)
        return ShieldReconciler(
            state: store,
            shields: LiveShieldStore(diagnostics: diag),
            scheduler: LiveActivityScheduler(diagnostics: diag),
            lock: lock(for: process),
            clock: SystemNow(),
            diagnostics: diag
        )
    }

    public static func spendCoordinator(for process: ProcessTag) -> SpendCoordinator? {
        guard let store = stateStore(for: process) else { return nil }
        let diag = diagnostics(for: process)
        return SpendCoordinator(
            state: store,
            shields: LiveShieldStore(diagnostics: diag),
            scheduler: LiveActivityScheduler(diagnostics: diag),
            lock: lock(for: process),
            clock: SystemNow(),
            diagnostics: diag
        )
    }

    /// Synchronous reconcile for a given process. The one-liner extensions call.
    ///
    /// Synchronous all the way down, deliberately: on the app's foreground path an `await` is a
    /// suspension point the user can exploit by backgrounding mid-reconcile, leaving shields
    /// half-applied.
    @discardableResult
    public static func reconcileNow(_ process: ProcessTag) -> ShieldReconciler.Outcome? {
        reconciler(for: process)?.reconcile(by: process)
    }
}

#endif
