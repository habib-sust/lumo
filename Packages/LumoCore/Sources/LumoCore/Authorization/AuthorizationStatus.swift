import Foundation

/// Portable mirror of `FamilyControls.AuthorizationStatus`.
///
/// Exists so the app's authorization logic and copy are testable on macOS, and so the
/// `approvedWithDataAccess` trap is handled in one place.
public enum LumoAuthorizationStatus: String, Codable, Sendable, CaseIterable {
    case notDetermined
    case denied
    case approved
    /// Added in iOS 26.4.
    ///
    /// This case is the reason `== .approved` is banned repo-wide by a merge-blocking CI grep:
    /// an equality test returns `false` for a user who granted *more* access than we asked for,
    /// silently disabling shielding for them. Always ask `isAuthorized`, never compare.
    case approvedWithDataAccess

    /// The only correct way to ask "can we shield?".
    public var isAuthorized: Bool {
        switch self {
        case .approved, .approvedWithDataAccess: true
        case .notDetermined, .denied: false
        }
    }

    /// Whether a prompt is still worth showing. `denied` is not re-promptable in-app — iOS
    /// requires a trip to Settings — so offering a button that silently does nothing would be
    /// worse than saying so.
    public var canRequestInApp: Bool {
        self == .notDetermined
    }
}

/// Portable mirror of every `FamilyControlsError` case, plus the two conditions we detect
/// ourselves.
///
/// Enumerated rather than collapsed into "something went wrong" because each of these has a
/// genuinely different fix, and a generic error here strands the user at the one screen they
/// must get past.
public enum AuthorizationBlocker: String, Codable, Sendable, CaseIterable {
    /// `.authenticationMethodUnavailable` — individual enrolment needs a device passcode.
    case needsDevicePasscode
    /// `.invalidAccountType` — no valid iCloud account.
    case needsICloudAccount
    /// `.authorizationConflict` — another app already provides parental controls.
    case conflictingApp
    /// `.restricted` — MDM, supervision, or Content & Privacy Restrictions.
    case deviceRestricted
    /// `.networkError` — enrolment requires the network.
    case offline
    /// `.authorizationCanceled` — the user dismissed the sheet. Not a failure.
    case canceled
    /// `.unauthorized`, iOS 26.4+.
    case notAuthorized
    /// `.unavailable` — the system's Screen Time daemon failed to set up.
    case systemUnavailable
    /// `.invalidArgument`, and what the Simulator returns.
    case invalidRequest
    /// Detected by us: Family Controls does not function in the Simulator at all.
    case simulatorUnsupported
    /// Anything new Apple adds. Reached via `@unknown default`, never guessed at.
    case unknown
}

/// What to tell the user, and what they can actually do about it.
public struct BlockerGuidance: Sendable, Equatable {
    /// Plain, non-shaming. This screen is where a frustrated user decides whether to keep going.
    public var title: String
    public var explanation: String
    /// The concrete next step, or `nil` when there is genuinely nothing the user can do.
    public var actionLabel: String?
    /// Where in Settings to go, phrased as the user would see it.
    public var settingsPath: String?
    /// Whether retrying in-app could plausibly succeed. `false` means don't offer a retry button
    /// that will just fail again.
    public var isRetryable: Bool

    public init(
        title: String,
        explanation: String,
        actionLabel: String? = nil,
        settingsPath: String? = nil,
        isRetryable: Bool
    ) {
        self.title = title
        self.explanation = explanation
        self.actionLabel = actionLabel
        self.settingsPath = settingsPath
        self.isRetryable = isRetryable
    }
}

public enum AuthorizationCopy {

    /// Always offered, on every blocker screen, without exception.
    ///
    /// Guideline 5.1.2(i): an app may not require the user to enable a system capability in order
    /// to use it. So Lumo has to remain genuinely useful with Screen Time declined — habits,
    /// timers and the buddy all work — and a launch flow that dead-ends on this screen is a
    /// plausible rejection. It is also just correct: trapping someone at a permission wall they
    /// cannot clear is how an app gets deleted.
    public static let continueWithoutLocking = "Continue without app locking"

