import Foundation

/// Assigns tokens to stable bucket slots.
///
/// One token per bucket, one bucket per named `ManagedSettingsStore`. Multi-app buckets
/// would over-deliver — pay for TikTok, get Instagram free — pushing the effective price
/// below the user's baseline ratio, which is where the contingency stops reinforcing and
/// starts *suppressing* the habit it exists to build.
///
/// Slots are the identity, never the token bytes. iOS reissues tokens unpredictably, so a
/// token that changes value keeps its slot and no shield ever migrates between stores. That
/// makes the stale-shield variant of the rotation bug structurally impossible rather than
/// merely handled.
public enum BucketPartitioner {

    /// Application slots. Capped at 40 rather than iOS's 50 because the platform fails
    /// **silently and totally** at 51 shielded tokens — `MonitoringError` has no
    /// token-count case, so there is nothing to catch. The headroom also keeps us under the
    /// 50-named-store limit.
    public static let applicationSlots = 0..<BucketTable.defaultMaxApplicationTokens

    /// Category slots, above the application range so the two never collide.
    public static var categorySlots: Range<Int> {
        BucketTable.defaultMaxApplicationTokens..<BucketTable.slotCapacity
    }

    public static func slotRange(for kind: BucketKind) -> Range<Int> {
        switch kind {
        case .application: applicationSlots
        case .category: categorySlots
        }
    }

    public struct Outcome: Equatable, Sendable {
        public var table: BucketTable
        /// Slots newly assigned by this commit.
        public var added: Set<BucketID>
        /// Slots freed by this commit — their stores must be cleared, not just forgotten.
        public var removed: Set<BucketID>
        /// Slots that kept their token and their number.
        public var retained: Set<BucketID>
        /// Tokens dropped because they are essential. Not an error: silently refusing to
        /// shield a medical app is the correct behaviour, and the UI can explain it.
        public var refusedAsEssential: Set<TokenBlob>
    }

    public enum CommitError: Error, Equatable {
        /// The whole commit is rejected. Never truncate: silently shielding 40 of a user's
        /// 45 chosen apps looks like a bug that ate their settings, and the platform gives
        /// no error at 51 to fall back on.
        case tooManyApplications(requested: Int, cap: Int, overflow: Set<TokenBlob>)
        case tooManyCategories(requested: Int, cap: Int, overflow: Set<TokenBlob>)
    }

    /// Reconciles a picker selection into slot assignments.
    ///
    /// All-or-nothing: on overflow the existing table is left untouched and the offending
    /// tokens are named, so the UI can say which apps did not fit.
    public static func commit(
        applications: Set<TokenBlob>,
        categories: Set<TokenBlob>,
        into table: BucketTable,
        now: Date
    ) throws -> Outcome {
        let essential = table.essential

        // Essential tokens are subtracted before anything else, so no later step can
        // reintroduce them.
        let refused = applications.intersection(essential).union(categories.intersection(essential))
        let wantedApps = applications.subtracting(essential)
        let wantedCategories = categories.subtracting(essential)

        if wantedApps.count > table.maxApplicationTokens {
            throw CommitError.tooManyApplications(
                requested: wantedApps.count,
                cap: table.maxApplicationTokens,
                overflow: overflowSample(wantedApps, keeping: table.maxApplicationTokens)
            )
        }
        if wantedCategories.count > table.maxCategoryTokens {
            throw CommitError.tooManyCategories(
                requested: wantedCategories.count,
                cap: table.maxCategoryTokens,
                overflow: overflowSample(wantedCategories, keeping: table.maxCategoryTokens)
            )
        }

        var next = table
        var added: Set<BucketID> = []
        var removed: Set<BucketID> = []
        var retained: Set<BucketID> = []

        for kind in [BucketKind.application, .category] {
            let wanted = kind == .application ? wantedApps : wantedCategories
            let existing = next.buckets.filter { $0.value.kind == kind }

            // Retain slots whose token is still wanted — this is what makes slots stable.
            var keptTokens: Set<TokenBlob> = []
            for (id, bucket) in existing {
                if wanted.contains(bucket.token) {
                    retained.insert(id)
                    keptTokens.insert(bucket.token)
                } else {
                    next.buckets.removeValue(forKey: id)
                    removed.insert(id)
                }
            }

            // Assign the remainder to the lowest free slots, in a deterministic order.
            // Sets are unordered, so without sorting the same selection could produce
            // different slot numbers on different runs — which would make the store names
            // unstable and the tests flaky.
            let newTokens = wanted.subtracting(keptTokens).sorted { $0.sortKey < $1.sortKey }
            var free = freeSlots(in: next, kind: kind)

            for token in newTokens {
                guard let slot = free.first else { break } // cap checks above make this unreachable
                free.removeFirst()
                let id = BucketID(slot: slot)
                next.buckets[id] = Bucket(id: id, kind: kind, token: token, addedAt: now)
                added.insert(id)
            }
        }

        next.lastPickerCommitAt = now
        return Outcome(
            table: next,
            added: added,
            removed: removed,
            retained: retained,
            refusedAsEssential: refused
        )
    }

    /// Slots in `kind`'s range that no bucket occupies, ascending.
    public static func freeSlots(in table: BucketTable, kind: BucketKind) -> [Int] {
        let taken = Set(table.buckets.keys.map(\.slot))
        return slotRange(for: kind).filter { !taken.contains($0) }
    }

    /// The tokens that would not fit, chosen deterministically so the error message is
    /// stable across runs.
    private static func overflowSample(_ tokens: Set<TokenBlob>, keeping cap: Int) -> Set<TokenBlob> {
        Set(tokens.sorted { $0.sortKey < $1.sortKey }.dropFirst(cap))
    }
}

extension TokenBlob {
    /// Deterministic ordering key. Only ever used for stable iteration and reproducible
    /// slot assignment — never as an identity, and never surfaced to the user.
    var sortKey: String {
        raw.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Enforcement helpers

extension BucketTable {

    /// The buckets that may legitimately be shielded.
    ///
    /// Every write path goes through this rather than iterating `buckets` directly, so an
    /// essential token cannot be shielded even if it somehow reached the table.
    public var shieldableBuckets: [BucketID: Bucket] {
        buckets.filter { !essential.contains($0.value.token) }
    }

    /// True if this token must never be shielded.
    public func isEssential(_ token: TokenBlob) -> Bool {
        essential.contains(token)
    }

    public func bucket(for token: TokenBlob) -> Bucket? {
        buckets.values.first { $0.token == token }
    }

    public var applicationBucketCount: Int {
        buckets.values.count { $0.kind == .application }
    }

    public var categoryBucketCount: Int {
        buckets.values.count { $0.kind == .category }
    }

    /// Marks a token essential and evicts it from shielding in the same step, so there is no
    /// window in which it is both essential and shielded.
    public mutating func markEssential(_ token: TokenBlob) {
        essential.insert(token)
        for (id, bucket) in buckets where bucket.token == token {
            buckets.removeValue(forKey: id)
        }
    }
}
