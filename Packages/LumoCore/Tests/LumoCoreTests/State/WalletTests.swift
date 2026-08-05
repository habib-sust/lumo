import Foundation
import Testing
@testable import LumoCore

/// T-LEDGER-01…08.
///
/// The invariant these protect: **a missed day may reduce `granted`, and nothing but the
/// user's own spend may ever reduce `earned`.**
///
/// That is not a stylistic preference. Deducting house money on a miss is the ACTIVE REWARD
/// structure — the only loss-framed design whose behavioural effect survived after the
/// incentive stopped. Clawing back coins the user worked for is a different mechanic
/// entirely: asking people to risk something already theirs collapses acceptance from ~90%
/// to ~14%, and removing earned points specifically harms the most engaged users.
///
/// So this file is where the economy's ethics are enforced in code.
@Suite("Wallet — grant vs earned")
struct WalletTests {

    // MARK: - Spending

    @Test("A spend draws from granted before earned")
    func spendDrawsGrantedFirst() throws {
        // Granted-first is deliberate: unspent grant expires weekly, so spending it first
        // costs the user less. It also keeps hard-won earned coins visible, which is the
        // sunk-cost weight that makes deleting Lumo feel like a loss — the only real
        // defence against uninstall, since no API can prevent it.
        var wallet = Wallet(granted: 30, earned: 100)
        // `spend` is mutating, so it cannot be called inside #require — the macro takes its
        // expression immutably. Same pattern throughout this file.
        let outcome = wallet.spend(40)
        let debit = try #require(outcome)

        #expect(debit.granted == 30)
        #expect(debit.earned == 10)
        #expect(wallet.granted == 0)
        #expect(wallet.earned == 90)
    }

    @Test("A spend covered entirely by grant leaves earned untouched")
    func spendWithinGrantLeavesEarnedAlone() throws {
        var wallet = Wallet(granted: 60, earned: 100)
        let outcome = wallet.spend(45)
        let debit = try #require(outcome)

        #expect(debit == .init(granted: 45, earned: 0))
        #expect(wallet.earned == 100)
    }

    @Test("An unaffordable spend changes nothing at all")
    func unaffordableSpendIsAtomic() {
        // A partial debit would be worse than a refusal: the user would lose coins and get
        // no window. The spend protocol depends on this being all-or-nothing.
        var wallet = Wallet(granted: 10, earned: 5)
        let before = wallet

        #expect(wallet.spend(16) == nil)
        #expect(wallet == before)
    }

    @Test("Spending the exact balance is allowed and empties both pots")
    func spendExactBalance() throws {
        var wallet = Wallet(granted: 10, earned: 5)
        let outcome = wallet.spend(15)
        let debit = try #require(outcome)

        #expect(debit == .init(granted: 10, earned: 5))
        #expect(wallet.total == 0)
    }

    // MARK: - Miss deductions — the core invariant

    @Test("A miss deducts from granted only")
    func missDeductsGrantedOnly() {
        var wallet = Wallet(granted: 40, earned: 200)
        let taken = wallet.deductForMiss(20)

        #expect(taken == 20)
        #expect(wallet.granted == 20)
        #expect(wallet.earned == 200)
    }

    @Test("A miss cannot reach into earned once granted is exhausted")
    func missNeverTouchesEarned() {
        // The single most important assertion in this file.
        var wallet = Wallet(granted: 5, earned: 500)
        let taken = wallet.deductForMiss(100)

        #expect(taken == 5, "should deduct only what grant was left")
        #expect(wallet.granted == 0)
        #expect(wallet.earned == 500, "earned must be untouchable by a miss")
    }

    @Test("A miss against an empty grant is a no-op, not a debt")
    func missWithNoGrantIsNoOp() {
        // Debt mechanics are a documented driver of shame spirals and uninstalls, so the
        // floor is zero rather than negative.
        var wallet = Wallet(granted: 0, earned: 75)
        #expect(wallet.deductForMiss(50) == 0)
        #expect(wallet.granted == 0)
        #expect(wallet.earned == 75)
    }

    @Test("Expiring the weekly grant leaves earned intact")
    func grantExpiryLeavesEarnedIntact() {
        var wallet = Wallet(granted: 90, earned: 140)
        #expect(wallet.expireGrant() == 90)
        #expect(wallet.granted == 0)
        #expect(wallet.earned == 140)
    }

