import Foundation

/// Executes a coin spend as a recoverable three-phase commit.
///
/// `UserDefaults` has no transactions, but a spend spans three effects across two subsystems
/// plus a durable counter. So the order is chosen so that **every crash point leaves a state
/// that is either a clean rollback or already protected by the OS**:
///
/// ```
/// T1  write intent (.intended)        no debit, no timer, still shielded
/// T2  debit wallet + arm timer        coins taken, OS holds a timer, STILL SHIELDED
/// T3  unshield + record window        user gains access
/// ```
///
/// Unshielding is deliberately LAST. The naive order — debit, unshield, then arm — has a
/// window where apps are reachable with no armed timer: unbounded free access, silent and
/// permanent, with nothing to ever close it. That is the worst failure this codebase could
/// have, and inverting two lines removes it entirely.
///
/// Crash table (each row has a test):
///
/// | dies after | coins | timer | apps      | reconcile does        |
/// |------------|-------|-------|-----------|-----------------------|
/// | T1         | intact| none  | shielded  | discards the intent   |
/// | T2         | taken | armed | shielded  | completes, unshields  |
/// | T2, late   | taken | armed | shielded  | refunds — window gone |
/// | T3         | taken | armed | open      | nothing to do         |
public struct SpendCoordinator: Sendable {

    let state: any StateStoring
    let shields: any ShieldStoring
    let scheduler: any ActivityScheduling
    let lock: any CrossProcessLocking
    let clock: any NowProviding
    let diagnostics: any Diagnosing

    public init(
        state: any StateStoring,
        shields: any ShieldStoring,
        scheduler: any ActivityScheduling,
        lock: any CrossProcessLocking,
        clock: any NowProviding = SystemNow(),
        diagnostics: any Diagnosing = NullDiagnostics()
    ) {
        self.state = state
        self.shields = shields
        self.scheduler = scheduler
        self.lock = lock
        self.clock = clock
        self.diagnostics = diagnostics
    }

    /// A priced offer. Always recomputed as a pure function of (bucket, wallet, policy) and
    /// validated by fingerprint, never carried across processes as written state — the shield
    /// submenu round-trips a *position*, not an identity, so two extensions agreeing by
    /// message would be a race that silently sells the wrong tier.
    public struct Offer: Sendable, Equatable {
        public var bucket: BucketID
        public var price: Int
        public var windowSeconds: TimeInterval
        public var usageBudgetSeconds: TimeInterval
        public var tierIndex: Int
        public var policyFingerprint: String
        public var origin: UnlockWindow.Origin

        public init(
            bucket: BucketID,
            price: Int,
            windowSeconds: TimeInterval,
            usageBudgetSeconds: TimeInterval,
            tierIndex: Int,
            policyFingerprint: String,
            origin: UnlockWindow.Origin = .purchased
        ) {
            self.bucket = bucket
            self.price = price
            self.windowSeconds = windowSeconds
            self.usageBudgetSeconds = usageBudgetSeconds
            self.tierIndex = tierIndex
            self.policyFingerprint = policyFingerprint
            self.origin = origin
        }
    }

    public enum SpendError: Error, Equatable {
        case insufficientCoins(needed: Int, available: Int)
        case unknownBucket(BucketID)
        /// The token must never be shielded, so it is already reachable and nothing is owed.
        case bucketIsEssential(BucketID)
        case alreadyOpen(BucketID)
        case lockUnavailable
        case stateUnavailable
        /// Arming failed, so no window is granted and the debit was rolled back. Never
        /// unshield in this case — an unlocked app with no timer never re-locks.
        case couldNotArm
        case safeMode
    }

    public struct Receipt: Sendable, Equatable {
        public var intentID: UUID
        public var window: UnlockWindow
        public var walletAfter: Wallet
    }

    @discardableResult
    public func spend(_ offer: Offer) throws -> Receipt {
        guard let result = lock.withLock({ () -> Result<Receipt, SpendError> in
            commit(offer)
        }) else {
            throw SpendError.lockUnavailable
        }
        return try result.get()
    }

