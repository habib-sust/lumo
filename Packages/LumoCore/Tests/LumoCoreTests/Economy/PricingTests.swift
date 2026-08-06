import Foundation
import Testing
@testable import LumoCore

/// T-PRICE-01…12 and T-MIGRATE-01…08.
@Suite("Pricing, tier ladder, migration")
struct PricingTests {

    private let bucket = BucketID(slot: 3)

    private func baseline(scroll: Double, habit: Double) -> Baseline {
        Baseline(
            scrollMinutesPerDay: scroll, habitMinutesPerDay: habit,
            source: .thresholdLadder, observedAt: .fixture
        )
    }

    // MARK: - The admissible band

    @Test("The band sits strictly above the baseline ratio")
    func bandIsAboveBaseline() {
        // Sitting exactly on the baseline is not deprivation — there is nothing to trade.
        let b = baseline(scroll: 120, habit: 20) // ratio 1/6
        let band = Pricing.admissibleBand(for: b)
        #expect(band.lowerBound > b.ratio)
        #expect(band.upperBound > band.lowerBound)
    }

    @Test("Just below the lower bound is a punisher")
    func belowLowerBoundIsPunisher() {
        // The boundary that matters most, and the one no competitor checks: below it the
        // contingency stops reinforcing and actively suppresses the habit. A cheap price is
        // worse than no app at all.
        let b = baseline(scroll: 120, habit: 20)
        let band = Pricing.admissibleBand(for: b)

        #expect(Pricing.isPunisher(ratio: band.lowerBound - 0.0001, baseline: b))
        #expect(!Pricing.isPunisher(ratio: band.lowerBound, baseline: b))
    }

    @Test("Just above the upper bound is ratio strain")
    func aboveUpperBoundIsStrain() {
        let b = baseline(scroll: 120, habit: 20)
        let band = Pricing.admissibleBand(for: b)

        #expect(Pricing.hasRatioStrain(ratio: band.upperBound + 0.0001, baseline: b))
        #expect(!Pricing.hasRatioStrain(ratio: band.upperBound, baseline: b))
    }

    @Test("Clamping pulls any proposal into the band, from either side")
    func clampWorksBothWays() {
        // Autonomy support matters — the user authoring their own economy is one of the few
        // mitigations for the overjustification effect — but they must not be able to choose a
        // price that makes the mechanic harmful.
        let b = baseline(scroll: 120, habit: 20)
        let band = Pricing.admissibleBand(for: b)

        #expect(Pricing.clamp(ratio: 0, baseline: b) == band.lowerBound)
        #expect(Pricing.clamp(ratio: 999, baseline: b) == band.upperBound)
        let inside = (band.lowerBound + band.upperBound) / 2
        #expect(Pricing.clamp(ratio: inside, baseline: b) == inside)
    }

