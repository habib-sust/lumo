import LumoCore
import LumoShieldKit
import ManagedSettings
import os

/// Handles taps on the shield, and settles the coin spend in-process.
///
/// Settling here rather than in the app is not a preference: on iOS 18.0–26.4 there is no supported
/// way to open the containing app from a shield action (confirmed by an Apple Frameworks Engineer),
/// and every workaround needs private API — a removal-grade guideline violation. iOS 26.5 added
/// `.openParentalControlsApp`, but it carries no context, so it can only ever be a courtesy.
///
/// The extension therefore does the transaction itself. It can, because it holds the Family Controls
/// entitlement and may write both `ManagedSettingsStore` and `DeviceActivityCenter`.
final class LumoShieldAction: ShieldActionDelegate {

    private static let log = Logger(subsystem: "com.habib.Lumo.shieldaction", category: "action")

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action, token: try? TokenCodec.blob(from: application)))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action, token: try? TokenCodec.blob(from: webDomain)))
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action, token: try? TokenCodec.blob(from: category)))
    }

    // MARK: - Dispatch

    private func respond(to action: ShieldAction, token: TokenBlob?) -> ShieldActionResponse {
        // `@unknown default` is mandatory rather than defensive: ShieldAction is a
        // library-evolution enum that gained three submenu cases in iOS 26.4.
        switch action {
        case .primaryButtonPressed:
            return .close

        case .secondaryButtonPressed:
            // Reached only when NO submenu was supplied — Apple documents that providing submenu
            // items suppresses this case. So both paths genuinely have to exist, and the plain
            // button buys the cheapest affordable tier.
            return spend(token: token, tierIndex: 0)

        case .firstSecondarySubmenuItemPressed:
            return spend(token: token, tierIndex: 0)
        case .secondSecondarySubmenuItemPressed:
            return spend(token: token, tierIndex: 1)
        case .thirdSecondarySubmenuItemPressed:
            return spend(token: token, tierIndex: 2)

        @unknown default:
            return .close
        }
    }

    /// Prices and settles, entirely in this process.
    private func spend(token: TokenBlob?, tierIndex: Int) -> ShieldActionResponse {
        guard let token,
              let store = LumoStack.stateStore(for: .shieldAction),
              let table = try? store.loadBuckets(),
              let bucket = table.bucket(for: token),
              let state = try? store.loadState(),
              let coordinator = LumoStack.spendCoordinator(for: .shieldAction)
        else {
            Self.log.error("spend unavailable")
            return .close
        }

        // The ladder is RECOMPUTED here, never read from shared state. The submenu round-trips a
        // POSITION, not an identity, so the config extension rendered a list and this process
        // received only an index. Two processes evaluating the same pure function cannot disagree;
        // a written handshake between them would be a race that silently sells the wrong tier.
        let policy = Policy.default
        guard let offer = TierLadder.offer(
            atSubmenuIndex: tierIndex,
            bucket: bucket.id,
            wallet: state.wallet,
            policy: policy,
            expectedFingerprint: policy.fingerprint
        ) else {
            // Refusing costs the user a tap; guessing charges them for a window they did not choose.
            Self.log.info("no affordable offer at index \(tierIndex, privacy: .public)")
            return .close
        }

        do {
            let receipt = try coordinator.spend(offer)
            Self.log.info("settled \(offer.price, privacy: .public) coins")
            // Nudge the app to refresh if it happens to be alive. Nothing depends on delivery.
            DarwinPing.spendSettled.post()
            _ = receipt

            // `.close` rather than `.defer`. There is no ShieldActionResponse meaning "dismiss the
            // shield and let the app run", and community reports conflict on whether `.defer`
            // dismisses in place or simply re-renders. `.close` is deterministic: the shield goes
            // away and the user relaunches the now-unshielded app. One extra tap, no ambiguity.
            return .close
        } catch {
            Self.log.error("spend failed: \(String(describing: error), privacy: .public)")
            // Redraw the shield so the user can see they were not charged, rather than being
            // dropped to the Home screen wondering whether it worked.
            return .defer
        }
    }
}
