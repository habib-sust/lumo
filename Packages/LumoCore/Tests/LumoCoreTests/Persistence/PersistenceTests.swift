import Foundation
import Testing
@testable import LumoCore

/// T-STORE-01…09, T-LOCK-01…05, T-DIAG-01…04.
///
/// These run on macOS because `UserDefaults` and `flock` are both Foundation/POSIX. That is the
/// point of keeping them in LumoCore: the code protecting the user's coin balance and the code
/// serialising four processes are the last things that should be device-only.
@Suite("Persistence, locking, diagnostics")
struct PersistenceTests {

    /// An isolated defaults suite per test, so tests cannot see each other's writes.
    private func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let d = UserDefaults(suiteName: "lumo.test.\(name)")!
        for key in StateKey.all { d.removeObject(forKey: key) }
        return d
    }

    // MARK: - Round trip

    @Test("State round-trips through the store")
    func stateRoundTrips() throws {
        let store = DefaultsStateStore(defaults: makeDefaults())
        let state = SharedState(wallet: Wallet(granted: 40, earned: 60), flags: [.tokenDriftDetected])

        try store.saveState(state)
        #expect(try store.loadState() == state)
    }

    @Test("A first launch with nothing stored yields the initial state, not an error")
    func firstLaunchIsNotAnError() throws {
        let store = DefaultsStateStore(defaults: makeDefaults())
        #expect(try store.loadState() == .initial)
    }

    @Test("Buckets round-trip")
    func bucketsRoundTrip() throws {
        let store = DefaultsStateStore(defaults: makeDefaults())
        let table = try BucketPartitioner.commit(
            applications: [TokenBlob(raw: Data([1])), TokenBlob(raw: Data([2]))],
            categories: [], into: .empty, now: .fixture
        ).table

        try store.saveBuckets(table, essential: .replaceBecauseUserEdited)
        #expect(try store.loadBuckets() == table)
    }

    // MARK: - The recovery ladder

    @Test("A corrupt main payload recovers from the backup")
    func corruptMainRecoversFromBackup() throws {
        let defaults = makeDefaults()
        let diag = RecordingDiagnostics()
        let store = DefaultsStateStore(defaults: defaults, diagnostics: diag)

        let good = SharedState(wallet: Wallet(granted: 30, earned: 70))
        try store.saveState(good)
        // A second save pushes `good` into the backup slot.
        try store.saveState(SharedState(wallet: Wallet(granted: 0, earned: 70)))

        // Now corrupt the main value only.
        defaults.set(Data("{ not json".utf8), forKey: StateKey.state)

        let recovered = try store.loadState()
        #expect(recovered.wallet.granted == 30, "should have fallen back to the backup")
        #expect(diag.contains("state.recoveredFromBackup"))
    }

    @Test("Both copies corrupt throws rather than inventing an empty wallet")
    func bothCorruptThrows() throws {
        let defaults = makeDefaults()
        let store = DefaultsStateStore(defaults: defaults)
        try store.saveState(SharedState(wallet: Wallet(granted: 10, earned: 500)))
        try store.saveState(SharedState(wallet: Wallet(granted: 10, earned: 500)))

        defaults.set(Data("{ bad".utf8), forKey: StateKey.state)
        defaults.set(Data("{ also bad".utf8), forKey: StateKey.stateBackup)

        // Returning `.initial` here would silently delete 500 earned coins and look exactly
        // like a bug that ate them. Throwing routes the caller into SafeMode, which shields
        // everything and leaves the balance to be rebuilt from the durable ledger.
        #expect(throws: DefaultsStateStore.StoreError.unrecoverable(key: StateKey.state)) {
            _ = try store.loadState()
        }
    }

    @Test("The backup holds the PREVIOUS state, not the current one")
    func backupHoldsPreviousState() throws {
        let defaults = makeDefaults()
        let store = DefaultsStateStore(defaults: defaults)

        try store.saveState(SharedState(wallet: Wallet(granted: 1, earned: 0)))
        try store.saveState(SharedState(wallet: Wallet(granted: 2, earned: 0)))

        // If the backup mirrored the current value it would be worthless — a torn write would
        // corrupt both. It has to lag by exactly one transition.
        let backup = try #require(defaults.data(forKey: StateKey.stateBackup))
        let decoded = try JSONDecoder().decode(SharedState.self, from: backup)
        #expect(decoded.wallet.granted == 1)
    }

    @Test("Corrupt buckets degrade to empty rather than throwing")
    func corruptBucketsDegradeGracefully() throws {
        // Asymmetric with state on purpose: a bucket table is reconstructible because the user
        // can re-pick their apps. A wallet cannot be re-picked, which is why only state gets
        // the backup ladder.
        let defaults = makeDefaults()
        let store = DefaultsStateStore(defaults: defaults)
        defaults.set(Data("{ nope".utf8), forKey: StateKey.buckets)

        #expect(try store.loadBuckets() == .empty)
    }

    @Test("removeAll clears every lumo key")
    func removeAllClearsEverything() throws {
        let defaults = makeDefaults()
        let store = DefaultsStateStore(defaults: defaults)
        try store.saveState(SharedState(wallet: Wallet(granted: 5, earned: 5)))
        try store.saveBuckets(.empty, essential: .replaceBecauseUserEdited)
        try store.saveSchemaVersion(1)

        store.removeAll()

        // Backs "Unlock everything and remove Lumo", which must always work and must never
        // require a Screen Time passcode.
        for key in StateKey.all {
            #expect(defaults.object(forKey: key) == nil, "\(key) survived teardown")
        }
    }

    @Test("Schema version persists and reads back")
    func schemaVersionPersists() throws {
        let store = DefaultsStateStore(defaults: makeDefaults())
        #expect(store.loadSchemaVersion() == nil)
        try store.saveSchemaVersion(SchemaVersion.current)
        #expect(store.loadSchemaVersion() == SchemaVersion.current)
    }

    // MARK: - FileLock

    private func lockURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lumo-\(UUID().uuidString).lock")
    }

    @Test("The lock runs its body and returns its value")
    func lockRunsBody() {
        let lock = FileLock(url: lockURL())
        #expect(lock.withLock { 42 } == 42)
    }

    @Test("The lock file is created on first use")
    func lockFileIsCreated() {
        let url = lockURL()
        let lock = FileLock(url: url)
        _ = lock.withLock { true }
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("The lock is re-acquirable after release")
    func lockIsReusable() {
        let lock = FileLock(url: lockURL())
        #expect(lock.withLock { 1 } == 1)
        #expect(lock.withLock { 2 } == 2)
    }

    /// Spawns a child that takes the lock, then waits until it has actually got it.
    ///
    /// Signals readiness through a sentinel file rather than a fixed sleep. The first version
    /// of this slept 400 ms and hoped, which was not reliably long enough for Python's cold
    /// start — the test then "passed" the exclusion check for the wrong reason.
    private func spawnLockHolder(at url: URL, holdSeconds: Int = 5) throws -> (Process, URL) {
        let ready = url.appendingPathExtension("ready")
        try? FileManager.default.removeItem(at: ready)

        let script = """
        import fcntl, time, os
        f = open('\(url.path)', 'w')
        fcntl.flock(f, fcntl.LOCK_EX)
        open('\(ready.path)', 'w').close()
        time.sleep(\(holdSeconds))
        """
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        child.arguments = ["-c", script]
        try child.run()

        // Wait for the sentinel, up to 10s.
        let deadline = Date().addingTimeInterval(10)
        while !FileManager.default.fileExists(atPath: ready.path), Date() < deadline {
            usleep(20_000)
        }
        return (child, ready)
    }

    private func reap(_ child: Process, _ ready: URL) {
        child.terminate()
        child.waitUntilExit()
        try? FileManager.default.removeItem(at: ready)
    }

    @Test("A second process is excluded while the lock is held, and admitted after")
    func lockExcludesAnotherProcess() throws {
        // Genuinely two processes, not two threads: flock is per-open-file-description, so a
        // same-process test would prove nothing about the property we actually depend on.
        let url = lockURL()
        let lock = FileLock(url: url, attempts: 1, retryInterval: 0)

        let (child, ready) = try spawnLockHolder(at: url)
        #expect(FileManager.default.fileExists(atPath: ready.path), "child never took the lock")

        #expect(lock.withLock { true } == nil, "must not acquire while the child holds it")

        reap(child, ready)

        // The kernel releases on process death — the property that stops a Jetsam-killed
        // monitor extension from deadlocking the app. Poll rather than sleep a fixed amount.
        var acquired: Bool?
        let deadline = Date().addingTimeInterval(5)
        repeat {
            acquired = lock.withLock { true }
            if acquired == nil { usleep(20_000) }
        } while acquired == nil && Date() < deadline
        #expect(acquired == true, "must be acquirable once the holder is gone")
    }

    @Test("Contention gives up promptly rather than blocking")
    func contentionIsBounded() throws {
        let url = lockURL()
        // 5 attempts x 5 ms ~= 25 ms ceiling.
        let lock = FileLock(url: url, attempts: 5, retryInterval: 0.005)

        let (child, ready) = try spawnLockHolder(at: url)
        #expect(FileManager.default.fileExists(atPath: ready.path), "child never took the lock")

        let started = Date()
        let result = lock.withLock { true }
        let elapsed = Date().timeIntervalSince(started)

        reap(child, ready)

        #expect(result == nil, "should not have acquired a held lock")
        // The shield-render path must return promptly or the system substitutes Apple's
        // generic grey shield.
        #expect(elapsed < 0.5, "gave up after \(elapsed)s — the render path cannot wait this long")
    }

    // MARK: - Diagnostics ring

    @Test("The ring keeps the most recent entries and drops the oldest")
    func ringIsBounded() {
        var ring = DiagRing.empty
        for i in 0..<(DiagRing.capacity + 20) {
            ring.append(DiagEntry(at: .fixture, process: .monitor, event: "e\(i)", detail: ""))
        }
        #expect(ring.entries.count == DiagRing.capacity)
        #expect(ring.entries.first?.event == "e20", "oldest entries should have been evicted")
        #expect(ring.entries.last?.event == "e\(DiagRing.capacity + 19)")
    }

    @Test("Details are truncated at the boundary")
    func detailIsTruncated() {
        // An unbounded detail string is the easy way to blow the size budget from a call site
        // that looks harmless.
        let entry = DiagEntry(
            at: .fixture, process: .app, event: "e",
            detail: String(repeating: "x", count: 5_000)
        )
        #expect(entry.detail.count == 120)
    }

    @Test("Diagnostics persist across store instances")
    func diagnosticsPersist() {
        let defaults = makeDefaults()
        let diag = RingBufferDiagnostics(
            defaults: defaults, process: .monitor, clock: FixedNow(.fixture))

        diag.record("jetsam.watch", detail: "resident 2.1MB")
        let loaded = RingBufferDiagnostics.load(from: defaults)

        // This is the only field telemetry for the monitor extension: a Jetsam kill leaves no
        // crash log a user would ever report.
        #expect(loaded.entries.count == 1)
        #expect(loaded.entries.first?.event == "jetsam.watch")
        #expect(loaded.entries.first?.process == .monitor)
    }

    @Test("A ring decoded from an over-long payload is clamped")
    func decodedRingIsClamped() throws {
        let oversized = DiagRing(entries: (0..<500).map {
            DiagEntry(at: .fixture, process: .app, event: "e\($0)", detail: "")
        })
        let data = try JSONEncoder().encode(oversized)
        let decoded = try JSONDecoder().decode(DiagRing.self, from: data)
        #expect(decoded.entries.count == DiagRing.capacity)
    }

    // MARK: - End to end

    @Test("The reconciler works against the real store and lock")
    func reconcilerWorksWithRealStoreAndLock() throws {
        // Everything real except the Screen Time frameworks themselves — which is as far as
        // any test can go, since Family Controls does not exist in the Simulator.
        let defaults = makeDefaults()
        let store = DefaultsStateStore(defaults: defaults)
        let clock = MutableNow(.fixture)

        let table = try BucketPartitioner.commit(
            applications: [TokenBlob(raw: Data([1])), TokenBlob(raw: Data([2]))],
            categories: [], into: .empty, now: clock.now
        ).table
        try store.saveBuckets(table, essential: .replaceBecauseUserEdited)
        try store.saveState(SharedState(wallet: Wallet(granted: 100, earned: 0)))
        try store.saveSchemaVersion(SchemaVersion.current)

        let shields = FakeShieldStore()
        let reconciler = ShieldReconciler(
            state: store, shields: shields, scheduler: FakeActivityScheduler(),
            lock: FileLock(url: lockURL()), clock: clock
        )

        let first = reconciler.reconcile(by: .app)
        #expect(first.shielded.count == 2)

        let callsAfterFirst = shields.calls.count
        let second = reconciler.reconcile(by: .monitor)
        #expect(second.isNoOp)
        #expect(shields.calls.count == callsAfterFirst, "steady state must issue zero IPC calls")
    }
}

