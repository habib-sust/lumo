import Foundation
@testable import LumoCore

/// Fakes for the seams.
///
/// The important capability here is **failing on demand at a chosen call**. The spend
/// protocol's whole safety argument is about what state the system is left in when a process
/// dies partway through, and Family Controls cannot run in the Simulator — so injected
/// failure is the only way to test the crash table at all.
///
/// All `@unchecked Sendable` with a lock: the protocols are `Sendable` and these need mutable
/// recording. Contained to this file, and tests are single-threaded anyway.

enum FakeError: Error, Equatable {
    /// Simulates the process dying mid-transaction.
    case injected(at: Int)
    case unavailable
}

// MARK: - Shield store

final class FakeShieldStore: ShieldStoring, @unchecked Sendable {
    private let lock = NSLock()

    private(set) var shielded: Set<BucketID> = []
    private(set) var destroyed: Set<BucketID> = []
    /// Ordered log, so tests can assert the ORDER of effects and not merely the end state.
    /// Ordering is the entire point of the spend protocol.
    private(set) var calls: [String] = []

    var failOnCall: Int?
    var reportedStoreNames: Set<String>?

    private var callCount = 0

    private func tick(_ label: String) throws {
        try lock.withLock {
            callCount += 1
            calls.append(label)
            if let failOnCall, callCount == failOnCall { throw FakeError.injected(at: callCount) }
        }
    }

    func shield(_ bucket: BucketID, token: TokenBlob, kind: BucketKind) throws {
        try tick("shield(\(bucket.slot))")
        lock.withLock { shielded.insert(bucket) }
    }

    func unshield(_ bucket: BucketID) throws {
        try tick("unshield(\(bucket.slot))")
        lock.withLock { shielded.remove(bucket) }
    }

    func destroy(_ bucket: BucketID) throws {
        try tick("destroy(\(bucket.slot))")
        lock.withLock {
            shielded.remove(bucket)
            destroyed.insert(bucket)
        }
    }

    func knownStoreNames() -> Set<String>? { lock.withLock { reportedStoreNames } }

    func reset() {
        lock.withLock {
            shielded = []; destroyed = []; calls = []; callCount = 0; failOnCall = nil
        }
    }
}

// MARK: - Activity scheduler

final class FakeActivityScheduler: ActivityScheduling, @unchecked Sendable {
    private let lock = NSLock()

    struct Armed: Equatable {
        var bucket: BucketID
        var wallClockSeconds: TimeInterval
        var usageBudgetSeconds: TimeInterval?
    }

    private(set) var armed: [String: Armed] = [:]
    private(set) var calls: [String] = []

    var failOnCall: Int?
    private var callCount = 0

    func arm(
        activityName: String,
        bucket: BucketID,
        token: TokenBlob,
        kind: BucketKind,
        wallClockSeconds: TimeInterval,
        usageBudgetSeconds: TimeInterval?
    ) throws {
        try lock.withLock {
            callCount += 1
            calls.append("arm(\(activityName))")
            if let failOnCall, callCount == failOnCall { throw FakeError.injected(at: callCount) }
            armed[activityName] = Armed(
                bucket: bucket,
                wallClockSeconds: wallClockSeconds,
                usageBudgetSeconds: usageBudgetSeconds
            )
        }
    }

    func disarm(activityName: String) {
        lock.withLock {
            calls.append("disarm(\(activityName))")
            armed.removeValue(forKey: activityName)
        }
    }

    func activeActivityNames() -> Set<String> { lock.withLock { Set(armed.keys) } }

    func reset() {
        lock.withLock { armed = [:]; calls = []; callCount = 0; failOnCall = nil }
    }
}

// MARK: - State store

final class FakeStateStore: StateStoring, @unchecked Sendable {
    private let lock = NSLock()

    private var state: SharedState
    private var buckets: BucketTable
    private var schemaVersion: Int?

    /// Set to simulate a corrupt or unreadable payload — the path that leads to SafeMode.
    var loadStateError: Error?
    var saveStateError: Error?
    private(set) var saveCount = 0

    init(
        state: SharedState = .initial,
        buckets: BucketTable = .empty,
        schemaVersion: Int? = SchemaVersion.current
    ) {
        self.state = state
        self.buckets = buckets
        self.schemaVersion = schemaVersion
    }

    func loadState() throws -> SharedState {
        try lock.withLock {
            if let loadStateError { throw loadStateError }
            return state
        }
    }

    func saveState(_ newValue: SharedState) throws {
        try lock.withLock {
            if let saveStateError { throw saveStateError }
            saveCount += 1
            state = newValue
        }
    }

    func loadBuckets() throws -> BucketTable { lock.withLock { buckets } }
    func saveBuckets(_ table: BucketTable, essential intent: EssentialIntent) throws {
        lock.withLock {
            var outgoing = table
            // Mirrors the real store, so a test cannot pass where production would not.
            if intent == .preserve { outgoing.essential = buckets.essential }
            buckets = outgoing
        }
    }
    func loadSchemaVersion() -> Int? { lock.withLock { schemaVersion } }
    func saveSchemaVersion(_ version: Int) throws { lock.withLock { schemaVersion = version } }

    /// Peek without going through the protocol, for assertions.
    var currentState: SharedState { lock.withLock { state } }
    var currentBuckets: BucketTable { lock.withLock { buckets } }
}

// MARK: - Lock

/// Grants the lock immediately. The default for tests that are not about contention.
struct ImmediateLock: CrossProcessLocking {
    func withLock<T>(_ body: () throws -> T) rethrows -> T? { try body() }
}

/// Always refuses the lock, simulating contention.
///
/// Matters because the shield-render path must not stall: the correct behaviour under
/// contention is to give up and render from last-known state, never to block.
struct ContendedLock: CrossProcessLocking {
    func withLock<T>(_ body: () throws -> T) rethrows -> T? { nil }
}

// MARK: - Diagnostics

final class RecordingDiagnostics: Diagnosing, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var events: [(event: String, detail: String)] = []

    func record(_ event: String, detail: String) {
        lock.withLock { events.append((event, detail)) }
    }

    func contains(_ event: String) -> Bool {
        lock.withLock { events.contains { $0.event == event } }
    }
}


// MARK: - Coin ledger

final class FakeLedgerStore: CoinLedgerStore, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var entries: [LedgerEntry] = []

    /// Set to simulate a store that cannot be written, so the retry path is testable.
    var appendError: Error?
    var readError: Error?
    private(set) var appendCallCount = 0

    init(entries: [LedgerEntry] = []) { self.entries = entries }

    func allEntries() throws -> [LedgerEntry] {
        try lock.withLock {
            if let readError { throw readError }
            return entries.sorted { $0.at < $1.at }
        }
    }

    func append(_ newEntries: [LedgerEntry]) throws {
        try lock.withLock {
            if let appendError { throw appendError }
            appendCallCount += 1
            entries.append(contentsOf: newEntries)
        }
    }

    func hasEntries(forIntent intentID: UUID) throws -> Bool {
        lock.withLock { entries.contains { $0.intentID == intentID } }
    }

    func rows(of kind: LedgerKind) -> [LedgerEntry] {
        lock.withLock { entries.filter { $0.kind == kind } }
    }
}
