import Foundation

/// Builds the offers shown on the shield and in the spend sheet.
///
/// **A pure deterministic function of (bucket, wallet, policy), evaluated independently in every
/// process.** That is not stylistic: `secondaryButtonSubmenuItems` round-trips a *position*, and
/// the response arrives as `.firstSecondarySubmenuItemPressed` and friends. So the config
/// extension renders a list and the action extension receives an index — two processes that must
/// agree on ordering with no identifier passing between them.
///
/// Passing the ladder through the App Group would be a cross-process race that silently sells
/// the wrong tier. A pure function evaluated twice cannot disagree, and the policy fingerprint
/// catches the one case that could: the policy changing between render and tap.
public enum TierLadder {

    /// iOS allows at most three submenu items, and the system adds its own Cancel — so we must
    /// never spend a slot on one.
    public static let maxTiers = 3

    /// Offers for a bucket, cheapest first, capped at three.
    ///
    /// Total and deterministic: no randomness, no clock, no I/O. Given the same inputs it returns
    /// the same list in the same order in every process, every time.
    public static func tiers(
        bucket: BucketID,
        policy: Policy,
        origin: UnlockWindow.Origin = .purchased
    ) -> [SpendCoordinator.Offer] {
        policy.tierMinutes
            .prefix(maxTiers)
            .enumerated()
            .map { index, minutes in
                SpendCoordinator.Offer(
                    bucket: bucket,
                    price: policy.price(forMinutes: minutes),
                    windowSeconds: TimeInterval(minutes * 60),
                    // Usage budget equals the window: the wall clock is the guarantee and the
                    // usage threshold is only an advisory early close.
                    usageBudgetSeconds: TimeInterval(minutes * 60),
                    tierIndex: index,
                    policyFingerprint: policy.fingerprint,
                    origin: origin
                )
            }
    }

    /// Offers the user can currently afford.
    ///
    /// Kept separate from `tiers` on purpose. The shield needs to render only affordable options
    /// — offering something unaffordable is a dead end the user cannot act on — but the action
    /// extension must resolve an index against the **same** filtered list, or index 1 means
    /// different things in the two processes.
    public static func affordableTiers(
        bucket: BucketID,
        wallet: Wallet,
        policy: Policy,
        origin: UnlockWindow.Origin = .purchased
    ) -> [SpendCoordinator.Offer] {
        tiers(bucket: bucket, policy: policy, origin: origin)
            .filter { $0.price <= wallet.total }
    }

    /// Resolves a submenu position back to an offer.
    ///
    /// Returns `nil` rather than guessing when the index is out of range or the policy has
    /// changed since the shield rendered. Refusing costs the user one extra tap; guessing charges
    /// them for a window they did not choose.
    public static func offer(
        atSubmenuIndex index: Int,
        bucket: BucketID,
        wallet: Wallet,
        policy: Policy,
        expectedFingerprint: String?
    ) -> SpendCoordinator.Offer? {
        if let expectedFingerprint, expectedFingerprint != policy.fingerprint { return nil }
        let offers = affordableTiers(bucket: bucket, wallet: wallet, policy: policy)
        guard offers.indices.contains(index) else { return nil }
        return offers[index]
    }

    /// The always-available emergency unlock.
    ///
    /// Free, never rate-limited, and priced at zero rather than "cheap". A user who genuinely
    /// needs Maps or a banking app must never be blocked by an empty wallet — the failure mode
    /// there is not a lost sale, it is someone stranded. The friction is a delay and a prominent
    /// dismiss button in the app, not a price.
    public static func emergencyOffer(
        bucket: BucketID,
        policy: Policy,
        minutes: Int = 15
    ) -> SpendCoordinator.Offer {
        SpendCoordinator.Offer(
            bucket: bucket,
            price: 0,
            windowSeconds: TimeInterval(minutes * 60),
            usageBudgetSeconds: TimeInterval(minutes * 60),
            tierIndex: 0,
            policyFingerprint: policy.fingerprint,
            origin: .emergency
        )
    }

    /// Labels for `secondaryButtonSubmenuItems`.
    ///
    /// Never includes a Cancel entry — the system supplies one, and duplicating it would burn one
    /// of only three slots.
    public static func submenuLabels(for offers: [SpendCoordinator.Offer]) -> [String] {
        offers.prefix(maxTiers).map { offer in
            let minutes = Int(offer.windowSeconds / 60)
            return "\(minutes) min — \(offer.price) coins"
        }
    }
}
