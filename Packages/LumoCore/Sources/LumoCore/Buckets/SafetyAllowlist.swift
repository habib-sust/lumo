import Foundation

/// Apps that must never be shielded.
///
/// The motivating review, from a competitor: *"I am a type 1 diabetic and it would block my
/// pump… I can die from that."* This is the one failure mode in Lumo with a physical-harm
/// path, so it is enforced in the reconciler rather than only in the picker — a token in the
/// essential set is never shielded regardless of how it entered the bucket table.
///
/// **Read this before writing onboarding copy.** iOS gives us no way to recognise a CGM app:
/// `ApplicationToken`s are opaque, and `ActivityCategoryPolicy.all(except:)` also takes
/// tokens rather than bundle identifiers. `FamilyActivityData` (iOS 26.4+) does expose
/// `bundleIdentifier` alongside `token`, which would let us map these IDs to tokens — but
/// Apple restricts it in production to EU devices, so it cannot be the worldwide mechanism.
///
/// Therefore the *primary* protection is a user-authored essential set collected before the
/// blocklist picker, and `bundleIDs` below is only a seed for the paths where token
/// resolution actually works. Copy must not promise automatic medical-app protection.
public enum SafetyAllowlist {

    /// Bundle identifiers to seed the essential set from, where the platform lets us resolve
    /// them to tokens. Ordered roughly by consequence of being wrong.
    public static let bundleIDs: [String] = [
        // Communication and emergency
        "com.apple.mobilephone",
        "com.apple.MobileSMS",
        "com.apple.facetime",
        // Navigation
        "com.apple.Maps",
        // Payment and identity
        "com.apple.Passbook",
        // Health — the category that carries the physical-harm path
        "com.apple.Health",
        // System settings — the user needs this to undo anything we did
        "com.apple.Preferences",
    ]

    /// Human-readable groups for the onboarding step, so the UI can explain what it is
    /// protecting without claiming more than the platform allows.
    public static let suggestedCategories: [String] = [
        "Phone and Messages",
        "Maps",
        "Wallet",
        "Health and medical",
        "Settings",
    ]
}
