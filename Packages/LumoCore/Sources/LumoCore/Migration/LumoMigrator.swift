import Foundation

/// One single-step schema migration.
///
/// Steps are pure `Data -> Data` so they compose into a uniform chain, but each one decodes to
/// a **frozen `_vN` shape** internally, so the transformation itself is type-checked rather than
/// key-poking at JSON. See `SharedState_v1` for the pattern.
///
/// A released shape is never edited in place. Once a version ships, its struct is frozen and the
/// next version gets a new one — otherwise a migration written today silently changes meaning
/// when the current shape evolves tomorrow.
public struct MigrationStep: Sendable {
    public let from: Int
    public let to: Int
    let body: @Sendable (Data) throws -> Data

    public init(from: Int, to: Int, body: @escaping @Sendable (Data) throws -> Data) {
        self.from = from
        self.to = to
        self.body = body
    }

    public func apply(_ data: Data) throws -> Data {
        try body(data)
    }
}

/// Runs schema migrations.
///
/// **Only the app migrates.** Extensions read the version first and refuse to write on mismatch;
/// two processes migrating concurrently, or an extension writing a shape the app has not yet
/// converted, would corrupt the wallet silently.
public enum LumoMigrator {

    /// Production chain. Empty at v1 — there is nothing to migrate yet.
    ///
    /// The harness exists anyway because the first migration is exactly when you least want to
    /// be designing one: it will arrive alongside a feature, under time pressure, against real
    /// user data that cannot be re-created.
    public static let productionSteps: [MigrationStep] = []

    public enum MigrationError: Error, Equatable {
        /// Stored data is newer than this build understands. Never guess — refuse and let the
        /// caller enter SafeMode.
        case futureVersion(stored: Int, supported: Int)
        /// No step chain reaches the target. A packaging mistake, caught loudly at the boundary
        /// rather than halfway through mutating the user's state.
        case noPath(from: Int, to: Int)
        case stepFailed(from: Int, to: Int)
    }

    public struct Outcome: Equatable, Sendable {
        public var data: Data
        public var fromVersion: Int
        public var toVersion: Int
        public var stepsApplied: Int

        public var didMigrate: Bool { stepsApplied > 0 }
    }

    /// Builds the ordered chain from `from` to `to`, or throws if it cannot be completed.
    ///
    /// Validated up front so a partially-applicable chain is rejected before any data is
    /// touched. A migration that gets halfway and then discovers it cannot finish is the worst
    /// possible outcome — the state is left in a shape no version understands.
    public static func plan(
        from: Int,
        to: Int = SchemaVersion.current,
        steps: [MigrationStep] = productionSteps
    ) throws -> [MigrationStep] {
        if from == to { return [] }
        if from > to { throw MigrationError.futureVersion(stored: from, supported: to) }

        var chain: [MigrationStep] = []
        var cursor = from
        while cursor < to {
            guard let step = steps.first(where: { $0.from == cursor }) else {
                throw MigrationError.noPath(from: from, to: to)
            }
            chain.append(step)
            cursor = step.to
        }
        // A step that overshoots would skip a version's transformation entirely.
        guard cursor == to else { throw MigrationError.noPath(from: from, to: to) }
        return chain
    }

    public static func migrate(
        data: Data,
        from: Int,
        to: Int = SchemaVersion.current,
        steps: [MigrationStep] = productionSteps
    ) throws -> Outcome {
        let chain = try plan(from: from, to: to, steps: steps)
        var payload = data
        for step in chain {
            do {
                payload = try step.apply(payload)
            } catch {
                throw MigrationError.stepFailed(from: step.from, to: step.to)
            }
        }
        return Outcome(data: payload, fromVersion: from, toVersion: to, stepsApplied: chain.count)
    }

    /// App-side orchestration: migrate the stored state if needed, then bump the version.
    ///
    /// The version is written **last**, deliberately. A crash between migrating the payload and
    /// bumping the version means the migration simply re-runs from the old version next launch —
    /// which is safe because each step is pure. Bumping first would leave data in the old shape
    /// labelled as the new one, which nothing could ever recover from.
    ///
    /// Call inside the cross-process lock, before the first reconcile.
    @discardableResult
    public static func migrateIfNeeded(
        defaults: UserDefaults,
        to target: Int = SchemaVersion.current,
        steps: [MigrationStep] = productionSteps
    ) throws -> Outcome? {
        let stored = defaults.object(forKey: StateKey.schemaVersion) as? Int

        guard let stored else {
            // No version recorded. Either a genuine first launch or a pre-versioning build;
            // either way the current shape decodes from absence, so stamping the version is
            // correct and no transformation is needed.
            defaults.set(target, forKey: StateKey.schemaVersion)
            return nil
        }

        if stored == target { return nil }
        if stored > target { throw MigrationError.futureVersion(stored: stored, supported: target) }

        guard let data = defaults.data(forKey: StateKey.state) else {
            // Nothing stored to migrate, so the version alone is stale.
            defaults.set(target, forKey: StateKey.schemaVersion)
            return nil
        }

        let outcome = try migrate(data: data, from: stored, to: target, steps: steps)
        defaults.set(outcome.data, forKey: StateKey.state)
        // Invalidate the backup: it still holds the OLD shape, so recovering from it after a
        // successful migration would silently downgrade the payload.
        defaults.removeObject(forKey: StateKey.stateBackup)
        defaults.set(target, forKey: StateKey.schemaVersion)
        return outcome
    }
}