/// T-ESSENTIAL-BOUNDARY-01…05.
///
/// The essential set has been silently dropped three times, at three different call sites, each
/// passing a table whose `essential` happened to be empty. Three failures at three sites is a
/// missing constraint rather than a run of bad luck — so the intent is now a protocol requirement
/// and the store enforces it. These tests are the enforcement's proof.
@Suite("Essential-apps save boundary")
struct EssentialBoundaryTests {

    private func makeStore(_ diag: RecordingDiagnostics = RecordingDiagnostics())
        -> (DefaultsStateStore, UserDefaults, RecordingDiagnostics) {
        let d = UserDefaults(suiteName: "lumo.boundary.\(UUID().uuidString)")!
        for key in StateKey.all { d.removeObject(forKey: key) }
        return (DefaultsStateStore(defaults: d, diagnostics: diag), d, diag)
    }

    private func table(essential: Int, apps: Int) throws -> BucketTable {
        var t = BucketTable.empty
        t.essential = Set((0..<essential).map { TokenBlob(raw: Data([0xE0, UInt8($0)])) })
        if apps > 0 {
            t = try BucketPartitioner.commit(
                applications: Set((0..<apps).map { TokenBlob(raw: Data([0xB0, UInt8($0)])) }),
                categories: [], into: t, now: .fixture
            ).table
        }
        return t
    }

