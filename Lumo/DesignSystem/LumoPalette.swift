import SwiftUI

/// The "Ember" palette.
///
/// Dark-first because the app's signature is a pool of light whose radius tracks the coin balance,
/// and glow needs somewhere to fall off. Only the tokens Phase 2 actually uses are defined here;
/// the full design system, type scale and the Light Radius component land in Phase 4.
extension Color {
    /// Base. Near-black shifted warm-violet, so it reads cozy rather than clinical.
    static let lumoInk = Color(red: 0.078, green: 0.071, blue: 0.110)
    /// Raised surfaces.
    static let lumoSoot = Color(red: 0.141, green: 0.122, blue: 0.180)
    /// Primary. Coins, energy, light itself.
    static let lumoEmber = Color(red: 1.0, green: 0.478, blue: 0.239)
    /// The hot centre of the glow.
    static let lumoFlare = Color(red: 1.0, green: 0.769, blue: 0.302)
    /// Reserved *exclusively* for "you did the thing" confirmation, so it keeps its meaning.
    static let lumoMoss = Color(red: 0.435, green: 0.827, blue: 0.659)
    /// Secondary text and dim/locked states.
    static let lumoHaze = Color(red: 0.655, green: 0.624, blue: 0.722)
}
