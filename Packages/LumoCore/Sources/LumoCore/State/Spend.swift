import Foundation

/// A live unlock window.
public struct UnlockWindow: Codable, Sendable, Equatable {
    public var bucket: BucketID
    public var startedAt: Date

    /// Wall-clock expiry. This is the PRIMARY expiry mechanism.
    ///
    /// It is primary — rather than the usage threshold, which would be the better product —
    /// because `eventDidReachThreshold` is reported still firing at +0 seconds on iOS
    /// 26.5.2 even with `includesPastActivity: false`. If usage were primary, a user could
    /// pay 45 coins and have the window shut instantly.
    public var endsAt: Date

    /// Advisory only. Honoured for early close, but never before `thresholdHonorFloor`.
    public var usageBudget: TimeInterval

    public var usageExhausted: Bool

    /// A fresh UUID-derived name per session.
    ///
    /// Reusing a `DeviceActivityName` is a trap: calling `startMonitoring` on a name that
    /// is already monitored fires a spurious `intervalDidEnd`, which would re-shield the
    /// window the user just paid for.
    public var activityName: String

    public var origin: Origin
    public var intentID: UUID

    public enum Origin: String, Codable, Sendable {
        case purchased
        /// Always available, behind friction, never rate-limited. Never breaks a streak and
        /// never touches earned coins.
        case emergency
    }

    public init(
        bucket: BucketID,
        startedAt: Date,
        endsAt: Date,
        usageBudget: TimeInterval,
        usageExhausted: Bool = false,
        activityName: String,
        origin: Origin,
        intentID: UUID
    ) {
        self.bucket = bucket
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.usageBudget = usageBudget
        self.usageExhausted = usageExhausted
        self.activityName = activityName
        self.origin = origin
        self.intentID = intentID
    }

    /// A usage-exhausted signal is ignored until the window has been live this long.
    ///
    /// `eventDidReachThreshold` is reported firing at +0 seconds on current iOS even with
    /// `includesPastActivity: false`, so without a floor a user pays and the window shuts
    /// instantly.
    public static let thresholdHonorFloor: TimeInterval = 120

    /// The single definition of "is this window still open".
    ///
    /// It lives here, on the window, because it was previously duplicated: the reconciler's
    /// expiry pass applied the sanity floor while `openBuckets` treated `usageExhausted` as
    /// immediately closing. The floor therefore stopped the window being *deleted* but the
    /// shield-delta pass re-shielded it anyway — the phantom threshold still stole the paid
    /// window. Two code paths, one rule: keep it that way.
    public func isLive(now: Date) -> Bool {
        guard endsAt > now else { return false }
        if usageExhausted, now.timeIntervalSince(startedAt) >= Self.thresholdHonorFloor {
            return false
        }
        return true
    }

    /// True when exhaustion was reported implausibly early — the known iOS regression rather
    /// than a real signal.
    public func hasPhantomThreshold(now: Date) -> Bool {
        usageExhausted && now.timeIntervalSince(startedAt) < Self.thresholdHonorFloor
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bucket = try c.decodeIfPresent(BucketID.self, forKey: .bucket) ?? BucketID(slot: 0)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date(timeIntervalSince1970: 0)
        endsAt = try c.decodeIfPresent(Date.self, forKey: .endsAt) ?? Date(timeIntervalSince1970: 0)
        usageBudget = try c.decodeIfPresent(TimeInterval.self, forKey: .usageBudget) ?? 0
        usageExhausted = try c.decodeIfPresent(Bool.self, forKey: .usageExhausted) ?? false
        activityName = try c.decodeIfPresent(String.self, forKey: .activityName) ?? ""
        origin = try c.decodeIfPresent(Origin.self, forKey: .origin) ?? .purchased
        intentID = try c.decodeIfPresent(UUID.self, forKey: .intentID) ?? UUID()
    }
}

