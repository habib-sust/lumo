import SwiftUI

/// The motion vocabulary.
///
/// Two speeds and one spring, because the design has exactly one orchestrated moment — a completed
/// habit sends motes into the buddy and the light radius springs outward — and everything else is
/// supposed to be still. A codebase with eight bespoke animations does not have a signature moment,
/// it has eight.
enum LumoMotion {

    /// State changes the user caused and is watching for. Fast enough to feel like a response.
    static let quick = Animation.easeOut(duration: 0.22)

    /// The light receding as a paid window burns down. Slow on purpose: this is ambient
    /// information, and an eye-catching decay would make the user watch the clock rather than use
    /// the time they bought.
    static let ambient = Animation.easeInOut(duration: 1.2)

    /// The one bold moment. Overshoots.
    static let surge = Animation.spring(response: 0.55, dampingFraction: 0.62)

    /// The idle breathing loop under the buddy.
    static let breathe = Animation.easeInOut(duration: 3.4).repeatForever(autoreverses: true)
}

// MARK: - Reduce Motion

extension View {

    /// Applies an animation unless the user asked for less motion, in which case it crossfades.
    ///
    /// The fallback is a crossfade rather than nothing at all. Removing the transition entirely
    /// makes the light radius *jump*, and a large area of the screen changing between frames with no
    /// transition is precisely the vestibular trigger Reduce Motion exists to prevent — so "no
    /// animation" would be worse for the people who asked for it than a gentle opacity change.
    func lumoAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(LumoAnimationModifier(animation: animation, value: value))
    }
}

private struct LumoAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .easeInOut(duration: 0.2) : animation, value: value)
    }
}

/// Reads Reduce Motion where a view needs to change its *content* rather than its timing — a static
/// radius instead of a breathing one, no repeating loop at all.
///
/// Separate from the modifier above because "animate more gently" and "do not run a perpetual
/// animation" are different accommodations, and a repeating loop is not fixed by shortening it.
struct ReduceMotionReader<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let content: (Bool) -> Content

    init(@ViewBuilder content: @escaping (Bool) -> Content) {
        self.content = content
    }

    var body: some View { content(reduceMotion) }
}
