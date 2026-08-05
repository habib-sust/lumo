import Foundation

/// Drives every shield store to the state the persisted session implies.
///
/// Called from all four processes: the app on foreground, the monitor extension on every
/// DeviceActivity callback, and the shield-action extension after a spend. It is
/// **synchronous and idempotent**, and both properties are load-bearing:
///
/// * Synchronous, because on the app's foreground path an `await` is a suspension point the
///   user can exploit by backgrounding mid-reconcile, leaving shields half-applied.
/// * Idempotent, because callbacks arrive spuriously. `startMonitoring` on an existing name
///   fires a phantom `intervalDidEnd`, thresholds fire at +0 seconds, and deliveries
///   duplicate. Recomputing from persisted state plus `now` makes all of that harmless.
///
/// **Callbacks are triggers, never data.** Nothing here branches on which activity or event
/// arrived. That is the design rule that turns a pile of unreliable OS callbacks into
/// something with a single, testable meaning.
public struct ShieldReconciler: Sendable {

    /// Re-exported for callers and tests. The definition lives on `UnlockWindow`, next to
    /// the liveness rule that uses it, so the floor cannot drift between the two.
    public static var thresholdHonorFloor: TimeInterval { UnlockWindow.thresholdHonorFloor }

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

    public struct Outcome: Equatable, Sendable {
        public var shielded: Set<BucketID> = []
        public var unshielded: Set<BucketID> = []
        public var destroyed: Set<BucketID> = []
        public var expiredWindows: Int = 0
        public var rolledBackIntents: Int = 0
        public var completedIntents: Int = 0
        public var disarmedActivities: Int = 0
        public var enteredSafeMode = false
        public var skippedForLock = false

        /// True when nothing at all had to change — the steady state, and the case that must
        /// issue zero IPC calls.
        public var isNoOp: Bool {
            shielded.isEmpty && unshielded.isEmpty && destroyed.isEmpty
                && expiredWindows == 0 && rolledBackIntents == 0 && completedIntents == 0
                && disarmedActivities == 0
        }
    }

    @discardableResult
    public func reconcile(by process: ProcessTag) -> Outcome {
        // Contention must never stall a caller. The shield-render path in particular has to
        // return promptly or the system substitutes Apple's generic grey shield.
        guard let outcome = lock.withLock({ perform(by: process) }) else {
            diagnostics.record("reconcile.skipped", detail: "lock contended")
            var out = Outcome()
            out.skippedForLock = true
            return out
        }
        return outcome
    }

    // MARK: - The body

    private func perform(by process: ProcessTag) -> Outcome {
        var out = Outcome()
        let now = clock.now

        // Schema gate FIRST. Operating on a layout we do not understand would corrupt the
        // wallet silently, which is worse than refusing to run.
        let version = state.loadSchemaVersion() ?? SchemaVersion.current
        guard SchemaVersion.isReadable(version) else {
            diagnostics.record("reconcile.safeMode", detail: "schema \(version)")
            out.enteredSafeMode = true
            shieldEverything(reason: "schema \(version)", into: &out)
            return out
        }

        guard var shared = try? state.loadState(), let table = try? state.loadBuckets() else {
            // A decode failure is a product outage, not a bug report: refusing to guess and
            // shielding everything is the safe direction, and the wallet is rebuilt from the
            // durable ledger on the next app launch rather than zeroed.
            diagnostics.record("reconcile.safeMode", detail: "state unreadable")
            out.enteredSafeMode = true
            shieldEverything(reason: "state unreadable", into: &out)
            return out
        }

        if shared.flags.contains(.safeMode) {
            out.enteredSafeMode = true
            shieldEverything(reason: "safeMode flag", into: &out)
            return out
        }

        // Captured so a reconcile that only raises a diagnostic flag still persists it.
        // Without this, a phantom-threshold sighting set `.thresholdUntrusted` in memory and
        // then dropped it on the floor, because the pass was otherwise a no-op — the exact
        // bug is invisible in the debug panel, which is the one place we would look for it.
        let flagsBefore = shared.flags

        resolveJournal(&shared, now: now, out: &out)
        expireWindows(&shared, now: now, out: &out)
        applyShieldDeltas(&shared, table: table, now: now, out: &out)
        collectActivities(&shared, out: &out)

        shared.lastReconcileAt = now
        shared.lastReconcileBy = process
        // Only persist when something actually changed, so a steady-state reconcile is a
        // pure read. The monitor extension runs this on every callback under a 6 MB ceiling.
        if !out.isNoOp || shared.flags != flagsBefore {
            try? state.saveState(shared)
        }
        return out
    }