/// Where a spend has got to. The ordering of these cases is the safety argument.
///
/// The commit order is `debit -> arm monitoring -> unshield`, deliberately NOT
/// `debit -> unshield -> arm`. Unshielding last means that by the time apps are reachable,
/// the OS already holds a timer guaranteeing they will be re-shielded. Every crash point
/// is then either a clean rollback or a state the OS is already protecting.
///
/// The alternative ordering has a window where apps are open with no armed timer — i.e.
/// unbounded free access, silently and permanently. That is the worst failure this
/// codebase could have.
public enum SpendPhase: String, Codable, Sendable {
    /// Journal written. No effects yet, no durable debit. Rollback is free.
    case intended
    /// Debit is durable and DeviceActivity is armed. Store is still SHIELDED — safe to
    /// crash here, because the timer exists and the user has not gained access.
    case armed
    /// Store unshielded, window live.
    case settled
    /// Fully undone. Retained until the app ingests it into the durable ledger.
    case rolledBack
}

/// The write-ahead record for one spend.
///
/// `UserDefaults` has no transactions but a spend spans three effects, so this journal is
/// what makes the sequence recoverable. It is also the only durable record of a spend made
/// inside an extension, which is why only the app may prune it: pruning on settle would
/// destroy the audit trail and leave the wallet unreconcilable.
public struct SpendIntent: Codable, Sendable, Equatable {
    public var id: UUID
    public var bucket: BucketID
    public var phase: SpendPhase
    public var createdAt: Date
    public var activityName: String

    // The offer, captured so that rollback and ledger ingestion are exact rather than
    // recomputed against a policy that may have changed in the meantime.
    public var price: Int
    public var usageBudget: TimeInterval
    public var windowSeconds: TimeInterval

    /// The submenu position this came from, `0..<3`.
    ///
    /// The shield submenu round-trips a *position*, not an identity — the response arrives
    /// as `.firstSecondarySubmenuItemPressed` and friends. Two extensions must therefore
    /// agree on ordering, which is why the tier ladder is a pure function of
    /// (bucket, wallet, policy) validated against `policyFingerprint` rather than a written
    /// handshake between processes.
    public var tierIndex: Int

    public var policyFingerprint: String

    /// Recorded when the debit becomes durable, so a refund restores the exact
    /// granted/earned shape instead of collapsing it into one pot.
    public var debit: Wallet.Debit

    public var balanceBefore: Wallet

    /// Set only by the app, after writing the durable ledger row. Gates pruning.
    public var ingestedIntoLedger: Bool

    public var origin: UnlockWindow.Origin

    public init(
        id: UUID,
        bucket: BucketID,
        phase: SpendPhase,
        createdAt: Date,
        activityName: String,
        price: Int,
        usageBudget: TimeInterval,
        windowSeconds: TimeInterval,
        tierIndex: Int,
        policyFingerprint: String,
        debit: Wallet.Debit = .none,
        balanceBefore: Wallet = .zero,
        ingestedIntoLedger: Bool = false,
        origin: UnlockWindow.Origin = .purchased
    ) {
        self.id = id
        self.bucket = bucket
        self.phase = phase
        self.createdAt = createdAt
        self.activityName = activityName
        self.price = price
        self.usageBudget = usageBudget
        self.windowSeconds = windowSeconds
        self.tierIndex = tierIndex
        self.policyFingerprint = policyFingerprint
        self.debit = debit
        self.balanceBefore = balanceBefore
        self.ingestedIntoLedger = ingestedIntoLedger
        self.origin = origin
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        bucket = try c.decodeIfPresent(BucketID.self, forKey: .bucket) ?? BucketID(slot: 0)
        phase = try c.decodeIfPresent(SpendPhase.self, forKey: .phase) ?? .intended
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
        activityName = try c.decodeIfPresent(String.self, forKey: .activityName) ?? ""
        price = try c.decodeIfPresent(Int.self, forKey: .price) ?? 0
        usageBudget = try c.decodeIfPresent(TimeInterval.self, forKey: .usageBudget) ?? 0
        windowSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .windowSeconds) ?? 0
        tierIndex = try c.decodeIfPresent(Int.self, forKey: .tierIndex) ?? 0
        policyFingerprint = try c.decodeIfPresent(String.self, forKey: .policyFingerprint) ?? ""
        debit = try c.decodeIfPresent(Wallet.Debit.self, forKey: .debit) ?? .none
        balanceBefore = try c.decodeIfPresent(Wallet.self, forKey: .balanceBefore) ?? .zero
        ingestedIntoLedger = try c.decodeIfPresent(Bool.self, forKey: .ingestedIntoLedger) ?? false
        origin = try c.decodeIfPresent(UnlockWindow.Origin.self, forKey: .origin) ?? .purchased
    }
}
