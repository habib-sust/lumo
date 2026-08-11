import Foundation
import Testing
@testable import LumoCore

/// T-CODEC-01…07.
///
/// These exist because a decode failure is a product outage, not a bug report. A throw
/// while decoding shared state means SafeMode, and SafeMode shields every app the user
/// owns. During an OS-triggered extension launch we control neither ordering nor timing,
/// so tolerance has to be proven rather than assumed.
@Suite("Shared state codec")
struct CodecTests {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        try decoder.decode(T.self, from: try encoder.encode(value))
    }

    // MARK: - T-CODEC-01: round trips

    @Test("SharedState survives a round trip with every field populated")
    func sharedStateRoundTrips() throws {
        let intent = SpendIntent(
            id: UUID(),
            bucket: BucketID(slot: 7),
            phase: .armed,
            createdAt: .fixture,
            activityName: "lumo.unlock.ABC",
            price: 45,
            usageBudget: 900,
            windowSeconds: 2700,
            tierIndex: 1,
            policyFingerprint: "fp-1",
            debit: .init(granted: 30, earned: 15),
            balanceBefore: Wallet(granted: 30, earned: 20),
            ingestedIntoLedger: false,
            origin: .purchased
        )

        let state = SharedState(
            version: 1,
            wallet: Wallet(granted: 0, earned: 5),
            week: WeekLedger(
                weekStart: .fixture,
                grantIssued: 140,
                missesThisWeek: 2,
                grantDeductedThisWeek: 20,
                comebackBonusArmed: true
            ),
            windows: [
                UnlockWindow(
                    bucket: BucketID(slot: 7),
                    startedAt: .fixture,
                    endsAt: Date.fixture.addingTimeInterval(2700),
                    usageBudget: 900,
                    usageExhausted: false,
                    activityName: "lumo.unlock.ABC",
                    origin: .purchased,
                    intentID: intent.id
                ),
            ],
            journal: [intent],
            mirror: ShieldMirror(
                shielded: [BucketID(slot: 1), BucketID(slot: 2)],
                unshielded: [BucketID(slot: 7)],
                lastWriteAt: .fixture
            ),
            flags: [.tokenDriftDetected, .thresholdUntrusted],
            lastReconcileAt: .fixture,
            lastReconcileBy: .monitor,
            pendingSpendRequest: .init(bucket: BucketID(slot: 3), requestedAt: .fixture, tierIndex: 2)
        )

        #expect(try roundTrip(state) == state)
    }

    @Test("BucketTable survives a round trip")
    func bucketTableRoundTrips() throws {
        let table = BucketTable(
            buckets: [
                BucketID(slot: 0): Bucket(
                    id: BucketID(slot: 0),
                    kind: .application,
                    token: TokenBlob(raw: Data([1, 2, 3])),
                    addedAt: .fixture,
                    observedDisplayName: "Example"
                ),
                BucketID(slot: 41): Bucket(
                    id: BucketID(slot: 41),
                    kind: .category,
                    token: TokenBlob(raw: Data([9])),
                    addedAt: .fixture
                ),
            ],
            essential: [TokenBlob(raw: Data([7, 7]))],
            lastPickerCommitAt: .fixture
        )

        #expect(try roundTrip(table) == table)
    }

    // MARK: - T-CODEC-02: decode from {}
    //
    // The single most important test in this file. An empty object is what a first launch,
    // a failed write, or a truncated read looks like, and it must produce a usable state
    // rather than a throw.

    @Test("SharedState decodes from an empty JSON object")
    func sharedStateDecodesFromEmptyObject() throws {
        let state = try decoder.decode(SharedState.self, from: Data("{}".utf8))

        #expect(state.version == SchemaVersion.current)
        #expect(state.wallet == .zero)
        #expect(state.week == .empty)
        #expect(state.windows.isEmpty)
        #expect(state.journal.isEmpty)
        #expect(state.mirror == .empty)
        #expect(state.flags.isEmpty)
        #expect(state.lastReconcileAt == nil)
        #expect(state.lastReconcileBy == nil)
        #expect(state.pendingSpendRequest == nil)
    }

    @Test("Every lumo.* payload decodes from an empty JSON object", arguments: [
        "SharedState", "BucketTable", "Wallet", "WeekLedger", "ShieldMirror",
        "Bucket", "UnlockWindow", "SpendIntent", "PendingSpendRequest",
    ])
    func allPayloadsDecodeFromEmpty(name: String) throws {
        let empty = Data("{}".utf8)
        // Enumerated by name so a newly added payload type that forgets its
        // decodeIfPresent defaults shows up here as a named failure.
        switch name {
        case "SharedState":  _ = try decoder.decode(SharedState.self, from: empty)
        case "BucketTable":  _ = try decoder.decode(BucketTable.self, from: empty)
        case "Wallet":       _ = try decoder.decode(Wallet.self, from: empty)
        case "WeekLedger":   _ = try decoder.decode(WeekLedger.self, from: empty)
        case "ShieldMirror": _ = try decoder.decode(ShieldMirror.self, from: empty)
        case "Bucket":       _ = try decoder.decode(Bucket.self, from: empty)
        case "UnlockWindow": _ = try decoder.decode(UnlockWindow.self, from: empty)
        case "SpendIntent":  _ = try decoder.decode(SpendIntent.self, from: empty)
        case "PendingSpendRequest":
            _ = try decoder.decode(SharedState.PendingSpendRequest.self, from: empty)
        default: Issue.record("unhandled payload \(name)")
        }
    }

    // MARK: - T-CODEC-03: forward compatibility

    @Test("A payload from a newer build decodes, ignoring fields we do not know")
    func unknownFieldsAreIgnored() throws {
        let json = """
        {"version":1,"wallet":{"granted":10,"earned":5},"somethingFromV3":{"nested":true},"windows":[]}
        """
        let state = try decoder.decode(SharedState.self, from: Data(json.utf8))
        #expect(state.wallet.granted == 10)
        #expect(state.wallet.earned == 5)
    }

    @Test("A partial payload fills only the fields it omits")
    func partialPayloadKeepsWhatItHas() throws {
        let json = #"{"wallet":{"earned":42}}"#
        let state = try decoder.decode(SharedState.self, from: Data(json.utf8))
        #expect(state.wallet.earned == 42)
        #expect(state.wallet.granted == 0)
        #expect(state.windows.isEmpty)
    }

    // MARK: - T-CODEC-04/05: on-the-wire shape
    //
    // The debug panel dumps raw lumo.* JSON, and on device that is frequently the only
    // diagnostic available — Family Controls does not run in the Simulator. So the encoded
    // shape being human-readable is a real requirement, not cosmetics.

    @Test("Bucket dictionaries encode as a keyed object, not a flat array")
    func bucketDictionaryEncodesAsKeyedObject() throws {
        let table = BucketTable(buckets: [
            BucketID(slot: 3): Bucket(
                id: BucketID(slot: 3), kind: .application,
                token: TokenBlob(raw: Data([1])), addedAt: .fixture
            ),
        ])
        let json = try #require(String(data: try encoder.encode(table), encoding: .utf8))

        // Zero-padded key, so slots sort lexicographically the same way they sort numerically.
        #expect(json.contains(#""03""#))
        // Swift's default for a non-CodingKeyRepresentable key would be [key, value, …].
        #expect(!json.contains(#""buckets":[{"slot""#))
    }

    @Test("Flags encodes as a bare integer")
    func flagsEncodeAsBareInt() throws {
        let state = SharedState(flags: [.safeMode, .tokenDriftDetected]) // 1 | 4 == 5
        let json = try #require(String(data: try encoder.encode(state), encoding: .utf8))
        #expect(json.contains(#""flags":5"#))
        #expect(!json.contains("rawValue"))
    }

    @Test("Flags round trip through their raw value")
    func flagsRoundTrip() throws {
        let all: Flags = [
            .safeMode, .needsMigration, .tokenDriftDetected,
            .authorizationLost, .thresholdUntrusted, .activityBudgetFull,
        ]
        #expect(try roundTrip(all) == all)
        #expect(try roundTrip(Flags()) == Flags())
    }

    // MARK: - T-CODEC-06: size budget
    //
    // The monitor extension decodes this against a 6 MB high-watermark. Past it, Jetsam
    // kills the process — and when that process dies the shield never re-applies, silently,
    // with no crash log a user would ever report.

    @Test("The absolute worst-case SharedState stays inside the size guardrail")
    func worstCaseStateStaysWithinBudget() throws {
        var state = SharedState(wallet: Wallet(granted: 140, earned: 260))
        // Journal pinned at its hard cap with every field populated, plus concurrent
        // windows. This is not a realistic state — it is the ceiling the cap enforces.
        for slot in 0..<SharedState.maxJournalEntries {
            state.journal.append(SpendIntent(
                id: UUID(), bucket: BucketID(slot: slot), phase: .settled,
                createdAt: .fixture, activityName: "lumo.unlock.\(UUID().uuidString)",
                price: 45, usageBudget: 900, windowSeconds: 2700,
                tierIndex: 1, policyFingerprint: "fp-abcdef123456",
                debit: .init(granted: 30, earned: 15),
                balanceBefore: Wallet(granted: 30, earned: 20)
            ))
        }
        for slot in 0..<4 {
            state.windows.append(UnlockWindow(
                bucket: BucketID(slot: slot), startedAt: .fixture,
                endsAt: Date.fixture.addingTimeInterval(2700), usageBudget: 900,
                activityName: "lumo.unlock.\(UUID().uuidString)",
                origin: .purchased, intentID: UUID()
            ))
        }
        // Baseline calibration at its 14-day cap. Added when the ladder landed, because a new field
        // in this blob is exactly the kind of growth the guardrail exists to catch.
        for offset in 0..<20 {
            state.baseline.record(
                highestRung: 120,
                on: Date.fixture.addingTimeInterval(TimeInterval(offset * 86_400))
            )
        }
        state.emergency.record(now: .fixture)

        let size = try encoder.encode(state).count
        #expect(
            size < SharedState.encodedSizeBudget,
            "worst-case SharedState encoded to \(size)B, over the \(SharedState.encodedSizeBudget)B guardrail"
        )
    }

    @Test("A steady-state SharedState is small — this is the number that matters")
    func steadyStateIsSmall() throws {
        // What the monitor extension actually decodes on a normal callback: one live
        // window, one in-flight intent. Asserted separately from the worst case because
        // this is the size that governs real decode and lock-hold cost.
        var state = SharedState(wallet: Wallet(granted: 60, earned: 120))
        let intentID = UUID()
        state.journal = [SpendIntent(
            id: intentID, bucket: BucketID(slot: 3), phase: .settled,
            createdAt: .fixture, activityName: "lumo.unlock.\(UUID().uuidString)",
            price: 45, usageBudget: 900, windowSeconds: 2700,
            tierIndex: 1, policyFingerprint: "fp-abcdef123456"
        )]
        state.windows = [UnlockWindow(
            bucket: BucketID(slot: 3), startedAt: .fixture,
            endsAt: Date.fixture.addingTimeInterval(2700), usageBudget: 900,
            activityName: "lumo.unlock.\(UUID().uuidString)",
            origin: .purchased, intentID: intentID
        )]

        // A realistic steady state also has a streak in it, which is what the user has actually
        // been doing all week. Leaving it at .empty would measure a state no returning user is in.
        state.streak.recordCompletion(on: .fixture)

        let size = try encoder.encode(state).count
        // Raised from 1 KB to 1.5 KB when `streak` joined the blob: six fields, ~110 bytes, and
        // the alternative was a side key that could tear away from the wallet credit it belongs to.
        // The ceiling is a growth alarm, not a platform limit — the real one is 6 MB, and the
        // encoding stays verbose on purpose because a readable on-device JSON dump is frequently
        // the only diagnostic available. Anything approaching this again deserves the same argument
        // rather than another bump.
        #expect(size < 1536, "steady-state SharedState encoded to \(size)B, expected under 1.5 KB")
    }

    @Test("The journal cap is enforceable and small enough to bound the blob")
    func journalCapIsSane() {
        // A log of in-flight transactions. If this needs raising, the real question is why
        // the app is not pruning.
        #expect(SharedState.maxJournalEntries <= 8)
        #expect(SharedState.maxJournalEntries >= 2)
    }

    // MARK: - T-CODEC-07: schema gate

    @Test("Schema readability accepts current and rejects skew")
    func schemaGate() {
        #expect(SchemaVersion.isReadable(SchemaVersion.current))
        #expect(SchemaVersion.isReadable(SchemaVersion.minimumReadable))
        // A newer payload must NOT be guessed at — writing against a layout we do not
        // understand would corrupt the wallet silently.
        #expect(!SchemaVersion.isReadable(SchemaVersion.current + 1))
        #expect(!SchemaVersion.isReadable(0))
    }

    @Test("Store names are zero-padded and stable")
    func storeNaming() {
        #expect(BucketID(slot: 0).storeNameRaw == "lumo.bucket.00")
        #expect(BucketID(slot: 7).storeNameRaw == "lumo.bucket.07")
        #expect(BucketID(slot: 47).storeNameRaw == "lumo.bucket.47")
        // Distinct slots must never collide on a store name, or two buckets would share a
        // ManagedSettingsStore and unlocking one would unlock the other.
        let names = Set((0..<BucketTable.slotCapacity).map { BucketID(slot: $0).storeNameRaw })
        #expect(names.count == BucketTable.slotCapacity)
    }
}