    // MARK: - Journal

    /// Finishes or undoes anything a dying process left half-done.
    ///
    /// The commit order (debit -> arm -> unshield) is what makes this decidable: an `armed`
    /// intent means the OS already holds a timer and the user has NOT yet gained access, so
    /// completing it is both safe and fair. An `intended` intent has no durable effects at
    /// all, so it is free to discard.
    private func resolveJournal(_ shared: inout SharedState, now: Date, out: inout Outcome) {
        for index in shared.journal.indices {
            switch shared.journal[index].phase {
            case .intended:
                // Nothing durable happened. Discard rather than guess at intent.
                shared.journal[index].phase = .rolledBack
                out.rolledBackIntents += 1
                diagnostics.record("intent.rolledBack", detail: shared.journal[index].id.uuidString)

            case .armed:
                let intent = shared.journal[index]
                let elapsed = now.timeIntervalSince(intent.createdAt)
                if elapsed > intent.windowSeconds {
                    // The paid window elapsed while we were dead. Refund rather than grant a
                    // window the user cannot use — they never got access.
                    shared.wallet.refund(intent.debit)
                    scheduler.disarm(activityName: intent.activityName)
                    shared.journal[index].phase = .rolledBack
                    out.rolledBackIntents += 1
                    diagnostics.record("intent.refunded", detail: intent.id.uuidString)
                } else if !shared.windows.contains(where: { $0.intentID == intent.id }) {
                    // Timer armed, coins taken, but the window was never recorded. Finish the
                    // transaction — the unshield itself happens in the delta pass below.
                    shared.windows.append(UnlockWindow(
                        bucket: intent.bucket,
                        startedAt: intent.createdAt,
                        endsAt: intent.createdAt.addingTimeInterval(intent.windowSeconds),
                        usageBudget: intent.usageBudget,
                        activityName: intent.activityName,
                        origin: intent.origin,
                        intentID: intent.id
                    ))
                    shared.journal[index].phase = .settled
                    out.completedIntents += 1
                    diagnostics.record("intent.completed", detail: intent.id.uuidString)
                }

            case .settled, .rolledBack:
                break
            }
        }

        // Trim only what the app has already written to the durable ledger. Pruning on settle
        // would destroy the only record of an extension-side spend and leave the wallet
        // unreconcilable.
        if shared.journal.count > SharedState.maxJournalEntries {
            let prunable = shared.journal.filter {
                ($0.phase == .settled || $0.phase == .rolledBack) && $0.ingestedIntoLedger
            }
            let dropCount = shared.journal.count - SharedState.maxJournalEntries
            let toDrop = Set(prunable.prefix(dropCount).map(\.id))
            shared.journal.removeAll { toDrop.contains($0.id) }
        }
    }

    // MARK: - Windows

    private func expireWindows(_ shared: inout SharedState, now: Date, out: inout Outcome) {
        let before = shared.windows.count
        shared.windows.removeAll { !$0.isLive(now: now) }
        out.expiredWindows = before - shared.windows.count

        // A window that claims exhaustion implausibly early is the known iOS regression, not
        // a real signal. Flag it so it is visible in the debug panel rather than mysterious.
        for window in shared.windows where window.hasPhantomThreshold(now: now) {
            shared.flags.insert(.thresholdUntrusted)
            diagnostics.record(
                "threshold.phantom",
                detail: "bucket \(window.bucket.slot) at \(Int(now.timeIntervalSince(window.startedAt)))s"
            )
        }
    }

    // MARK: - Shield deltas