    /// Distinct, actionable copy per blocker. Total by construction.
    public static func guidance(for blocker: AuthorizationBlocker) -> BlockerGuidance {
        switch blocker {
        case .needsDevicePasscode:
            BlockerGuidance(
                title: "Your iPhone needs a passcode first",
                explanation: "Locking apps relies on Screen Time, and Screen Time needs a device passcode to work. Lumo never sees your passcode.",
                actionLabel: "Open Settings",
                settingsPath: "Settings → Face ID & Passcode → Turn Passcode On",
                isRetryable: true
            )

        case .needsICloudAccount:
            BlockerGuidance(
                title: "Sign in to iCloud to lock apps",
                explanation: "Screen Time is tied to your Apple Account. Signing in lets Lumo lock and unlock apps on this device.",
                actionLabel: "Open Settings",
                settingsPath: "Settings → Sign in to your iPhone",
                isRetryable: true
            )

        case .conflictingApp:
            BlockerGuidance(
                title: "Another app is managing Screen Time",
                explanation: "iOS allows one app at a time to manage Screen Time this way. Turn off the other app's Screen Time access and Lumo can take over.",
                actionLabel: "Open Settings",
                settingsPath: "Settings → Screen Time → Apps with Screen Time Access",
                isRetryable: true
            )

        case .deviceRestricted:
            BlockerGuidance(
                title: "This iPhone doesn't allow app locking",
                explanation: "A device restriction — often a school or work profile — blocks Screen Time access. That's set by whoever manages the device, so Lumo can't change it.",
                actionLabel: nil,
                settingsPath: nil,
                isRetryable: false
            )

        case .offline:
            BlockerGuidance(
                title: "You're offline",
                explanation: "Setting up app locking needs a connection once. After that it works offline.",
                actionLabel: "Try again",
                settingsPath: nil,
                isRetryable: true
            )

        case .canceled:
            // Explicitly not framed as an error. The user made a choice, and pestering them is
            // how a permission prompt becomes a reason to delete the app.
            BlockerGuidance(
                title: "No problem",
                explanation: "You can turn on app locking whenever you like. Habits and your buddy work either way.",
                actionLabel: "Turn on app locking",
                settingsPath: nil,
                isRetryable: true
            )

        case .notAuthorized:
            BlockerGuidance(
                title: "Lumo's Screen Time access was turned off",
                explanation: "Your locked apps are open again. Granting access restores them exactly as they were — your coins and streak are untouched.",
                actionLabel: "Open Settings",
                settingsPath: "Settings → Screen Time → Apps with Screen Time Access",
                isRetryable: true
            )

        case .systemUnavailable:
            BlockerGuidance(
                title: "Screen Time isn't responding",
                explanation: "This is usually temporary. Trying again, or restarting your iPhone, normally clears it.",
                actionLabel: "Try again",
                settingsPath: nil,
                isRetryable: true
            )

        case .invalidRequest:
            BlockerGuidance(
                title: "Couldn't set up app locking",
                explanation: "Something went wrong asking iOS for Screen Time access. Trying again is safe.",
                actionLabel: "Try again",
                settingsPath: nil,
                isRetryable: true
            )

        case .simulatorUnsupported:
            // Developer-facing, and deliberately explicit: this costs hours if you assume the
            // code is broken rather than the platform.
            BlockerGuidance(
                title: "Not available in the Simulator",
                explanation: "Family Controls doesn't function in the iOS Simulator at all. Run on a physical device with a passcode set and iCloud signed in.",
                actionLabel: nil,
                settingsPath: nil,
                isRetryable: false
            )

        case .unknown:
            BlockerGuidance(
                title: "Couldn't turn on app locking",
                explanation: "iOS reported something Lumo doesn't recognise yet. Habits and your buddy still work.",
                actionLabel: "Try again",
                settingsPath: nil,
                isRetryable: true
            )
        }
    }
}

/// Reads the current authorization status. Synchronous — the underlying property is.
public protocol AuthorizationStatusReading: Sendable {
    var status: LumoAuthorizationStatus { get }
}
