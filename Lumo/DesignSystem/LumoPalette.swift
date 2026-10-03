import SwiftUI
import UIKit

/// Semantic colors for light and dark appearances.
/// Text tokens meet 4.5:1 contrast on both base and raised surfaces.
extension Color {
    /// Base and raised surfaces.
    static let lumoInk = adaptive(
        light: (0.98, 0.97, 0.95), dark: (0.078, 0.071, 0.110))
    static let lumoSoot = adaptive(
        light: (1, 1, 1), dark: (0.141, 0.122, 0.180))

    static let lumoText = adaptive(
        light: (0.078, 0.071, 0.110), dark: (1, 1, 1))
    static let lumoHaze = adaptive(
        light: (0.36, 0.33, 0.41), dark: (0.75, 0.72, 0.81))

    /// Accented text and meaningful icons need darker colors on light surfaces.
    static let lumoEmber = adaptive(
        light: (0.65, 0.23, 0.08), dark: (1, 0.478, 0.239))
    static let lumoFlare = adaptive(
        light: (0.48, 0.32, 0.04), dark: (1, 0.769, 0.302))
    static let lumoMoss = adaptive(
        light: (0.16, 0.40, 0.29), dark: (0.435, 0.827, 0.659))

    /// Filled controls and artwork retain their warm colors in either appearance.
    static let lumoAccentFill = Color(red: 1, green: 0.769, blue: 0.302)
    static let lumoOnAccent = Color(red: 0.078, green: 0.071, blue: 0.110)
    static let lumoGlowEmber = Color(red: 1, green: 0.478, blue: 0.239)

    private static func adaptive(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let components = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: components.0,
                green: components.1,
                blue: components.2,
                alpha: 1
            )
        })
    }
}

#Preview("Theme contrast") {
    HStack(spacing: 0) {
        contrastPreview
            .environment(\.colorScheme, .light)
        contrastPreview
            .environment(\.colorScheme, .dark)
    }
}

@MainActor
private var contrastPreview: some View {
    VStack(spacing: 20) {
        Text("Lumo").font(.title).foregroundStyle(Color.lumoText)
        Text("Secondary text").foregroundStyle(Color.lumoHaze)
        VStack(spacing: 12) {
            Text("Earn coins").foregroundStyle(Color.lumoEmber)
            Text("120 coins").foregroundStyle(Color.lumoFlare)
            Text("Session complete").foregroundStyle(Color.lumoMoss)
            Text("Details").foregroundStyle(Color.lumoHaze)
        }
        .lumoSurface()
        PrimaryButton("Start", isBusy: false) {}
        PrimaryButton("Unavailable", isBusy: false, isEnabled: false) {}
        ZStack {
            LightRadius(warmth: 1, surge: 0.35)
            Text("Text over glow").foregroundStyle(Color.lumoHaze)
        }
        .frame(height: 100)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .lumoBackground()
}
