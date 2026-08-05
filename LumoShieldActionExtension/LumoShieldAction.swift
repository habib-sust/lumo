import LumoCore
import ManagedSettings
import os

/// Handles taps on the shield.
///
/// This extension is where a coin spend actually settles on iOS 26.4+, because there is no
/// supported way to open the containing app from here on iOS 18.0–26.4 (an Apple Frameworks
/// Engineer confirmed this, and every workaround needs private API — a removal-grade
/// guideline violation). iOS 26.5 added `.openParentalControlsApp`, but it carries no
/// context, so the App Group handoff stays mandatory either way.
///
/// Three response paths will exist here:
///   * iOS 26.5+  `.openParentalControlsApp`, pending a device spike on its semantics
///   * iOS 26.4+  submenu tier tapped, transaction settles in-process
///   * iOS 18.0+  write a pending request, post a local notification, `.close`
final class LumoShieldAction: ShieldActionDelegate {

    private static let log = Logger(subsystem: "com.habib.Lumo.shieldaction", category: "action")

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action))
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action))
    }

    // MARK: - Dispatch

    private func respond(to action: ShieldAction) -> ShieldActionResponse {
        // `@unknown default` is mandatory, not defensive: ShieldAction and
        // ShieldActionResponse are library-evolution enums and both gained cases recently
        // (iOS 26.4 added the three submenu cases, 26.5 added openParentalControlsApp).
        switch action {
        case .primaryButtonPressed:
            return .close

        case .secondaryButtonPressed:
            // Pre-26.4 path, and also the fallback when no submenu was supplied — Apple
            // documents that providing submenu items SUPPRESSES this case, so both paths
            // have to exist.
            // TODO(T-052/T-055): record a pending spend request, post a local notification.
            Self.log.info("secondaryButtonPressed schema=\(SchemaVersion.current, privacy: .public)")
            return .close

        case .firstSecondarySubmenuItemPressed,
             .secondSecondarySubmenuItemPressed,
             .thirdSecondarySubmenuItemPressed:
            // The submenu round-trips a POSITION, not an identity. So the tier ladder must
            // be recomputed here as a pure function of (bucket, wallet, policy) and
            // validated against a fingerprint — never read from a written handshake, which
            // would be a cross-process race that silently sells the wrong tier.
            // TODO(T-052): recompute tiers, validate fingerprint, then spend.
            Self.log.info("submenu item pressed")
            return .close

        @unknown default:
            return .close
        }
    }
}
