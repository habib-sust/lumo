import LumoCore
import LumoShieldKit
import SwiftUI

/// Buy a window on one app.
///
/// The ladder shown here is `TierLadder.affordableTiers` — the **same pure function** the shield
/// config extension renders and the shield action extension resolves a tapped index against. Three
/// processes, one function, no handshake: that is what makes it impossible for the sheet to offer a
/// price the shield would refuse.
struct SpendSheet: View {

    let bucket: BucketID
    let snapshot: HearthSnapshot
    /// Called after a successful spend, so the hearth can flash and re-read.
    let onSpent: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var failure: String?
    @State private var isSpending = false

    private var offers: [SpendCoordinator.Offer] {
        TierLadder.affordableTiers(
            bucket: bucket, wallet: snapshot.wallet, policy: snapshot.policy)
    }

    /// Everything on the ladder, so an unaffordable tier can be shown as a target rather than
    /// hidden. Hiding it makes the economy look smaller than it is; showing it priced and disabled
    /// is the informational-feedback version.
    private var allTiers: [SpendCoordinator.Offer] {
        TierLadder.tiers(bucket: bucket, policy: snapshot.policy)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lumoInk.ignoresSafeArea()
                VStack(alignment: .leading, spacing: LumoSpace.regular) {
                    balanceLine
                    tiers
                    Spacer()
                    disclosure
                }
                .padding(LumoSpace.margin)
            }
            .navigationTitle("Open for a while")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                        .accessibilityIdentifier("spend.cancel")
                }
            }
            .alert("That didn't go through", isPresented: .init(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            )) {
                Button("OK", role: .cancel) { failure = nil }
            } message: {
                Text(failure ?? "")
            }
        }
    }

    private var balanceLine: some View {
        HStack(spacing: LumoSpace.snug) {
            if let target = snapshot.locked.first(where: { $0.id == bucket }) {
                BucketLabel(bucket: target)
                    .frame(width: 44, height: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.wallet.total) coins")
                    .font(.lumoTitle)
                    .foregroundStyle(.white)
                Text("\(snapshot.wallet.earned) earned, \(snapshot.wallet.granted) allowance")
                    .lumoSecondary()
            }
            Spacer()
        }
    }

    private var tiers: some View {
        VStack(spacing: LumoSpace.tight) {
            ForEach(allTiers, id: \.tierIndex) { offer in
                let affordable = offers.contains { $0.tierIndex == offer.tierIndex }
                Button {
                    spend(offer)
                } label: {
                    HStack {
                        Text("\(Int(offer.windowSeconds / 60)) minutes")
                            .font(.lumoHeadline)
                        Spacer()
                        Text("\(offer.price)")
                            .font(.lumoLedger)
                    }
                    .foregroundStyle(affordable ? Color.white : Color.lumoHaze)
                    .padding(.vertical, LumoSpace.snug)
                    .padding(.horizontal, LumoSpace.regular)
                    .frame(maxWidth: .infinity)
                    .background(affordable ? Color.lumoSoot : Color.lumoSoot.opacity(0.45))
                    .clipShape(
                        RoundedRectangle(cornerRadius: LumoRadius.control, style: .continuous))
                }
                .disabled(!affordable || isSpending)
                .accessibilityIdentifier("spend.tier.\(offer.tierIndex)")
                .accessibilityLabel(
                    "\(Int(offer.windowSeconds / 60)) minutes for \(offer.price) coins")
            }

            if offers.isEmpty {
                // Never a dead end. The wallet being empty is a reason to go earn, not a wall — and
                // the emergency unlock is reachable from Settings regardless of balance.
                Text("Not enough yet. Finish something and come back.")
                    .lumoSecondary()
                    .padding(.top, LumoSpace.tight)
            }
        }
    }

    /// The honest limits, stated up front rather than discovered.
    ///
    /// Both of these are things iOS imposes and every competitor lets the user find out the hard
    /// way — then eats the 1★ review for a platform behaviour they never explained.
    private var disclosure: some View {
        VStack(alignment: .leading, spacing: LumoSpace.tight) {
            Text("Your window ends around the time shown, not to the second.")
            Text("Lumo can unlock the app, but it can't open it — you'll switch to it yourself.")
        }
        .lumoDisclosure()
    }

    private func spend(_ offer: SpendCoordinator.Offer) {
        guard let coordinator = LumoStack.spendCoordinator(for: .app) else {
            failure = "Lumo can't reach its shared storage right now."
            return
        }
        isSpending = true
        defer { isSpending = false }

        do {
            _ = try coordinator.spend(offer)
            onSpent()
            dismiss()
        } catch let error as SpendCoordinator.SpendError {
            failure = Self.message(for: error)
        } catch {
            failure = "Something went wrong. Nothing was spent."
        }
    }

    /// Plain, specific, and never blaming the user.
    ///
    /// `couldNotArm` matters most: the debit is rolled back and the app stays shielded, because
    /// unshielding without an armed timer is the one failure that never self-corrects. Saying so
    /// plainly beats a generic error, since the user's real question is "did that cost me coins".
    static func message(for error: SpendCoordinator.SpendError) -> String {
        switch error {
        case let .insufficientCoins(needed, available):
            "That one costs \(needed) and you have \(available)."
        case .alreadyOpen:
            "That app is already open. No coins were spent."
        case .bucketIsEssential:
            "You marked that app as essential, so it's never locked."
        case .unknownBucket:
            "Lumo has lost track of that app. Re-pick your apps in Settings."
        case .couldNotArm:
            "iOS wouldn't start the timer, so nothing was unlocked and nothing was spent."
        case .lockUnavailable, .stateUnavailable:
            "Lumo is busy finishing something else. Try that again in a moment."
        case .safeMode:
            "Lumo has locked everything while it sorts out a problem. Check Settings."
        }
    }
}
