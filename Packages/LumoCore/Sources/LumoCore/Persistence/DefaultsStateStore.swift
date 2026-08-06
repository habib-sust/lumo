import Foundation

/// `StateStoring` over a `UserDefaults` suite.
///
/// Lives in LumoCore rather than LumoShieldKit deliberately: `UserDefaults` is Foundation, so
/// keeping it here means the **corruption-recovery ladder is testable on macOS**. That ladder
/// is the code protecting the user's coin balance, so it is exactly what should not be
/// device-only. LumoShieldKit's job is reduced to naming the App Group suite.
public struct DefaultsStateStore: StateStoring, @unchecked Sendable {

    // `@unchecked Sendable` because `UserDefaults`' Sendable conformance is explicitly
    // unavailable (`@_nonSendable(_assumed)`), so a retroactive conformance is not an option.
    // Apple documents the class as thread-safe, and this type only ever reads and writes
    // whole values, so the assertion is true.
    private let defaults: UserDefaults
    private let diagnostics: any Diagnosing

    public init(defaults: UserDefaults, diagnostics: any Diagnosing = NullDiagnostics()) {
        self.defaults = defaults
        self.diagnostics = diagnostics
    }

    public enum StoreError: Error, Equatable {
        /// Both the main payload and its backup failed to decode. The caller must enter
        /// SafeMode rather than invent a state — the wallet is rebuilt from the durable
        /// ledger later, never zeroed here.
        case unrecoverable(key: String)
    }

    // MARK: - State

    /// Recovery ladder: main, then backup, then fail.
    ///
    /// Never fabricates an empty state on a decode failure. Returning `.initial` here would
    /// silently reset the user's balance to zero, which is precisely the betrayal that drives
    /// away the most engaged users — and it would look like a bug that ate their coins.
    public func loadState() throws -> SharedState {
        if let value = decode(SharedState.self, forKey: StateKey.state) {
            return value
        }
        if defaults.data(forKey: StateKey.state) != nil {
            diagnostics.record("state.mainCorrupt", detail: StateKey.state)
        }

        if let backup = decode(SharedState.self, forKey: StateKey.stateBackup) {
            // The backup is at most one transition stale and every transition is idempotent,
            // so re-running from it is safe.
            diagnostics.record("state.recoveredFromBackup", detail: StateKey.stateBackup)
            return backup
        }

        // Nothing stored at all is a legitimate first launch, not corruption.
        if defaults.data(forKey: StateKey.state) == nil,
           defaults.data(forKey: StateKey.stateBackup) == nil {
            return .initial
        }

        diagnostics.record("state.unrecoverable", detail: StateKey.state)
        throw StoreError.unrecoverable(key: StateKey.state)
    }

    /// Writes the backup FIRST, then the main value.
    ///
    /// Two sequential atomic writes cannot both be torn, so a crash between them leaves at
    /// least one decodable copy. Order matters: writing main first would mean a crash before
    /// the backup lands leaves the backup stale-but-valid, which is fine — but writing backup
    /// first means the backup always holds the *previous* good state, which is what recovery
    /// actually needs.
    public func saveState(_ state: SharedState) throws {
        if let previous = defaults.data(forKey: StateKey.state) {
            defaults.set(previous, forKey: StateKey.stateBackup)
        }
        defaults.set(try JSONEncoder().encode(state), forKey: StateKey.state)
    }

    // MARK: - Buckets

    /// Buckets have no backup ladder because they are reconstructible: the user can re-pick.
    /// A wallet cannot be re-picked, which is why only state gets the `.bak` treatment.
    public func loadBuckets() throws -> BucketTable {
        decode(BucketTable.self, forKey: StateKey.buckets) ?? .empty
    }

    public func saveBuckets(_ table: BucketTable) throws {
        defaults.set(try JSONEncoder().encode(table), forKey: StateKey.buckets)
    }

    // MARK: - Schema

    public func loadSchemaVersion() -> Int? {
        defaults.object(forKey: StateKey.schemaVersion) as? Int
    }

    public func saveSchemaVersion(_ version: Int) throws {
        defaults.set(version, forKey: StateKey.schemaVersion)
    }

    // MARK: - Teardown

    /// Removes everything Lumo owns.
    ///
    /// Backs "Unlock everything and remove Lumo", which must always work and must never
    /// require a Screen Time passcode the user may not have.
    public func removeAll() {
        for key in StateKey.all { defaults.removeObject(forKey: key) }
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
