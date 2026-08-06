import FamilyControls
import Foundation
import LumoCore

/// Reads `AuthorizationCenter`'s current status. Synchronous, because the property is.
///
/// Lives in the APP target, not LumoShieldKit, and that placement is load-bearing. FamilyControls
/// links SwiftUI, which links UIKit — and LumoShieldKit is linked by the DeviceActivityMonitor
/// extension, which dies past a 6 MB high-watermark. Putting this in the package reintroduced
/// exactly that leak once already; `lint-imports.sh` and the link-graph gate both caught it.
///
/// No extension reads authorization status — they read the persisted state flags instead — so the
/// app is also where this belongs on the merits.
struct LiveAuthorizationStatus: AuthorizationStatusReading {
    // `nonisolated` throughout: the app target defaults to MainActor isolation, but
    // AuthorizationStatusReading is a Sendable protocol with a nonisolated requirement, and this
    // has to be readable from any context. AuthorizationCenter is a plain ObservableObject rather
    // than a MainActor class, so reading it off the main actor is legitimate.

    init() {}

    nonisolated var status: LumoAuthorizationStatus {
        AuthorizationMapper.status(AuthorizationCenter.shared.authorizationStatus)
    }
}

/// Maps Apple's types onto the portable ones, so the app's logic and copy stay testable on macOS.
enum AuthorizationMapper {

    /// Never written as an equality test.
    ///
    /// `AuthorizationStatus` is a library-evolution enum that gained `approvedWithDataAccess` in
    /// iOS 26.4, so `@unknown default` is mandatory rather than defensive. Note the default maps
    /// to `.denied`: for an unrecognised status the safe assumption is "we cannot shield", because
    /// wrongly believing we can leaves apps open while the UI claims they are locked.
    nonisolated static func status(_ status: AuthorizationStatus) -> LumoAuthorizationStatus {
        // An availability-gated case can be pattern-matched without an `#available` guard —
        // matching evaluates nothing. So all known cases are handled here and `@unknown default`
        // stays meaningful: it fires only for a case Apple adds after this was written, which is
        // exactly the signal worth keeping.
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .approved: return .approved
        case .approvedWithDataAccess: return .approvedWithDataAccess
        @unknown default: return .denied
        }
    }

    /// Maps a thrown error to the blocker whose guidance the user should see.
    ///
    /// Every case is handled explicitly because each has a genuinely different fix — a collapsed
    /// "something went wrong" would strand the user at the one screen they have to get past.
    nonisolated static func blocker(for error: any Error) -> AuthorizationBlocker {
        guard let error = error as? FamilyControlsError else { return .unknown }

        switch error {
        case .authenticationMethodUnavailable: return .needsDevicePasscode
        case .invalidAccountType: return .needsICloudAccount
        case .authorizationConflict: return .conflictingApp
        case .restricted: return .deviceRestricted
        case .networkError: return .offline
        case .authorizationCanceled: return .canceled
        case .unavailable: return .systemUnavailable
        case .invalidArgument: return .invalidRequest
        // iOS 26.4+. Matchable without an `#available` guard, so `@unknown default` keeps its
        // real meaning: a case Apple adds later, not one we simply chose not to list.
        case .unauthorized: return .notAuthorized
        @unknown default: return .unknown
        }
    }

    /// True when Family Controls cannot work at all, regardless of what the user does.
    ///
    /// Checked before requesting rather than after failing, so the Simulator produces a truthful
    /// explanation instead of an opaque `invalidArgument`.
    nonisolated static var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