    /// Writes only what changed, so the steady state costs zero IPC calls.
    private func applyShieldDeltas(
        _ shared: inout SharedState,
        table: BucketTable,
        now: Date,
        out: inout Outcome
    ) {
        // `shieldableBuckets` already excludes the essential deny-set. Enforcing it here as
        // well as in the picker is deliberate: this is the layer that actually writes, so a
        // token cannot become shielded by any route.
        let shieldable = table.shieldableBuckets
        let open = shared.openBuckets(now: now)
        let desiredShielded = Set(shieldable.keys).subtracting(open)

        var believedShielded = shared.mirror.shielded

        // Buckets that no longer exist, or became essential: tear their stores down. Skipping
        // this would leave an app shielded with no UI showing it — an unreachable shield the
        // user cannot pay to remove.
        let orphans = believedShielded.union(shared.mirror.unshielded)
            .subtracting(shieldable.keys)
        for bucket in orphans.sorted() {
            if (try? shields.destroy(bucket)) != nil {
                out.destroyed.insert(bucket)
                believedShielded.remove(bucket)
            }
        }

        for bucket in desiredShielded.subtracting(believedShielded).sorted() {
            guard let entry = shieldable[bucket] else { continue }
            if (try? shields.shield(bucket, token: entry.token, kind: entry.kind)) != nil {
                out.shielded.insert(bucket)
                believedShielded.insert(bucket)
            }
        }

        for bucket in believedShielded.subtracting(desiredShielded).sorted() {
            if (try? shields.unshield(bucket)) != nil {
                out.unshielded.insert(bucket)
                believedShielded.remove(bucket)
            }
        }

        shared.mirror.shielded = believedShielded
        shared.mirror.unshielded = Set(shieldable.keys).subtracting(believedShielded)
        if !out.shielded.isEmpty || !out.unshielded.isEmpty || !out.destroyed.isEmpty {
            shared.mirror.lastWriteAt = now
        }
    }

    // MARK: - Activity GC

    /// Releases activities that no live window needs, against the 20-activity cap.
    private func collectActivities(_ shared: inout SharedState, out: inout Outcome) {
        let needed = Set(shared.windows.map(\.activityName))
        let armedButUnneeded = scheduler.activeActivityNames().subtracting(needed)
        for name in armedButUnneeded.sorted() {
            scheduler.disarm(activityName: name)
            out.disarmedActivities += 1
        }
        if needed.count >= 12 {
            shared.flags.insert(.activityBudgetFull)
        } else {
            shared.flags.remove(.activityBudgetFull)
        }
    }

    // MARK: - SafeMode

    /// Shields everything we know about and writes nothing.
    ///
    /// Shielding is the safe direction: over-shielding is annoying and visible, whereas
    /// under-shielding is a silent failure of the product's only promise. The wallet is never
    /// zeroed here — it is rebuilt from the durable ledger on the next app launch.
    private func shieldEverything(reason: String, into out: inout Outcome) {
        guard let table = try? state.loadBuckets() else { return }
        for (id, bucket) in table.shieldableBuckets.sorted(by: { $0.key < $1.key }) {
            if (try? shields.shield(id, token: bucket.token, kind: bucket.kind)) != nil {
                out.shielded.insert(id)
            }
        }
    }
}

// MARK: - Read-only observation

extension ShieldReconciler {

    /// What the shield-config extension uses.
    ///
    /// Deliberately cannot write: it holds no `ShieldStoring`, so "render-time reconcile"
    /// cannot accidentally mutate shield state from inside the "what should I render?"
    /// callback — which would invite re-entrant invalidation on a latency-sensitive path.
    public struct Observation: Sendable, Equatable {
        public var wallet: Wallet
        public var openBuckets: Set<BucketID>
        public var isSafeMode: Bool
    }

    public static func observe(
        state: any StateStoring,
        clock: any NowProviding = SystemNow()
    ) -> Observation {
        guard let shared = try? state.loadState() else {
            return Observation(wallet: .zero, openBuckets: [], isSafeMode: true)
        }
        return Observation(
            wallet: shared.wallet,
            openBuckets: shared.openBuckets(now: clock.now),
            isSafeMode: shared.flags.contains(.safeMode)
        )
    }
}
