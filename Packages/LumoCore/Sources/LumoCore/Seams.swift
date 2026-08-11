import Foundation

// The seams that let LumoCore hold the dangerous logic while staying Foundation-only.
//
// Family Controls does not function in the iOS Simulator at all, so "integration-test the
// shield path in CI" is not an option that exists. Instead every effect the reconciler
// produces goes through one of these protocols, LumoShieldKit supplies the real
// implementations on device, and the tests supply fakes that can fail on command.
//
// Every one of these is SYNCHRONOUS, deliberately. `reconcile()` runs on the app's
// foreground path before any UI or store work, and an `await` there is a suspension point
// the user can exploit by backgrounding mid-reconcile — leaving shields half-applied. There
// is a merge-blocking CI grep for `async` in this package to keep it that way.

// MARK: - Shield state

/// Applies and removes shields, one named store per bucket.
public protocol ShieldStoring: Sendable {
    /// Shields the given bucket. Must be idempotent.
    func shield(_ bucket: BucketID, token: TokenBlob, kind: BucketKind) throws

    /// Unshields the given bucket. Must be idempotent.
    func unshield(_ bucket: BucketID) throws

    /// Clears a bucket's store entirely, for a bucket that no longer exists.
    ///
    /// Distinct from `unshield` on purpose: unshielding is a temporary, paid state that the
    /// reconciler will undo, whereas clearing is permanent teardown. Conflating them would
    /// let a removed app stay reachable.
    func destroy(_ bucket: BucketID) throws

    /// Store names currently known to the system, where the platform can report them.
    /// `nil` means "cannot tell on this OS version" — which must not be read as "none",
    /// or we would happily believe the user has no shields at all.
    func knownStoreNames() -> Set<String>?
}

// MARK: - Activity scheduling

/// Arms and disarms the OS-side timers that guarantee a window re-locks.
public protocol ActivityScheduling: Sendable {
    /// Arms monitoring for one window.
    ///
    /// `wallClockSeconds` is the PRIMARY expiry mechanism. `usageBudgetSeconds` is advisory
    /// only: `eventDidReachThreshold` is reported firing at +0 seconds on current iOS even
    /// with `includesPastActivity: false`, so it can never be the sole guarantee.
    func arm(
        activityName: String,
        bucket: BucketID,
        token: TokenBlob,
        kind: BucketKind,
        wallClockSeconds: TimeInterval,
        usageBudgetSeconds: TimeInterval?
    ) throws

    func disarm(activityName: String)

    /// Activities Lumo currently has registered, for garbage collection against the
    /// 20-activity cap. Prefix-filtered by the implementation so we never stop another
    /// app's monitoring.
    func activeActivityNames() -> Set<String>
}

// MARK: - Persistence

/// Reads and writes the App Group payloads.
///
/// Errors are surfaced rather than swallowed because a failed *write* and a failed *read*
/// need opposite handling: a failed read falls back to the backup and then SafeMode, while a
/// failed write must abort the transaction rather than let state diverge from reality.
public protocol StateStoring: Sendable {
    func loadState() throws -> SharedState
    func saveState(_ state: SharedState) throws
    func loadBuckets() throws -> BucketTable

    /// Persists the bucket table. **The essential-apps intent is mandatory.**
    ///
    /// Deliberately not defaulted, and deliberately not inferable. The essential set is the one
    /// piece of state in Lumo whose loss has a physical-harm path — the driving evidence is a
    /// competitor's reviewer writing *"I am a type 1 diabetic and it would block my pump… I can die
    /// from that."* It has now been silently dropped **three times**, by three different call sites,
    /// each of which passed a table whose `essential` happened to be empty:
    ///
    ///   1. skipping the blocklist step never committed at all
    ///   2. editing the blocklist replaced essential with the empty in-memory selection
    ///   3. the same wipe again via `commitEssentialOnly`, which the first fix missed
    ///
    /// Three failures at three call sites is not a run of bad luck, it is a missing constraint. So
    /// the decision moves into the type system: a caller cannot save without saying which it means,
    /// and `.preserve` makes accidental loss impossible rather than merely unlikely.
    func saveBuckets(_ table: BucketTable, essential intent: EssentialIntent) throws

    func loadSchemaVersion() -> Int?
    func saveSchemaVersion(_ version: Int) throws
}

/// Reads and writes harm telemetry.
///
/// **Separate from `StateStoring` on purpose.** Harm metrics live under their own key rather than
/// inside the hot `lumo.state` blob, so the monitor extension — which decodes that blob on every
/// callback under a 6 MB ceiling — never deserialises the user's self-reported enjoyment scores. It
/// has no business reading them and no reason to pay for them. Keeping the seam separate too means
/// no extension can acquire the capability by accident.
///
/// Never throws on read. This is instrumentation: losing it must never degrade the product, so a
/// corrupt payload resets to empty rather than escalating. That is the opposite of the wallet's
/// rule, and correct for the same reason — one is the user's property, the other is a measurement.
public protocol HarmStoring: Sendable {
    func loadHarm() -> HarmMetrics
    func saveHarm(_ metrics: HarmMetrics) throws
}

/// What a caller means about the essential-apps set when saving a bucket table.
public enum EssentialIntent: Sendable, Equatable {
    /// Keep whatever is already persisted, ignoring the incoming set.
    ///
    /// The right answer for every path that is not the user editing the protected list — which is
    /// almost all of them.
    case preserve

    /// The user explicitly edited the protected list. Replacement is honoured, including clearing
    /// it, because deliberately removing protection is theirs to choose.
    case replaceBecauseUserEdited
}

// MARK: - Mutual exclusion

/// Serialises state transitions across the four processes.
///
/// `flock` on a file in the App Group container, not an actor: an actor cannot span
/// processes, and `await`ing one would break the synchronous guarantee above. `flock` also
/// releases automatically when a process dies — including a Jetsam kill — so a dying monitor
/// extension cannot deadlock the app.
public protocol CrossProcessLocking: Sendable {
    /// Runs `body` under the lock. Never blocks indefinitely: on contention it gives up and
    /// returns `nil`, because the shield-render path must not stall.
    func withLock<T>(_ body: () throws -> T) rethrows -> T?
}

// MARK: - Diagnostics

/// Best-effort breadcrumbs. Never gates logic, never throws.
///
/// This is the only telemetry available from the field for the monitor extension: a Jetsam
/// kill leaves no crash log a user would ever report.
public protocol Diagnosing: Sendable {
    func record(_ event: String, detail: String)
}

/// A diagnostics sink that discards everything. Default so no call site needs a nil check.
public struct NullDiagnostics: Diagnosing {
    public init() {}
    public func record(_ event: String, detail: String) {}
}
