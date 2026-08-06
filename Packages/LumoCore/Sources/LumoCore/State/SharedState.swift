import Foundation

/// What we last successfully wrote to each store.
///
/// Enables delta-only writes, so a steady-state reconcile issues zero IPC calls. That
/// matters most in the shield-config extension, which sits on a latency-sensitive render
/// path and can be invoked repeatedly.
public struct ShieldMirror: Codable, Sendable, Equatable {
    public var shielded: Set<BucketID>
    public var unshielded: Set<BucketID>
    public var lastWriteAt: Date?

    public init(
        shielded: Set<BucketID> = [],
        unshielded: Set<BucketID> = [],
        lastWriteAt: Date? = nil
    ) {
        self.shielded = shielded
        self.unshielded = unshielded
        self.lastWriteAt = lastWriteAt
    }

    public static let empty = ShieldMirror()

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shielded = try c.decodeIfPresent(Set<BucketID>.self, forKey: .shielded) ?? []
        unshielded = try c.decodeIfPresent(Set<BucketID>.self, forKey: .unshielded) ?? []
        lastWriteAt = try c.decodeIfPresent(Date.self, forKey: .lastWriteAt)
    }
}

public struct Flags: OptionSet, Codable, Sendable, Equatable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Something is untrustworthy: shield everything, refuse to write, tell the user.
    public static let safeMode = Flags(rawValue: 1 << 0)
    public static let needsMigration = Flags(rawValue: 1 << 1)
    /// A token no longer resolves — iOS reissued it. Triggers repair.
    public static let tokenDriftDetected = Flags(rawValue: 1 << 2)
    public static let authorizationLost = Flags(rawValue: 1 << 3)
    /// Tripwire for the threshold-fires-immediately regression. Set when a usage event
    /// arrives implausibly early; makes the bug visible instead of silently costing coins.
    public static let thresholdUntrusted = Flags(rawValue: 1 << 4)
    /// Approaching the 20-activity cap, past which `startMonitoring` throws.
    public static let activityBudgetFull = Flags(rawValue: 1 << 5)

    // Encoded as a bare integer rather than {"rawValue": n}, so the raw JSON dump stays
    // compact and readable on device.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        rawValue = try c.decode(Int.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

/// Which process last touched the state. Diagnostic only — never branched on for logic.
public enum ProcessTag: String, Codable, Sendable {
    case app
    case monitor
    case shieldAction
    case shieldConfig
}

/// The hot, contended cross-process state.
///
/// Deliberately ONE Codable blob under ONE key. `UserDefaults` is atomic per *value*, not
/// across values, so a state spread over several keys is torn-read-able and
/// torn-write-able by construction. One blob makes every transition a single atomic write.
///
/// Kept under ~4 KB because the DeviceActivityMonitor extension decodes it against a 6 MB
/// ceiling. Bucket tokens live in a separate key precisely so a spend never re-serialises
/// 20 KB of tokens while holding the lock.
public struct SharedState: Codable, Sendable, Equatable {
    public var version: Int
    public var wallet: Wallet
    public var week: WeekLedger
    public var windows: [UnlockWindow]

    /// The spend write-ahead log. Bounded; only the app prunes.
    public var journal: [SpendIntent]

    public var mirror: ShieldMirror

    /// Emergency-unlock usage. Counted to escalate friction and feed harm telemetry, never to
    /// deny access.
    public var emergency: EmergencyLog

    public var flags: Flags
    public var lastReconcileAt: Date?
    public var lastReconcileBy: ProcessTag?

    /// Written by the shield-action extension on the pre-26.4 path, consumed by the app.
    ///
    /// Needed because on iOS 18.0–26.4 there is no supported way to open the containing app
    /// from a shield action, so the extension records the request and a local notification
    /// carries the user across.
    public var pendingSpendRequest: PendingSpendRequest?

    public struct PendingSpendRequest: Codable, Sendable, Equatable {
        public var bucket: BucketID
        public var requestedAt: Date
        /// `nil` means the user pressed the plain secondary button rather than a submenu tier.
        public var tierIndex: Int?

        public init(bucket: BucketID, requestedAt: Date, tierIndex: Int? = nil) {
            self.bucket = bucket
            self.requestedAt = requestedAt
            self.tierIndex = tierIndex
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            bucket = try c.decodeIfPresent(BucketID.self, forKey: .bucket) ?? BucketID(slot: 0)
            requestedAt = try c.decodeIfPresent(Date.self, forKey: .requestedAt) ?? Date(timeIntervalSince1970: 0)
            tierIndex = try c.decodeIfPresent(Int.self, forKey: .tierIndex)
        }
    }