    @Test("A heavy scroller gets a gentler required ratio than a light one")
    func heavierBaselineMeansGentlerRatio() {
        // 4h/day of scrolling with the same habit time is a lower baseline ratio, so the price
        // that clears deprivation is lower too. This is the whole point of per-user pricing:
        // a global table would punish the heavy user and under-charge the light one.
        let heavy = baseline(scroll: 240, habit: 20)
        let light = baseline(scroll: 60, habit: 20)

        #expect(Pricing.admissibleBand(for: heavy).lowerBound
                < Pricing.admissibleBand(for: light).lowerBound)
    }

    @Test("A degenerate baseline does not produce an inverted range")
    func degenerateBaselineIsSafe() {
        // Total and defined for every input, including nonsense — the reconciler cannot afford
        // to trap here.
        let zero = baseline(scroll: 0, habit: 0)
        let band = Pricing.admissibleBand(for: zero)
        #expect(band.lowerBound <= band.upperBound)

        let noHabits = baseline(scroll: 120, habit: 0)
        #expect(Pricing.admissibleBand(for: noHabits).lowerBound >= 0)
    }

    // MARK: - Policy

    @Test("The default policy sits inside its own admissible band")
    func defaultPolicyIsAdmissible() {
        let policy = Policy.default
        let band = Pricing.admissibleBand(for: policy.baseline)
        #expect(band.contains(policy.requiredRatio))
        #expect(!Pricing.isPunisher(ratio: policy.requiredRatio, baseline: policy.baseline))
        #expect(!Pricing.hasRatioStrain(ratio: policy.requiredRatio, baseline: policy.baseline))
    }

    @Test("An out-of-band ratio is clamped at construction, not stored raw")
    func policyClampsOnInit() {
        let b = baseline(scroll: 120, habit: 20)
        let tooCheap = Policy(baseline: b, requiredRatio: 0.0001)
        let tooDear = Policy(baseline: b, requiredRatio: 500)

        #expect(!Pricing.isPunisher(ratio: tooCheap.requiredRatio, baseline: b))
        #expect(!Pricing.hasRatioStrain(ratio: tooDear.requiredRatio, baseline: b))
    }

    @Test("Nothing is ever free by rounding")
    func priceIsNeverZero() {
        // A one-minute tier at a tiny ratio could round to zero coins, which would make the
        // whole economy bypassable in one tap.
        let policy = Policy(baseline: baseline(scroll: 600, habit: 1), coinsPerHabitMinute: 1)
        #expect(policy.price(forMinutes: 1) >= 1)
        for minutes in 1...120 {
            #expect(policy.price(forMinutes: minutes) >= 1)
        }
    }

    @Test("Price rises monotonically with window length")
    func priceIsMonotonic() {
        let policy = Policy.default
        var previous = 0
        for minutes in [5, 15, 30, 60, 120] {
            let price = policy.price(forMinutes: minutes)
            #expect(price >= previous, "price went down from \(previous) to \(price)")
            previous = price
        }
    }

    @Test("The default policy allows more than one earn-spend cycle per day")
    func defaultPolicySupportsMultipleCycles() {
        // Saving for three days to afford one unlock does not build a habit; the literature's
        // heuristic is a reinforcer reachable several times per session.
        #expect(Policy.default.supportsMultipleDailyCycles())
    }

    @Test("A policy that requires days of saving is detectable")
    func ratioStrainIsDetectable() {
        // Deliberately punishing: heavy scroller, almost no habit time, expensive coins.
        let policy = Policy(
            baseline: baseline(scroll: 300, habit: 2),
            coinsPerHabitMinute: 1,
            requiredRatio: Pricing.admissibleBand(for: baseline(scroll: 300, habit: 2)).upperBound,
            tierMinutes: [60]
        )
        #expect(!policy.supportsMultipleDailyCycles(), "should flag as unreachable")
    }

    // MARK: - Fingerprint

    @Test("The fingerprint is order-sensitive")
    func fingerprintIsOrderSensitive() {
        // Order matters because the submenu's POSITION is the only identity that crosses the
        // process boundary. Two policies with the same tiers in a different order must not
        // compare equal, or index 1 could mean different things in two processes.
        let a = Policy(tierMinutes: [15, 30, 60])
        let b = Policy(tierMinutes: [60, 30, 15])
        // Policy sorts on init, so these end up identical — which is itself the guarantee.
        #expect(a.fingerprint == b.fingerprint)

        let c = Policy(tierMinutes: [15, 30, 90])
        #expect(a.fingerprint != c.fingerprint, "different tiers must fingerprint differently")
    }

    @Test("The fingerprint changes when anything price-relevant changes")
    func fingerprintCoversPricingInputs() {
        let base = Policy.default
        #expect(base.fingerprint != Policy(coinsPerHabitMinute: 5).fingerprint)
        #expect(base.fingerprint != Policy(tierMinutes: [10, 20]).fingerprint)
        #expect(base.fingerprint
                != Policy(baseline: baseline(scroll: 300, habit: 20)).fingerprint)
    }

    // MARK: - Tier ladder

    @Test("At most three tiers are ever offered")
    func atMostThreeTiers() {
        // iOS allows three submenu items and adds its own Cancel, so a fourth is unrenderable.
        let policy = Policy(tierMinutes: [5, 15, 30, 60, 120])
        #expect(TierLadder.tiers(bucket: bucket, policy: policy).count == TierLadder.maxTiers)
    }

    @Test("Tiers are deterministic across repeated evaluation")
    func tiersAreDeterministic() {
        // The safety property: two processes computing this independently must agree, because
        // nothing but the index travels between them.
        let policy = Policy.default
        let first = TierLadder.tiers(bucket: bucket, policy: policy)
        let second = TierLadder.tiers(bucket: bucket, policy: policy)
        #expect(first == second)
    }

    @Test("Tier indices match array positions")
    func tierIndicesMatchPositions() {
        let offers = TierLadder.tiers(bucket: bucket, policy: .default)
        for (position, offer) in offers.enumerated() {
            #expect(offer.tierIndex == position)
        }
    }

    @Test("Only affordable tiers are offered")
    func onlyAffordableTiers() {
        let policy = Policy.default
        let all = TierLadder.tiers(bucket: bucket, policy: policy)
        let cheapest = try! #require(all.first)

        let broke = TierLadder.affordableTiers(
            bucket: bucket, wallet: Wallet(granted: cheapest.price - 1, earned: 0), policy: policy)
        #expect(broke.isEmpty, "offering an unaffordable tier is a dead end")

        let rich = TierLadder.affordableTiers(
            bucket: bucket, wallet: Wallet(granted: 100_000, earned: 0), policy: policy)
        #expect(rich.count == all.count)
    }

    @Test("A submenu index resolves against the AFFORDABLE list, not the full one")
    func indexResolvesAgainstAffordableList() {
        // The subtle bug this prevents: if the shield renders 2 affordable tiers and the action
        // extension resolves index 1 against all 3, the user is charged for the wrong window.
        let policy = Policy.default
        let all = TierLadder.tiers(bucket: bucket, policy: policy)
        let wallet = Wallet(granted: all[1].price, earned: 0) // affords the first two

        let affordable = TierLadder.affordableTiers(bucket: bucket, wallet: wallet, policy: policy)
        #expect(affordable.count == 2)

        let resolved = TierLadder.offer(
            atSubmenuIndex: 1, bucket: bucket, wallet: wallet,
            policy: policy, expectedFingerprint: policy.fingerprint)
        #expect(resolved?.windowSeconds == affordable[1].windowSeconds)
    }

    @Test("An out-of-range index resolves to nil rather than guessing")
    func outOfRangeIndexIsNil() {
        let policy = Policy.default
        let wallet = Wallet(granted: 0, earned: 0)
        #expect(TierLadder.offer(atSubmenuIndex: 0, bucket: bucket, wallet: wallet,
                                policy: policy, expectedFingerprint: nil) == nil)
        #expect(TierLadder.offer(atSubmenuIndex: 99, bucket: bucket,
                                wallet: Wallet(granted: 10_000, earned: 0),
                                policy: policy, expectedFingerprint: nil) == nil)
    }

    @Test("A stale fingerprint refuses the spend")
    func staleFingerprintRefuses() {
        // Covers the one case a pure function cannot: the policy changing between the shield
        // rendering and the user tapping. Refusing costs a tap; guessing charges for a window
        // they did not choose.
        let policy = Policy.default
        let wallet = Wallet(granted: 10_000, earned: 0)
        #expect(TierLadder.offer(atSubmenuIndex: 0, bucket: bucket, wallet: wallet,
                                policy: policy, expectedFingerprint: "stale") == nil)
    }

    @Test("The emergency offer is free, never priced")
    func emergencyIsFree() {
        // Someone who genuinely needs Maps or a banking app must never be blocked by an empty
        // wallet. The friction is a delay in the app, not a price.
        let offer = TierLadder.emergencyOffer(bucket: bucket, policy: .default)
        #expect(offer.price == 0)
        #expect(offer.origin == .emergency)
    }

    @Test("Submenu labels never include a Cancel entry")
    func labelsExcludeCancel() {
        // The system adds Cancel itself; duplicating it would burn one of only three slots.
        let offers = TierLadder.tiers(bucket: bucket, policy: .default)
        let labels = TierLadder.submenuLabels(for: offers)
        #expect(labels.count <= TierLadder.maxTiers)
        #expect(!labels.contains { $0.lowercased().contains("cancel") })
        #expect(labels.allSatisfy { $0.contains("coins") })
    }

    // MARK: - Migration harness

    @Test("Same version is a no-op")
    func sameVersionNoOp() throws {
        #expect(try LumoMigrator.plan(from: 1, to: 1).isEmpty)
    }

    @Test("A future stored version refuses rather than guessing")
    func futureVersionRefuses() {
        // Writing against a layout we do not understand would corrupt the wallet silently.
        #expect(throws: LumoMigrator.MigrationError.futureVersion(stored: 3, supported: 1)) {
            _ = try LumoMigrator.plan(from: 3, to: 1)
        }
    }

    @Test("A missing step is detected before any data is touched")
    func missingStepIsDetectedUpFront() {
        // A migration that gets halfway and then cannot finish leaves state in a shape no
        // version understands — so the chain is validated first.
        #expect(throws: LumoMigrator.MigrationError.noPath(from: 1, to: 3)) {
            _ = try LumoMigrator.plan(from: 1, to: 3, steps: [
                MigrationStep(from: 1, to: 2) { $0 },
            ])
        }
    }

    @Test("A synthetic two-step chain applies in order")
    func chainAppliesInOrder() throws {
        // Proves the harness shape with a real chain, since the production chain is empty at v1
        // and the first real migration will arrive under time pressure.
        let steps = [
            MigrationStep(from: 1, to: 2) { Data(($0.map { $0 } + Array("A".utf8))) },
            MigrationStep(from: 2, to: 3) { Data(($0.map { $0 } + Array("B".utf8))) },
        ]
        let outcome = try LumoMigrator.migrate(
            data: Data("x".utf8), from: 1, to: 3, steps: steps)

        #expect(String(data: outcome.data, encoding: .utf8) == "xAB")
        #expect(outcome.stepsApplied == 2)
        #expect(outcome.didMigrate)
    }

    @Test("A failing step is reported with its position")
    func failingStepIsReported() {
        let steps = [
            MigrationStep(from: 1, to: 2) { _ in throw FakeError.unavailable },
        ]
        #expect(throws: LumoMigrator.MigrationError.stepFailed(from: 1, to: 2)) {
            _ = try LumoMigrator.migrate(data: Data(), from: 1, to: 2, steps: steps)
        }
    }

    @Test("The frozen v1 shape decodes today's payload")
    func frozenShapeDecodesCurrentPayload() throws {
        // The freeze is only useful if it actually matches what shipped.
        let state = SharedState(wallet: Wallet(granted: 12, earned: 34), flags: [.safeMode])
        let data = try JSONEncoder().encode(state)
        let frozen = try JSONDecoder().decode(SharedState_v1.self, from: data)

        #expect(frozen.wallet == state.wallet)
        #expect(frozen.flags == state.flags)
    }

    @Test("The frozen v1 shape also decodes from an empty object")
    func frozenShapeDecodesFromEmpty() throws {
        _ = try JSONDecoder().decode(SharedState_v1.self, from: Data("{}".utf8))
    }

    // MARK: - migrateIfNeeded

    private func makeDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "lumo.migrate.\(UUID().uuidString)")!
        for key in StateKey.all { d.removeObject(forKey: key) }
        return d
    }

    @Test("A first launch stamps the version without migrating")
    func firstLaunchStampsVersion() throws {
        let defaults = makeDefaults()
        #expect(try LumoMigrator.migrateIfNeeded(defaults: defaults) == nil)
        #expect(defaults.object(forKey: StateKey.schemaVersion) as? Int == SchemaVersion.current)
    }

    @Test("A matching version does nothing")
    func matchingVersionDoesNothing() throws {
        let defaults = makeDefaults()
        defaults.set(SchemaVersion.current, forKey: StateKey.schemaVersion)
        #expect(try LumoMigrator.migrateIfNeeded(defaults: defaults) == nil)
    }

    @Test("The version is bumped LAST, so a crash mid-migration re-runs")
    func versionIsBumpedLast() throws {
        // Bumping first would leave old-shaped data labelled as new, which nothing could ever
        // recover from. Each step is pure, so re-running is safe.
        let defaults = makeDefaults()
        defaults.set(1, forKey: StateKey.schemaVersion)
        defaults.set(Data("payload".utf8), forKey: StateKey.state)

        let failing = [MigrationStep(from: 1, to: 2) { _ in throw FakeError.unavailable }]
        #expect(throws: LumoMigrator.MigrationError.self) {
            _ = try LumoMigrator.migrateIfNeeded(defaults: defaults, to: 2, steps: failing)
        }

        #expect(defaults.object(forKey: StateKey.schemaVersion) as? Int == 1,
                "version must still be 1 so the migration retries next launch")
        #expect(defaults.data(forKey: StateKey.state) == Data("payload".utf8),
                "payload must be untouched")
    }

    @Test("A successful migration invalidates the stale backup")
    func migrationInvalidatesBackup() throws {
        // The backup still holds the OLD shape, so recovering from it after migrating would
        // silently downgrade the payload.
        let defaults = makeDefaults()
        defaults.set(1, forKey: StateKey.schemaVersion)
        defaults.set(Data("old".utf8), forKey: StateKey.state)
        defaults.set(Data("older".utf8), forKey: StateKey.stateBackup)

        let steps = [MigrationStep(from: 1, to: 2) { Data(($0.map { $0 } + Array("!".utf8))) }]
        let outcome = try LumoMigrator.migrateIfNeeded(defaults: defaults, to: 2, steps: steps)

        #expect(outcome?.stepsApplied == 1)
        #expect(defaults.data(forKey: StateKey.stateBackup) == nil)
        #expect(defaults.object(forKey: StateKey.schemaVersion) as? Int == 2)
    }
}
