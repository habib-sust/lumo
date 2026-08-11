import SwiftUI

/// Spacing and shape.
///
/// A closed set rather than free-floating numbers, so "quiet everywhere, bold once" is enforceable
/// rather than aspirational. The hearth spends the entire visual budget on one gradient; if the
/// surfaces around it drift into bespoke padding and bespoke radii, the light stops reading as the
/// signature and starts reading as decoration among decoration.
enum LumoSpace {
    /// Between a label and the thing it labels.
    static let hair: CGFloat = 4
    static let tight: CGFloat = 8
    /// The default gap inside a group.
    static let snug: CGFloat = 12
    static let regular: CGFloat = 16
    /// Between groups.
    static let loose: CGFloat = 24
    /// Between sections of the hearth.
    static let section: CGFloat = 40

    /// Screen-edge inset. One value, everywhere.
    static let margin: CGFloat = 20
}

enum LumoRadius {
    static let control: CGFloat = 16
    static let surface: CGFloat = 20
    /// App tiles on the hearth's bottom edge. Matches the iOS icon squircle closely enough that a
    /// `Label(token)` icon does not look pasted onto a foreign shape.
    static let tile: CGFloat = 14
}

// MARK: - Surfaces

extension View {

    /// A raised surface: soot, rounded, no border and no shadow.
    ///
    /// Deliberately flat. The design spends its boldness once, on the Light Radius, and a card with
    /// its own gradient or glow competes with the one object that is supposed to carry meaning.
    func lumoSurface(radius: CGFloat = LumoRadius.surface) -> some View {
        padding(LumoSpace.regular)
            .background(Color.lumoSoot)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// The app's base background, edge to edge.
    func lumoBackground() -> some View {
        background(Color.lumoInk.ignoresSafeArea())
    }
}
