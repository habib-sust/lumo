import LumoCore
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Supplies the shield screen's appearance.
///
/// `import UIKit` is mandatory here, not incidental: `ShieldConfiguration` is built from
/// `UIColor`, `UIImage` and `UIBlurEffect.Style`, and the project enables
/// MemberImportVisibility so UIKit does not arrive transitively. This is also why
/// LumoShieldKit must never expose a UIKit type — the 6 MB monitor extension would inherit
/// the link. (That regressed once already, via FamilyControls, and was caught by the
/// link-graph gate rather than by review.)
///
/// **This extension is read-only with respect to shield state.** It may compute what the
/// state *should* be and render truthfully, but it must never write a
/// `ManagedSettingsStore`. Writing shield state from inside the "what should I render?"
/// callback invites re-entrant invalidation, and this callback sits on a latency-sensitive
/// path that the system can invoke repeatedly.
///
/// The shield is a fixed system layout: blurred background, one icon, title, subtitle, and
/// up to two buttons — text and colour only. No custom SwiftUI is possible. So anything
/// resembling a friction screen or a breathing exercise lives in the Lumo app, not here.
final class LumoShieldConfiguration: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // TODO(T-051): read the wallet and tier ladder via ShieldReconciler.observe(),
        // and on iOS 26.4+ attach secondaryButtonSubmenuItems for the price tiers.
        Self.placeholder
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        Self.placeholder
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        Self.placeholder
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        Self.placeholder
    }

    /// Always return *something*.
    ///
    /// If this data source is slow or throws, the system substitutes Apple's generic grey
    /// shield — which silently replaces Lumo's only conversion surface with an anonymous
    /// wall. The same fallback covers unrecognised tokens, which happen for real: iOS
    /// reissues tokens unpredictably, so an unknown token must render a truthful generic
    /// Lumo shield rather than crash or show nothing.
    private static var placeholder: ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.078, green: 0.071, blue: 0.110, alpha: 1), // ink
            icon: nil,
            title: .init(text: "Light comes first", color: .white),
            subtitle: .init(
                text: "Open Lumo to see what this costs.",
                color: UIColor.white.withAlphaComponent(0.75)
            ),
            primaryButtonLabel: .init(
                text: "Not now",
                color: UIColor(red: 0.078, green: 0.071, blue: 0.110, alpha: 1)
            ),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: nil
        )
    }
}