    /// Hard cap on journal entries.
    ///
    /// Lowered from the spec's 16 after measuring: 16 fully-populated intents encode to
    /// ~7.5 KB on their own. This is a runaway guard, not a working size — the journal is a
    /// log of *in-flight* spends, so the realistic depth is 0 or 1, and entries only linger
    /// until the app ingests them into the durable ledger. Eight would already mean eight
    /// un-ingested spends between two app launches.
    public static let maxJournalEntries = 8

    /// Self-imposed size guardrail for the encoded blob.
    ///
    /// NOT a platform limit — the real constraint is the monitor extension's 6 MB process
    /// high-watermark, which single-digit KB is nowhere near. What this actually defends
    /// against is unbounded growth: the blob is decoded on every extension callback and
    /// rewritten under a cross-process lock, so it has to stay bounded by construction
    /// rather than by hope.
    ///
    /// Deliberately traded against readability: the encoding stays verbose and
    /// human-readable because dumping raw `lumo.*` JSON on device is often the only
    /// diagnostic available, given Family Controls cannot run in the Simulator.
    public static let encodedSizeBudget = 8 * 1024

    public init(
        version: Int = SchemaVersion.current,
        wallet: Wallet = .zero,
        week: WeekLedger = .empty,
        windows: [UnlockWindow] = [],
        journal: [SpendIntent] = [],
        mirror: ShieldMirror = .empty,
        emergency: EmergencyLog = .empty,
        flags: Flags = [],
        lastReconcileAt: Date? = nil,
        lastReconcileBy: ProcessTag? = nil,
        pendingSpendRequest: PendingSpendRequest? = nil
    ) {
        self.version = version
        self.wallet = wallet
        self.week = week
        self.windows = windows
        self.journal = journal
        self.mirror = mirror
        self.emergency = emergency
        self.flags = flags
        self.lastReconcileAt = lastReconcileAt
        self.lastReconcileBy = lastReconcileBy
        self.pendingSpendRequest = pendingSpendRequest
    }

    public static let initial = SharedState()

    // Hand-written so that EVERY field decodes from absence.
    //
    // Synthesised Codable throws on a missing key. A throw here means SafeMode, and
    // SafeMode means every app the user owns is shielded — so a decode failure is a
    // product outage. During an OS-triggered extension launch we control neither ordering
    // nor timing, so this has to be tolerant by construction.
    //
    // Review rule: adding a stored property to any lumo.* payload without a
    // decodeIfPresent default is a rejected PR.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? SchemaVersion.current
        wallet = try c.decodeIfPresent(Wallet.self, forKey: .wallet) ?? .zero
        week = try c.decodeIfPresent(WeekLedger.self, forKey: .week) ?? .empty
        windows = try c.decodeIfPresent([UnlockWindow].self, forKey: .windows) ?? []
        journal = try c.decodeIfPresent([SpendIntent].self, forKey: .journal) ?? []
        mirror = try c.decodeIfPresent(ShieldMirror.self, forKey: .mirror) ?? .empty
        emergency = try c.decodeIfPresent(EmergencyLog.self, forKey: .emergency) ?? .empty
        flags = try c.decodeIfPresent(Flags.self, forKey: .flags) ?? []
        lastReconcileAt = try c.decodeIfPresent(Date.self, forKey: .lastReconcileAt)
        lastReconcileBy = try c.decodeIfPresent(ProcessTag.self, forKey: .lastReconcileBy)
        pendingSpendRequest = try c.decodeIfPresent(PendingSpendRequest.self, forKey: .pendingSpendRequest)
    }
}

// MARK: - Queries

extension SharedState {

    /// The live window for a bucket, if any.
    ///
    /// Delegates to `UnlockWindow.isLive` so liveness has exactly one definition — see the
    /// note there about the two paths that previously disagreed.
    public func liveWindow(for bucket: BucketID, now: Date) -> UnlockWindow? {
        windows.first { $0.bucket == bucket && $0.isLive(now: now) }
    }

    public func hasLiveWindow(for bucket: BucketID, now: Date) -> Bool {
        liveWindow(for: bucket, now: now) != nil
    }

    /// Buckets that should currently be open.
    public func openBuckets(now: Date) -> Set<BucketID> {
        Set(windows.filter { $0.isLive(now: now) }.map(\.bucket))
    }

    /// Journal entries that still need work — either finishing or rolling back.
    public var unsettledIntents: [SpendIntent] {
        journal.filter { $0.phase == .intended || $0.phase == .armed }
    }
}
