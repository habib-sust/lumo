import SwiftUI

/// The app's one bold object: a pool of light whose reach is the coin balance.
///
/// This carries the balance HUD, the progress signal, the countdown and the emotional tone in a
/// single object with no chrome — which is the point. A card dashboard would say the same things in
/// four boxes, and the user would read none of them.
///
/// Three channels, all driven by one number:
///
///   - **radius** — how far the light reaches. This is the balance.
///   - **saturation** — how alive the colour is. Near-zero balance desaturates towards grey.
///   - **intensity** — the hot centre. Surges on earning, recedes as a paid window burns down.
///
/// Deliberately NOT a progress bar. A bar has an end, and implies that filling it is the goal;
/// the light has no maximum the user is working towards, because the goal is the life outside it.
struct LightRadius: View {

    /// 0…1. Not coins directly — the caller maps balance to warmth, because "how bright should 200
    /// coins be" is an economy question and this view has no business answering it.
    let warmth: Double

    /// Extra brightness layered on top, for the moment a habit completes or a window opens.
    var surge: Double = 0

    /// Reduce Motion is handled by `lumoAnimation`, which substitutes a crossfade — deliberately
    /// not "no animation", since an un-transitioned jump across this much of the screen is the
    /// vestibular trigger the setting exists to prevent.
    var body: some View {
        GeometryReader { geometry in
            let side = max(geometry.size.width, geometry.size.height)
            let clamped = min(max(warmth, 0), 1)
            let boosted = min(1, clamped + surge)

            RadialGradient(
                stops: [
                    .init(color: .lumoAccentFill.opacity(0.95 * boosted), location: 0),
                    .init(color: .lumoGlowEmber.opacity(0.55 * boosted), location: 0.35),
                    .init(color: .lumoGlowEmber.opacity(0), location: 1),
                ],
                center: .center,
                startRadius: 0,
                // Never collapses to zero. A balance of nothing still shows an ember, because a
                // screen that goes fully dark reads as "broken" or "you have failed", and the
                // whole design brief is a companion you help rather than one that punishes you.
                endRadius: side * (0.18 + 0.42 * boosted)
            )
            // Desaturating at low warmth does the emotional work that a red "empty" state would
            // otherwise do, without ever using an alarm colour on the user's own balance.
            .saturation(0.35 + 0.65 * clamped)
            // Keep text readable even at peak warmth and during a surge.
            .opacity(0.12)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .lumoAnimation(LumoMotion.ambient, value: clamped)
            .lumoAnimation(LumoMotion.surge, value: surge)
        }
        // The light is atmosphere. Its meaning is always stated in text elsewhere on the screen, so
        // hiding it here is not a loss of information — and announcing "radial gradient" would be.
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Mapping

extension LightRadius {

    /// Maps a coin balance to warmth.
    ///
    /// Logarithmic, not linear. A linear map makes the first 20 coins invisible and the difference
    /// between 400 and 500 obvious, which is exactly backwards: early progress is when the user
    /// needs to see that this works, and by 400 the number itself is doing the talking. This also
    /// mirrors the economy's own rule that reward magnitude saturates almost immediately — in a
    /// 61,293-person megastudy $0.09 beat $1.75.
    static func warmth(forBalance coins: Int) -> Double {
        guard coins > 0 else { return 0 }
        // Reaches ~0.75 around a day's earning and approaches 1 slowly after that.
        return min(1, log(Double(coins) + 1) / log(400))
    }
}

#Preview("Light radius") {
    VStack(spacing: 0) {
        ForEach([0, 5, 45, 200, 800], id: \.self) { coins in
            ZStack {
                LightRadius(warmth: LightRadius.warmth(forBalance: coins))
                Text("\(coins)")
                    .font(.lumoCoin)
                    .foregroundStyle(Color.lumoText)
            }
            .frame(height: 120)
        }
    }
    .lumoBackground()
}