    // MARK: - The three-phase commit

    private func commit(_ offer: Offer) -> Result<Receipt, SpendError> {
        let now = clock.now

        guard var shared = try? state.loadState(), let table = try? state.loadBuckets() else {
            return .failure(.stateUnavailable)
        }
        guard !shared.flags.contains(.safeMode) else { return .failure(.safeMode) }
        guard let bucket = table.buckets[offer.bucket] else {
            return .failure(.unknownBucket(offer.bucket))
        }
        guard !table.isEssential(bucket.token) else {
            // Charging for an app that is never shielded would be taking coins for nothing.
            return .failure(.bucketIsEssential(offer.bucket))
        }
        guard !shared.hasLiveWindow(for: offer.bucket, now: now) else {
            return .failure(.alreadyOpen(offer.bucket))
        }
        guard shared.wallet.total >= offer.price else {
            return .failure(.insufficientCoins(needed: offer.price, available: shared.wallet.total))
        }

        // ---- T1: intent. No durable effects, so a crash here costs nothing. ----
        let intentID = UUID()
        let activityName = "lumo.unlock.\(intentID.uuidString)"
        var intent = SpendIntent(
            id: intentID,
            bucket: offer.bucket,
            phase: .intended,
            createdAt: now,
            activityName: activityName,
            price: offer.price,
            usageBudget: offer.usageBudgetSeconds,
            windowSeconds: offer.windowSeconds,
            tierIndex: offer.tierIndex,
            policyFingerprint: offer.policyFingerprint,
            balanceBefore: shared.wallet,
            origin: offer.origin
        )
        shared.journal.append(intent)
        guard (try? state.saveState(shared)) != nil else { return .failure(.stateUnavailable) }

        // ---- T2: debit, then arm. Store stays SHIELDED throughout. ----
        guard let debit = shared.wallet.spend(offer.price) else {
            return .failure(.insufficientCoins(needed: offer.price, available: shared.wallet.total))
        }
        intent.debit = debit
        intent.phase = .armed
        shared.journal[shared.journal.count - 1] = intent

        do {
            try scheduler.arm(
                activityName: activityName,
                bucket: offer.bucket,
                token: bucket.token,
                kind: bucket.kind,
                wallClockSeconds: offer.windowSeconds,
                usageBudgetSeconds: offer.usageBudgetSeconds
            )
        } catch {
            // Arming failed. Refund and stop — crucially WITHOUT unshielding. Granting access
            // with no timer is the one outcome that never self-corrects.
            shared.wallet.refund(debit)
            shared.journal[shared.journal.count - 1].phase = .rolledBack
            try? state.saveState(shared)
            diagnostics.record("spend.armFailed", detail: intentID.uuidString)
            return .failure(.couldNotArm)
        }

        // Persist the armed phase before unshielding, so a crash between here and T3 is
        // recoverable by the reconciler rather than invisible.
        guard (try? state.saveState(shared)) != nil else {
            scheduler.disarm(activityName: activityName)
            return .failure(.stateUnavailable)
        }

        // ---- T3: unshield and record the window. ----
        let window = UnlockWindow(
            bucket: offer.bucket,
            startedAt: now,
            endsAt: now.addingTimeInterval(offer.windowSeconds),
            usageBudget: offer.usageBudgetSeconds,
            activityName: activityName,
            origin: offer.origin,
            intentID: intentID
        )
        shared.windows.append(window)
        shared.journal[shared.journal.count - 1].phase = .settled
        shared.mirror.shielded.remove(offer.bucket)
        shared.mirror.unshielded.insert(offer.bucket)
        shared.mirror.lastWriteAt = now

        // If this throws, the window is still recorded and the timer is armed, so the next
        // reconcile completes the unshield. Better than losing the paid window.
        try? shields.unshield(offer.bucket)

        guard (try? state.saveState(shared)) != nil else { return .failure(.stateUnavailable) }
        diagnostics.record("spend.settled", detail: intentID.uuidString)

        return .success(Receipt(
            intentID: intentID, window: window, walletAfter: shared.wallet
        ))
    }
}
