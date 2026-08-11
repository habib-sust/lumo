import SwiftUI

/// The type scale.
///
/// **Everything is built on semantic text styles**, not fixed point sizes, so Dynamic Type and the
/// accessibility sizes come free rather than having to be retrofitted. That is the whole reason the
/// UI face is SF Pro Rounded: it is system-supplied, so it scales, and `.rounded` is a deliberate
/// warmth choice for an app whose entire job is to not feel like a punishment.
///
/// **On Bricolage Grotesque.** The design direction calls for a bundled variable font on headlines
/// and the coin counter. It is not bundled yet, and inventing a `custom(_:)` call for a file that
/// does not exist would silently fall back to the system face with no warning anywhere — the exact
/// class of failure that cannot be distinguished from success. So display type is rounded-heavy for
/// now, isolated to `lumoDisplay` and `lumoCoin`, and swapping in the real face is a two-line change
/// in this file rather than a hunt through the view layer.
extension Font {

    // MARK: - Display

    /// Headlines. The only place the app raises its voice.
    static let lumoDisplay = Font.system(.largeTitle, design: .rounded, weight: .heavy)

    /// The coin counter, and nothing else.
    ///
    /// Monospaced digits are not cosmetic here: the balance changes while it is on screen — earning
    /// a habit, spending a window — and proportional digits make the whole number jitter sideways on
    /// every tick, which reads as instability in the one number the user is asked to trust.
    static let lumoCoin = Font.system(.largeTitle, design: .rounded, weight: .heavy).monospacedDigit()

    // MARK: - UI

    static let lumoTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let lumoHeadline = Font.system(.headline, design: .rounded)
    static let lumoBody = Font.system(.body, design: .rounded)
    static let lumoCallout = Font.system(.callout, design: .rounded)
    /// Secondary text. Pair with `Color.lumoHaze`.
    static let lumoCaption = Font.system(.caption, design: .rounded)

    // MARK: - Numeric

    /// Countdowns and ledger amounts.
    ///
    /// `.monospaced` rather than `.rounded`-with-monospaced-digits, because a timer needs its
    /// separators to hold position too, not just its digits.
    static let lumoTimer = Font.system(.title, design: .monospaced, weight: .medium)
    static let lumoLedger = Font.system(.footnote, design: .monospaced)
}

// MARK: - Text conventions

extension View {

    /// Secondary text: the caption face in haze.
    ///
    /// A modifier rather than two separate calls at each site, because the pairing is the
    /// convention — caption-weight text in full-strength foreground reads as a second body.
    func lumoSecondary() -> some View {
        font(.lumoCaption).foregroundStyle(Color.lumoHaze)
    }

    /// Honest-limit copy: what iOS does not let Lumo guarantee.
    ///
    /// Deliberately its own style rather than reusing `lumoSecondary`. Every competitor eats 1★
    /// reviews for platform behaviour they never explained, so this text is a feature and needs to
    /// be findable — both by the user and by whoever edits it next.
    func lumoDisclosure() -> some View {
        font(.lumoCaption)
            .foregroundStyle(Color.lumoHaze)
            .fixedSize(horizontal: false, vertical: true)
    }
}