    @Test(".preserve restores the persisted essential set even when the caller drops it")
    func preserveRestoresDroppedEssential() throws {
        // The EXACT shape of all three production bugs: a caller builds a table from an empty
        // in-memory selection and saves it.
        let (store, _, diag) = makeStore()
        try store.saveBuckets(try table(essential: 3, apps: 2), essential: .replaceBecauseUserEdited)
        #expect(try store.loadBuckets().essential.count == 3)

        var wiped = try store.loadBuckets()
        wiped.essential = []
        try store.saveBuckets(wiped, essential: .preserve)

        #expect(
            try store.loadBuckets().essential.count == 3,
            "protection must survive a caller that forgot it — this is the physical-harm path"
        )
        #expect(diag.contains("buckets.essentialPreserved"), "and it must be recorded loudly")
    }

    @Test(".replaceBecauseUserEdited honours a deliberate clear")
    func userEditCanClearProtection() throws {
        // Removing protection on purpose is the user's to choose; the guard must not become a
        // cage that stops them.
        let (store, _, _) = makeStore()
        try store.saveBuckets(try table(essential: 2, apps: 1), essential: .replaceBecauseUserEdited)

        var cleared = try store.loadBuckets()
        cleared.essential = []
        try store.saveBuckets(cleared, essential: .replaceBecauseUserEdited)

        #expect(try store.loadBuckets().essential.isEmpty)
    }

    @Test(".preserve still saves everything else")
    func preserveDoesNotBlockOtherChanges() throws {
        // The guard protects one field. Editing the blocklist while preserving protection is the
        // normal case and must work.
        let (store, _, _) = makeStore()
        try store.saveBuckets(try table(essential: 2, apps: 1), essential: .replaceBecauseUserEdited)

        let expanded = try BucketPartitioner.commit(
            applications: Set((0..<4).map { TokenBlob(raw: Data([0xB0, UInt8($0)])) }),
            categories: [], into: try store.loadBuckets(), now: .fixture
        ).table
        var incoming = expanded
        incoming.essential = []
        try store.saveBuckets(incoming, essential: .preserve)

        let loaded = try store.loadBuckets()
        #expect(loaded.applicationBucketCount == 4, "the blocklist edit must land")
        #expect(loaded.essential.count == 2, "while protection is preserved")
    }

    @Test("A preserved essential token is never left occupying a bucket")
    func preserveReappliesTheDenySet() throws {
        // Restoring the set is not enough on its own: if the incoming table shielded a token that
        // is essential, it has to be evicted in the same write.
        let (store, _, _) = makeStore()
        let protected = TokenBlob(raw: Data([0xE0, 0x00]))
        var initial = BucketTable.empty
        initial.essential = [protected]
        try store.saveBuckets(initial, essential: .replaceBecauseUserEdited)

        // A caller now tries to shield that very token, with essential blanked.
        var bad = try BucketPartitioner.commit(
            applications: [protected], categories: [], into: .empty, now: .fixture).table
        bad.essential = []
        try store.saveBuckets(bad, essential: .preserve)

        let loaded = try store.loadBuckets()
        #expect(loaded.essential.contains(protected))
        #expect(loaded.bucket(for: protected) == nil, "an essential token must not occupy a bucket")
        #expect(loaded.shieldableBuckets.isEmpty)
    }

    @Test("A first save with .preserve and nothing persisted is not an error")
    func preserveOnEmptyStoreIsFine() throws {
        let (store, _, _) = makeStore()
        try store.saveBuckets(try table(essential: 0, apps: 2), essential: .preserve)
        #expect(try store.loadBuckets().applicationBucketCount == 2)
    }
}
