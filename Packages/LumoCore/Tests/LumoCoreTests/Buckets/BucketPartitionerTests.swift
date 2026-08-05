import Foundation
import Testing
@testable import LumoCore

/// T-BUCKET-01…10 and T-ALLOW-01…05.
@Suite("Bucket partitioning and the essential deny-set")
struct BucketPartitionerTests {

    private func token(_ n: Int) -> TokenBlob {
        // Two bytes so ordering is well-defined past 255 and sortKey is stable.
        TokenBlob(raw: Data([UInt8(n / 256), UInt8(n % 256)]))
    }

    private func tokens(_ range: Range<Int>) -> Set<TokenBlob> {
        Set(range.map(token))
    }

    // MARK: - Caps

    @Test("Exactly 40 application tokens is accepted")
    func exactlyFortyIsFine() throws {
        let out = try BucketPartitioner.commit(
            applications: tokens(0..<40), categories: [], into: .empty, now: .fixture)
        #expect(out.table.applicationBucketCount == 40)
        #expect(out.added.count == 40)
    }

    @Test("39 application tokens is accepted")
    func thirtyNineIsFine() throws {
        let out = try BucketPartitioner.commit(
            applications: tokens(0..<39), categories: [], into: .empty, now: .fixture)
        #expect(out.table.applicationBucketCount == 39)
    }

    @Test("41 application tokens is rejected WHOLE, never truncated")
    func fortyOneIsRejectedWhole() {
        // Truncating would be the worst option available: iOS gives no error at 51 tokens,
        // it just silently stops shielding everything, so a partial commit would look like
        // Lumo ate the user's settings.
        let existing = BucketTable.empty
        var thrown: BucketPartitioner.CommitError?
        do {
            _ = try BucketPartitioner.commit(
                applications: tokens(0..<41), categories: [], into: existing, now: .fixture)
        } catch let error as BucketPartitioner.CommitError {
            thrown = error
        } catch {
            Issue.record("unexpected error \(error)")
        }

        guard case let .tooManyApplications(requested, cap, overflow) = thrown else {
            Issue.record("expected tooManyApplications, got \(String(describing: thrown))")
            return
        }
        #expect(requested == 41)
        #expect(cap == 40)
        #expect(overflow.count == 1, "the UI needs to name what did not fit")
    }

    @Test("A rejected commit leaves the existing table completely untouched")
    func rejectionIsAtomic() throws {
        let seeded = try BucketPartitioner.commit(
            applications: tokens(0..<5), categories: [], into: .empty, now: .fixture).table

        _ = try? BucketPartitioner.commit(
            applications: tokens(100..<200), categories: [], into: seeded, now: .fixture)

        #expect(seeded.applicationBucketCount == 5, "the input value must not have mutated")
    }

    @Test("Category tokens are capped separately and live in their own slot range")
    func categoriesHaveTheirOwnRange() throws {
        let out = try BucketPartitioner.commit(
            applications: tokens(0..<40), categories: tokens(500..<508),
            into: .empty, now: .fixture)

        #expect(out.table.applicationBucketCount == 40)
        #expect(out.table.categoryBucketCount == 8)

        // Ranges must not overlap, or two buckets would collide on a store name and
        // unlocking one would silently unlock the other.
        let appSlots = out.table.buckets.filter { $0.value.kind == .application }.keys.map(\.slot)
        let catSlots = out.table.buckets.filter { $0.value.kind == .category }.keys.map(\.slot)
        #expect(appSlots.allSatisfy { BucketPartitioner.applicationSlots.contains($0) })
        #expect(catSlots.allSatisfy { BucketPartitioner.categorySlots.contains($0) })
        #expect(Set(appSlots).isDisjoint(with: Set(catSlots)))
    }