    // MARK: - Refunds

    @Test("A refund restores the exact granted/earned split")
    func refundIsExact() throws {
        // Refunding into one pot would silently convert house money into earned coins (or
        // the reverse), quietly breaking the invariant it exists to protect.
        var wallet = Wallet(granted: 30, earned: 100)
        let outcome = wallet.spend(40)
        let debit = try #require(outcome)
        wallet.refund(debit)

        #expect(wallet == Wallet(granted: 30, earned: 100))
    }

    @Test("Spend then refund is identity for any affordable amount")
    func spendRefundRoundTrip() throws {
        for amount in 1...50 {
            var wallet = Wallet(granted: 25, earned: 25)
            let before = wallet
            let outcome = wallet.spend(amount)
            let debit = try #require(outcome)
            wallet.refund(debit)
            #expect(wallet == before, "spend(\(amount)) then refund was not identity")
        }
    }

    // MARK: - Construction

    @Test("Negative balances are clamped rather than stored")
    func negativesAreClamped() {
        #expect(Wallet(granted: -10, earned: -5) == .zero)
        #expect(Wallet.zero.total == 0)
    }

    @Test("Non-positive mutations are ignored")
    func nonPositiveMutationsIgnored() {
        var wallet = Wallet(granted: 10, earned: 10)
        wallet.issueGrant(0)
        wallet.issueGrant(-5)
        wallet.credit(earned: 0)
        wallet.credit(earned: -5)
        #expect(wallet == Wallet(granted: 10, earned: 10))
        #expect(wallet.deductForMiss(-5) == 0)
    }

    // MARK: - T-LEDGER-08: the property test

    @Test("earned is monotonic under any sequence of non-spend operations")
    func earnedIsMonotonicWithoutSpending() {
        // Exhaustive-ish rather than illustrative: the invariant has to hold for sequences
        // nobody thought to write a case for. Seeded so a failure is reproducible.
        var rng = SeededRNG(seed: 0x1_0E_5EED)
        var wallet = Wallet(granted: 50, earned: 50)
        var lowWaterMark = wallet.earned

        for step in 0..<5_000 {
            switch rng.next(upperBound: 5) {
            case 0: wallet.issueGrant(Int(rng.next(upperBound: 200)))
            case 1: wallet.deductForMiss(Int(rng.next(upperBound: 200)))
            case 2: wallet.expireGrant()
            case 3: wallet.credit(earned: Int(rng.next(upperBound: 50)))
            default: wallet.refund(.init(granted: Int(rng.next(upperBound: 20)), earned: 0))
            }

            #expect(
                wallet.earned >= lowWaterMark,
                "earned dropped from \(lowWaterMark) to \(wallet.earned) at step \(step) — no non-spend operation may reduce it"
            )
            lowWaterMark = wallet.earned
            #expect(wallet.granted >= 0)
            #expect(wallet.earned >= 0)
        }
    }

    @Test("Only a spend can reduce earned, and only by the amount it reports")
    func onlySpendReducesEarned() throws {
        var rng = SeededRNG(seed: 99)
        var wallet = Wallet(granted: 500, earned: 500)

        for _ in 0..<2_000 {
            let earnedBefore = wallet.earned
            let amount = Int(rng.next(upperBound: 120))

            if let debit = wallet.spend(amount) {
                #expect(wallet.earned == earnedBefore - debit.earned)
                #expect(debit.total == amount)
            } else {
                #expect(wallet.earned == earnedBefore, "a refused spend must not move earned")
            }

            // Keep the wallet from draining to zero so the loop keeps exercising both paths.
            wallet.issueGrant(Int(rng.next(upperBound: 60)))
            wallet.credit(earned: Int(rng.next(upperBound: 60)))
        }
    }
}

/// A tiny deterministic PRNG (xorshift64*).
///
/// `Math.random`-style entropy would make a property-test failure unreproducible, which is
/// the one thing a property test must not be.
struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xdead_beef : seed
    }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }

    mutating func next(upperBound: UInt64) -> UInt64 {
        upperBound == 0 ? 0 : next() % upperBound
    }
}
