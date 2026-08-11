import LumoCore
import LumoShieldKit
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Supplies the shield screen's appearance.
///
/// `import UIKit` is mandatory here: `ShieldConfiguration` is built from `UIColor`, `UIImage` and
/// `UIBlurEffect.Style`, and the project enables MemberImportVisibility so UIKit does not arrive
/// transitively. This is also why LumoShieldKit must never expose a UIKit type — the 6 MB monitor
/// extension would inherit the link. That regressed twice already, via FamilyControls both times,
/// and the link-graph gate caught it rather than review.
///
/// **Read-only with respect to shield state.** It may compute what the state should be and render
/// truthfully, but it must never write a `ManagedSettingsStore`. Writing from inside the "what
/// should I render?" callback invites re-entrant invalidation on a latency-sensitive path the system
/// can invoke repeatedly.
///
/// The shield is a fixed system layout: blurred background, one icon, title, subtitle, up to two
/// buttons — text and colour only. No custom SwiftUI is possible, which is why anything resembling a
/// friction screen lives in the Lumo app instead.
final class LumoShieldConfiguration: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        Self.shield(for: Self.blob(from: application))
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        Self.shield(for: Self.blob(from: application))
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        Self.shield(for: nil)
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        Self.shield(for: nil)
    }

    // MARK: - Rendering

    private static let ink = UIColor(red: 0.078, green: 0.071, blue: 0.110, alpha: 1)

    private static func blob(from application: Application) -> TokenBlob? {
        guard let token = application.token else { return nil }
        return try? TokenCodec.blob(from: token)
    }

    /// Builds the shield from the live wallet, or a truthful generic one if anything is unreadable.
    private static func shield(for token: TokenBlob?) -> ShieldConfiguration {
        guard let store = LumoStack.stateStore(for: .shieldConfig) else { return placeholder }

        // `observe` holds no ShieldStoring, so this path structurally cannot mutate shield state.
        let observation = ShieldReconciler.observe(state: store)
        guard !observation.isSafeMode else { return placeholder }

        // An unrecognised token is a real case rather than a theoretical one: iOS reissues tokens
        // unpredictably. Render a truthful generic Lumo shield instead of crashing — or worse,
        // returning slowly and letting the system substitute its own grey wall.
        guard let token,
              let table = try? store.loadBuckets(),
              let bucket = table.bucket(for: token)
        else { return placeholder }

        // Same policy the action extension will resolve the tap against. See the note there.
        let policy = LumoStack.policy(for: .shieldConfig)
        let offers = TierLadder.affordableTiers(
            bucket: bucket.id, wallet: observation.wallet, policy: policy)

        return configuration(coins: observation.wallet.total, offers: offers)
    }

    private static func configuration(
        coins: Int,
        offers: [SpendCoordinator.Offer]
    ) -> ShieldConfiguration {
        let subtitle = coins > 0
            ? "You have \(coins) coins."
            : "Do something first. Open Lumo to see how to earn."

        // Note there is no motivational text anywhere on this screen. The preregistered
        // decomposition of this mechanic found the dismiss option and the delay did the work, while
        // the deliberation message did nothing measurable.
        let title = ShieldConfiguration.Label(text: "Light comes first", color: .white)
        let subtitleLabel = ShieldConfiguration.Label(
            text: subtitle, color: UIColor.white.withAlphaComponent(0.75))
        let primary = ShieldConfiguration.Label(text: "Not now", color: ink)
        let secondary = offers.isEmpty
            ? nil
            : ShieldConfiguration.Label(text: "Spend coins", color: .white)

        // On iOS 26.4+ the price tiers go straight onto the shield, so the transaction settles with
        // no app switch at all. The labels come from the SAME pure function the action extension
        // uses, because the submenu round-trips a POSITION rather than an identity — and the system
        // supplies its own Cancel, so spending one of only three slots on one would be waste.
        if #available(iOS 26.4, *), !offers.isEmpty {
            return ShieldConfiguration(
                backgroundBlurStyle: .systemUltraThinMaterialDark,
                backgroundColor: ink,
                icon: nil,
                title: title,
                subtitle: subtitleLabel,
                primaryButtonLabel: primary,
                primaryButtonBackgroundColor: .white,
                secondaryButtonLabel: secondary,
                secondaryButtonSubmenuItems: TierLadder.submenuLabels(for: offers)
            )
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: ink,
            icon: nil,
            title: title,
            subtitle: subtitleLabel,
            primaryButtonLabel: primary,
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: secondary
        )
    }

    /// Always return *something*.
    ///
    /// If this data source is slow or throws, the system substitutes Apple's generic grey shield —
    /// silently replacing Lumo's only conversion surface with an anonymous wall.
    private static var placeholder: ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: ink,
            icon: nil,
            title: .init(text: "Light comes first", color: .white),
            subtitle: .init(
                text: "Open Lumo to see what this costs.",
                color: UIColor.white.withAlphaComponent(0.75)
            ),
            primaryButtonLabel: .init(text: "Not now", color: ink),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: nil
        )
    }
}
