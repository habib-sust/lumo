import FamilyControls
import LumoCore
import Observation
import SwiftUI

/// Owns the interactive Screen Time authorization flow.
///
/// The async *request* lives here in the app rather than in LumoShieldKit, because only the app
/// ever prompts — and keeping `await` out of the packages preserves the guarantee that nothing
/// the reconciler depends on can suspend. Status *reading* stays synchronous and shared.
@MainActor
@Observable
final class AuthorizationService {

    private(set) var status: LumoAuthorizationStatus
    private(set) var blocker: AuthorizationBlocker?
    private(set) var isRequesting = false

    private let reader: any AuthorizationStatusReading

    init(reader: any AuthorizationStatusReading = LiveAuthorizationStatus()) {
        self.reader = reader
        // The Simulator can never authorize, so say so up front rather than after a confusing
        // `invalidArgument` failure.
        status = AuthorizationMapper.isRunningInSimulator ? .denied : reader.status
        blocker = AuthorizationMapper.isRunningInSimulator ? .simulatorUnsupported : nil
    }

    var isAuthorized: Bool { status.isAuthorized }

    var guidance: BlockerGuidance? {
        blocker.map(AuthorizationCopy.guidance(for:))
    }

    /// Re-reads status from the system.
    ///
    /// Called on every activation because authorization can change **without Lumo running** — the
    /// user can revoke it in Settings, which unshields everything at once. Trusting a cached value
    /// would leave the UI claiming apps are locked when they are wide open.
    func refresh() {
        guard !AuthorizationMapper.isRunningInSimulator else { return }
        let fresh = reader.status
        let wasAuthorized = status.isAuthorized
        status = fresh

        if wasAuthorized, !fresh.isAuthorized {
            // Surfaced rather than silently retried: the user's apps just became reachable, and
            // they deserve to know why.
            blocker = .notAuthorized
        } else if fresh.isAuthorized {
            blocker = nil
        }
    }

    /// Requests `.individual` authorization.
    ///
    /// `.individual` rather than `.child`: these are self-managing adults, which is the case Apple
    /// added it for. The tradeoff is accepted knowingly — under individual enrolment iOS
    /// *deliberately removes* the restrictions that would prevent app deletion, so a determined
    /// user can always uninstall Lumo and drop every shield. No API prevents that, and the
    /// friction literature suggests it is arguably the correct design anyway.
    func request() async {
        guard !AuthorizationMapper.isRunningInSimulator else {
            blocker = .simulatorUnsupported
            return
        }
        guard !isRequesting else { return }

        isRequesting = true
        defer { isRequesting = false }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            status = reader.status
            blocker = status.isAuthorized ? nil : .unknown
        } catch {
            status = reader.status
            blocker = AuthorizationMapper.blocker(for: error)
        }
    }
}
