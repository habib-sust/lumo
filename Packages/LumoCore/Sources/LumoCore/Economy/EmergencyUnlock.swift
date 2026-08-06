import Foundation

/// Grants the free, always-available unlock, and tears everything down on request.
///
/// Both operations exist because of the same P0 rule: **never trap the user.** Competitor reviews
/// include *"impossible to delete: the app hides the delete button"* and *"one of the most
/// dangerous applications I have ever installed."* An escape hatch that works is an ethical
/// requirement, a review-score requirement, and an App Review requirement at once.
public struct EmergencyUnlock: Sendable {

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

    /// How long the user must wait before the unlock button becomes active.
    ///
    /// Read before showing the screen so the countdown is honest, and never used to refuse.
    public func requiredDelaySeconds(policy: FrictionPolicy = .default) -> Int {
        guard let shared = try? state.loadState() else {
            // If state is unreadable we still grant access — erring toward the user, because the
            // alternative is stranding someone whose data happens to be corrupt.
            return policy.delaySeconds(priorUsesToday: 0)
        }
        return policy.delaySeconds(priorUsesToday: shared.emergency.uses(on: clock.now))
    }

    public enum EmergencyError: Error, Equatable {
        case unknownBucket(BucketID)
        case stateUnavailable
        case lockUnavailable
    }

    /// Grants a free window.
    ///
    /// Deliberately different from a paid spend in four ways, each one a decision rather than an
    /// omission:
    ///   * costs zero coins, and `earned` is never touched
    ///   * never breaks or pauses a streak
    ///   * is never rate-limited
    ///   * still arms a timer, so the window closes on its own
    ///
    /// The last point matters: "free" must not mean "unbounded". Access with no armed timer never
    /// re-locks.
    @discardableResult
    public func grant(
        bucket: BucketID,
        policy: FrictionPolicy = .default
    ) throws -> UnlockWindow {
        guard let window = lock.withLock({ () -> Result<UnlockWindow, EmergencyError> in
            performGrant(bucket: bucket, policy: policy)
        }) else {
            throw EmergencyError.lockUnavailable
        }
        return try window.get()
    }

    private func performGrant(
        bucket: BucketID,
        policy: FrictionPolicy
    ) -> Result<UnlockWindow, EmergencyError> {
        let now = clock.now
        guard var shared = try? state.loadState(), let table = try? state.loadBuckets() else {
            return .failure(.stateUnavailable)
        }
        guard let entry = table.buckets[bucket] else {
            return .failure(.unknownBucket(bucket))
        }

        let activityName = "lumo.unlock.\(UUID().uuidString)"
        let seconds = TimeInterval(policy.windowMinutes * 60)

        // Arm BEFORE unshielding, exactly as a paid spend does. Free does not mean unmetered.
        try? scheduler.arm(
            activityName: activityName,
            bucket: bucket,
            token: entry.token,
            kind: entry.kind,
            wallClockSeconds: seconds,
            usageBudgetSeconds: nil
        )

        let window = UnlockWindow(
            bucket: bucket,
            startedAt: now,
            endsAt: now.addingTimeInterval(seconds),
            usageBudget: seconds,
            activityName: activityName,
            origin: .emergency,
            intentID: UUID()
        )
        shared.windows.append(window)
        shared.emergency.record(now: now)
        shared.mirror.shielded.remove(bucket)
        shared.mirror.unshielded.insert(bucket)

        try? shields.unshield(bucket)
        guard (try? state.saveState(shared)) != nil else { return .failure(.stateUnavailable) }

        // Recorded as a first-class harm metric, not an engagement one. Heavy reliance here means
        // the strictness tier is wrong for this user — which is a signal to act on, not to hide.
        diagnostics.record(
            "emergency.granted",
            detail: "bucket \(bucket.slot) uses today \(shared.emergency.usesToday)"
        )
        return .success(window)
    }

    /// Unlocks everything and forgets every shield.
    ///
    /// Must always succeed and must **never** require a Screen Time passcode the user may not
    /// have. Deliberately does not clear the wallet or history: someone stepping away should be
    /// able to come back to their coins and streak intact.
    @discardableResult
    public func unlockEverything() -> Int {
        let released = lock.withLock { () -> Int in
            var count = 0
            if let table = try? state.loadBuckets() {
                for id in table.buckets.keys.sorted() {
                    if (try? shields.destroy(id)) != nil { count += 1 }
                }
            }
            // Stop every timer we own, so nothing re-shields after the user has walked away.
            for name in scheduler.activeActivityNames() {
                scheduler.disarm(activityName: name)
            }
            if var shared = try? state.loadState() {
                shared.windows = []
                shared.mirror = .empty
                shared.journal = shared.journal.filter { $0.phase == .settled }
                try? state.saveState(shared)
            }
            diagnostics.record("teardown.unlockedEverything", detail: "\(count) bucket(s)")
            return count
        }
        // Even if the lock is contended, the user asked to be released — so fall through to an
        // unlocked-anyway path rather than leaving them shielded.
        return released ?? forceRelease()
    }

    /// Last-resort release used when the lock cannot be taken.
    ///
    /// Skipping mutual exclusion is normally unacceptable, but the failure modes are asymmetric:
    /// a racy teardown might redundantly clear a store, whereas refusing to release leaves someone
    /// locked out of their own phone.
    private func forceRelease() -> Int {
        var count = 0
        if let table = try? state.loadBuckets() {
            for id in table.buckets.keys.sorted() {
                if (try? shields.destroy(id)) != nil { count += 1 }
            }
        }
        diagnostics.record("teardown.forced", detail: "lock unavailable, released \(count)")
        return count
    }
}