    @Test("9 category tokens is rejected")
    func nineCategoriesRejected() {
        #expect(throws: BucketPartitioner.CommitError.self) {
            _ = try BucketPartitioner.commit(
                applications: [], categories: tokens(0..<9), into: .empty, now: .fixture)
        }
    }

    // MARK: - Slot stability

    @Test("A token keeps its slot across an unrelated commit")
    func slotsAreStableAcrossCommits() throws {
        let first = try BucketPartitioner.commit(
            applications: tokens(0..<3), categories: [], into: .empty, now: .fixture)
        let slotOfToken1 = try #require(first.table.bucket(for: token(1))?.id)

        // Add two more, remove none.
        let second = try BucketPartitioner.commit(
            applications: tokens(0..<5), categories: [], into: first.table, now: .fixture)

        #expect(second.table.bucket(for: token(1))?.id == slotOfToken1)
        #expect(second.retained.count == 3)
        #expect(second.added.count == 2)
        #expect(second.removed.isEmpty)
    }

    @Test("add / remove / add reuses the freed slot and reports it")
    func addRemoveAddReusesSlot() throws {
        let a = try BucketPartitioner.commit(
            applications: tokens(0..<3), categories: [], into: .empty, now: .fixture)
        let originalSlot = try #require(a.table.bucket(for: token(0))?.id)

        // Remove token 0.
        let b = try BucketPartitioner.commit(
            applications: tokens(1..<3), categories: [], into: a.table, now: .fixture)
        #expect(b.removed.contains(originalSlot))
        #expect(b.table.bucket(for: token(0)) == nil)

        // Put it back. Lowest-free-slot means it lands where it was.
        let c = try BucketPartitioner.commit(
            applications: tokens(0..<3), categories: [], into: b.table, now: .fixture)
        #expect(c.table.bucket(for: token(0))?.id == originalSlot)
    }

    @Test("A removed bucket is reported so its store can be cleared, not just forgotten")
    func removalIsReported() throws {
        let a = try BucketPartitioner.commit(
            applications: tokens(0..<4), categories: [], into: .empty, now: .fixture)
        let b = try BucketPartitioner.commit(
            applications: tokens(0..<2), categories: [], into: a.table, now: .fixture)

        // Dropping these on the floor would leave two apps shielded forever with no UI
        // showing them — an unreachable shield the user cannot pay to remove.
        #expect(b.removed.count == 2)
        #expect(b.retained.count == 2)
    }

    @Test("Slot assignment is deterministic for the same input set")
    func assignmentIsDeterministic() throws {
        // Sets are unordered; without an explicit sort the same selection could produce
        // different store names on different runs.
        let first = try BucketPartitioner.commit(
            applications: tokens(0..<10), categories: [], into: .empty, now: .fixture)
        let second = try BucketPartitioner.commit(
            applications: tokens(0..<10), categories: [], into: .empty, now: .fixture)
        #expect(first.table.buckets == second.table.buckets)
    }

    // MARK: - The essential deny-set (T-ALLOW)

    @Test("An essential token is silently refused, not shielded and not an error")
    func essentialTokenIsRefused() throws {
        // Silent refusal is deliberate. Erroring would make the picker feel broken; the
        // right behaviour is to protect the app and let the UI explain.
        var table = BucketTable.empty
        table.essential = [token(2)]

        let out = try BucketPartitioner.commit(
            applications: tokens(0..<5), categories: [], into: table, now: .fixture)

        #expect(out.refusedAsEssential == [token(2)])
        #expect(out.table.bucket(for: token(2)) == nil)
        #expect(out.table.applicationBucketCount == 4)
    }

    @Test("An essential token is never shieldable even if it is already in the table")
    func essentialIsExcludedFromShieldable() throws {
        // Defence in depth: this is the path that protects a user whose table predates the
        // token becoming essential. Enforcement lives here, in the layer the reconciler
        // reads, not only in the picker.
        var table = try BucketPartitioner.commit(
            applications: tokens(0..<3), categories: [], into: .empty, now: .fixture).table
        let victim = try #require(table.bucket(for: token(1)))

        table.essential = [token(1)]

        #expect(table.buckets[victim.id] != nil, "still present in the raw table")
        #expect(table.shieldableBuckets[victim.id] == nil, "but never shieldable")
        #expect(table.isEssential(token(1)))
    }

    @Test("markEssential evicts the bucket in the same step")
    func markEssentialEvicts() throws {
        var table = try BucketPartitioner.commit(
            applications: tokens(0..<3), categories: [], into: .empty, now: .fixture).table

        table.markEssential(token(1))

        // No window may exist in which a token is both essential and shielded.
        #expect(table.bucket(for: token(1)) == nil)
        #expect(table.isEssential(token(1)))
        #expect(table.applicationBucketCount == 2)
    }

    @Test("Essential tokens do not consume slots against the cap")
    func essentialDoesNotConsumeCap() throws {
        // A user who protects 5 apps should still be able to shield a full 40.
        var table = BucketTable.empty
        table.essential = tokens(1000..<1005)

        let out = try BucketPartitioner.commit(
            applications: tokens(0..<40).union(tokens(1000..<1005)),
            categories: [], into: table, now: .fixture)

        #expect(out.table.applicationBucketCount == 40)
        #expect(out.refusedAsEssential.count == 5)
    }

    @Test("The seed allowlist covers the categories the onboarding copy names")
    func allowlistCoversNamedCategories() {
        #expect(SafetyAllowlist.bundleIDs.contains("com.apple.mobilephone"))
        #expect(SafetyAllowlist.bundleIDs.contains("com.apple.MobileSMS"))
        #expect(SafetyAllowlist.bundleIDs.contains("com.apple.Maps"))
        #expect(SafetyAllowlist.bundleIDs.contains("com.apple.Health"))
        // Settings matters specifically: it is how a user undoes anything Lumo did.
        #expect(SafetyAllowlist.bundleIDs.contains("com.apple.Preferences"))
        #expect(!SafetyAllowlist.suggestedCategories.isEmpty)
    }

    // MARK: - Store naming

    @Test("Every assigned slot yields a unique store name")
    func storeNamesAreUnique() throws {
        let out = try BucketPartitioner.commit(
            applications: tokens(0..<40), categories: tokens(500..<508),
            into: .empty, now: .fixture)

        let names = Set(out.table.buckets.keys.map(\.storeNameRaw))
        #expect(names.count == 48)
        // Also inside iOS's 50-named-store limit, with headroom for our own bookkeeping.
        #expect(names.count <= 50)
    }
}
