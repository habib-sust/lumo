import Foundation

/// The shared-container identity. Must match the App Group in every target's entitlements.
public enum AppGroup {
    public static let identifier = "group.com.habib.Lumo"
}

/// Every key in the shared defaults, in one place.
///
/// The split across keys is deliberate, on two axes: **who writes** each key (so the
/// single-writer rules are structural rather than conventional), and **who needs to
/// decode** it (so the 6 MB monitor extension decodes ~4 KB rather than ~30 KB).
public enum StateKey {
    /// Read FIRST, before anything else. Migration gate. App writes; all four read.
    public static let schemaVersion = "lumo.schema.version"

    /// The hot contended blob: wallet, windows, journal, mirror, flags.
    /// Written by app, monitor and shield-action, always under the lock.
    public static let state = "lumo.state"

    /// Written immediately BEFORE `state`, inside the same lock.
    ///
    /// Two sequential atomic writes cannot both be torn, so this is what stops a corrupt
    /// write from zeroing the wallet. Rebuilding a balance from nothing would delete coins
    /// the user earned, which is precisely the betrayal that drives away the most engaged
    /// users — so the recovery ladder never zeroes a balance.
    public static let stateBackup = "lumo.state.bak"

    /// Slot to token mapping plus the essential deny-set. App-write-only.
    ///
    /// Separate from `state` because it is the largest payload (up to 48 encoded tokens)
    /// and never changes during a spend. Keeping it out means a spend transaction does not
    /// re-serialise it under the lock.
    public static let buckets = "lumo.buckets"

    /// Prices, ramp factor, window lengths, shield copy, feature gates. App-write-only.
    public static let policy = "lumo.policy"

    /// The shield-config extension's ONLY write: what it last rendered, unknown-token
    /// sightings, drift flags. It must never write shield state.
    public static let renderProvenance = "lumo.render"

    /// Ring buffer for the debug panel. Best-effort, bounded, never gates logic.
    public static let diagnostics = "lumo.diag"

    /// Harm telemetry. App-write-only and app-read-only.
    ///
    /// Kept OUT of `lumo.state` deliberately: the monitor extension decodes that blob on every
    /// callback under a 6 MB ceiling, and it has no use for enjoyment samples. Splitting by who
    /// needs to decode is the same reason bucket tokens live in their own key.
    public static let harm = "lumo.harm"

    /// The habit timer currently running, if any. **App-only**, and deliberately not in
    /// `lumo.state`: no extension has any use for it, and the hot blob is decoded on every monitor
    /// callback under a 6 MB ceiling.
    ///
    /// Persisted rather than held in memory because a timer that dies with the app is a timer that
    /// loses the user's session — and the whole point of the pause feature is that life interrupts.
    public static let timer = "lumo.timer"

    /// Everything Lumo owns, for teardown. Used by "Unlock everything and remove Lumo",
    /// which must always work and must never require a Screen Time passcode.
    public static let all: [String] = [
        schemaVersion, state, stateBackup, buckets, policy, renderProvenance, diagnostics, harm,
        timer,
    ]
}

public enum SchemaVersion {
    public static let current = 1

    /// The oldest layout this build can read. Anything older, or anything newer than
    /// `current`, means SafeMode rather than a guess.
    public static let minimumReadable = 1

    /// Whether a persisted version is safe for this build to operate on.
    ///
    /// Only the app migrates. Extensions check this first and, if it fails, refuse to write
    /// anything — a wrong guess here would corrupt the wallet silently.
    ///
    /// An app-bundle update is atomic, so skew between app and extension should be
    /// impossible. We defend anyway: the failure is silent and total, and the defence costs
    /// one integer comparison.
    public static func isReadable(_ version: Int) -> Bool {
        version >= minimumReadable && version <= current
    }
}
