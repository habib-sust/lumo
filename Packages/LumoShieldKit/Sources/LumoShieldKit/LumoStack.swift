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

    /// The pricing policy every process must agree on.
    ///
    /// Falls back to the default when the App Group is unavailable, which is the same value the
    /// store itself falls back to — so the three processes still agree in the degraded case rather
    /// than each inventing something different.
    public static func policy(for process: ProcessTag) -> Policy {
        stateStore(for: process)?.loadPolicy() ?? .default
    }

    /// Lock patience is per-process, because the cost of giving up differs enormously.
    ///
    /// A first device run showed EVERY monitor-extension invocation skipping on contention, which
    /// meant windows never re-locked — the monitor is the primary re-shield mechanism. The original
    /// uniform ~50 ms budget was tuned for the shield-render path and silently wrong everywhere else.
    ///
    ///   shieldConfig  ~50 ms  — sits on a latency-sensitive render path. If it stalls, the system
    ///                           substitutes Apple's generic grey shield, so giving up fast and
    ///                           rendering from last-known state is genuinely better.
    ///   monitor       ~3 s    — no UI to keep responsive, and skipping means a paid window never
    ///                           closes. Waiting is strictly better than being wrong.
    ///   app / action  ~1 s    — a user is waiting, but correctness still outranks a spinner.
    public static func lock(for process: ProcessTag) -> any CrossProcessLocking {
        guard let lockURL else {
            // No shared container means no cross-process contention to manage either, so a
            // no-op lock is honest rather than dangerous — and `stateStore` will already be nil.
            return NoOpLock()
        }
        let attempts: Int
        let interval: TimeInterval
        switch process {
        case .shieldConfig:
            attempts = 10
            interval = 0.005
        case .monitor:
            attempts = 120
            interval = 0.025
        case .app, .shieldAction:
            attempts = 40
            interval = 0.025
        }
        return FileLock(
            url: lockURL,
            attempts: attempts,
            retryInterval: interval,
            diagnostics: diagnostics(for: process)
        )
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
    public static func reconcileNow(
        _ process: ProcessTag,
        observing eventName: String? = nil
    ) -> ShieldReconciler.Outcome? {
        reconciler(for: process)?.reconcile(by: process, observing: eventName)
    }

    /// The free, always-available unlock and the teardown path.
    ///
    /// Returns `nil` only when the App Group is unavailable — in which case there are no shields
    /// to release either, so there is nothing the user is trapped behind.
    public static func emergencyUnlock(for process: ProcessTag) -> EmergencyUnlock? {
        guard let store = stateStore(for: process) else { return nil }
        let diag = diagnostics(for: process)
        return EmergencyUnlock(
            state: store,
            shields: LiveShieldStore(diagnostics: diag),
            scheduler: LiveActivityScheduler(diagnostics: diag),
            lock: lock(for: process),
            clock: SystemNow(),
            diagnostics: diag
        )
    }

    /// App launch: migrate if needed, then reconcile. **App only.**
    ///
    /// Extensions must never call this. Two processes migrating concurrently, or an extension
    /// writing a shape the app has not yet converted, would corrupt the wallet silently — which
    /// is why the extensions only ever read the version and refuse to write on a mismatch.
    ///
    /// The migration runs inside the same lock as the reconcile and strictly before it, so the
    /// reconciler never sees a half-converted payload.
    @discardableResult
    public static func startUp() -> ShieldReconciler.Outcome? {
        let diag = diagnostics(for: .app)

        lock(for: .app).withLock {
            guard let defaults else { return }
            do {
                if let outcome = try LumoMigrator.migrateIfNeeded(defaults: defaults) {
                    diag.record(
                        "migration.applied",
                        detail: "v\(outcome.fromVersion)->v\(outcome.toVersion) in \(outcome.stepsApplied) step(s)"
                    )
                }
            } catch {
                // Refuse to operate on a layout we do not understand. The reconciler's own
                // schema gate will then shield everything rather than guess — which is the safe
                // direction, and the wallet is left intact for a later build to read.
                diag.record("migration.refused", detail: "\(error)")
            }
        }

        return reconcileNow(.app)
    }
}

#endif
