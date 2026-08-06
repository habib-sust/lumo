import Foundation
import Testing
@testable import LumoCore

/// T-AUTH-01…12.
@Suite("Authorization status and recovery copy")
struct AuthorizationTests {

    // MARK: - The approvedWithDataAccess trap

    @Test("Both approved cases are authorized")
    func bothApprovedCasesAuthorize() {
        // The whole reason `== .approved` is banned repo-wide. iOS 26.4 added a fourth case, so
        // an equality test silently disables shielding for anyone who granted MORE access than
        // we asked for.
        #expect(LumoAuthorizationStatus.approved.isAuthorized)
        #expect(LumoAuthorizationStatus.approvedWithDataAccess.isAuthorized)
        #expect(!LumoAuthorizationStatus.denied.isAuthorized)
        #expect(!LumoAuthorizationStatus.notDetermined.isAuthorized)
    }

    @Test("Every status is classified — no case falls through")
    func everyStatusIsClassified() {
        // If Apple adds a fifth case, `isAuthorized`'s exhaustive switch stops compiling, which
        // is the point. This test asserts the enum is fully enumerated today.
        for status in LumoAuthorizationStatus.allCases {
            _ = status.isAuthorized
            _ = status.canRequestInApp
        }
        #expect(LumoAuthorizationStatus.allCases.count == 4)
    }

    @Test("Only notDetermined can be prompted in-app")
    func onlyNotDeterminedIsPromptable() {
        // Offering a "grant access" button to a `denied` user shows a prompt that never appears —
        // iOS requires a trip to Settings. A button that silently does nothing is worse than
        // saying so.
        #expect(LumoAuthorizationStatus.notDetermined.canRequestInApp)
        #expect(!LumoAuthorizationStatus.denied.canRequestInApp)
        #expect(!LumoAuthorizationStatus.approved.canRequestInApp)
        #expect(!LumoAuthorizationStatus.approvedWithDataAccess.canRequestInApp)
    }

    // MARK: - Guidance table

    @Test("Every blocker has guidance", arguments: AuthorizationBlocker.allCases)
    func everyBlockerHasGuidance(blocker: AuthorizationBlocker) {
        let g = AuthorizationCopy.guidance(for: blocker)
        #expect(!g.title.isEmpty, "\(blocker) has no title")
        #expect(!g.explanation.isEmpty, "\(blocker) has no explanation")
    }

    @Test("Every blocker's copy is distinct")
    func guidanceIsDistinct() {
        // A generic "something went wrong" here strands the user at the one screen they must get
        // past, because each of these has a genuinely different fix.
        let titles = AuthorizationBlocker.allCases.map { AuthorizationCopy.guidance(for: $0).title }
        #expect(Set(titles).count == titles.count, "duplicate titles: \(titles)")

        let explanations = AuthorizationBlocker.allCases
            .map { AuthorizationCopy.guidance(for: $0).explanation }
        #expect(Set(explanations).count == explanations.count)
    }

    @Test("A retryable blocker offers a concrete next step", arguments: AuthorizationBlocker.allCases)
    func retryableBlockersAreActionable(blocker: AuthorizationBlocker) {
        let g = AuthorizationCopy.guidance(for: blocker)
        if g.isRetryable {
            #expect(g.actionLabel != nil, "\(blocker) is retryable but offers no action")
        } else {
            // Non-retryable must NOT dangle a button that will fail again.
            #expect(g.actionLabel == nil, "\(blocker) is not retryable but offers an action")
        }
    }

    @Test("Any blocker pointing at Settings names the exact path")
    func settingsPathsAreSpecific() {
        // "Check your Settings" is not a next step. Every Settings hop spells out the path as the
        // user sees it.
        for blocker in AuthorizationBlocker.allCases {
            let g = AuthorizationCopy.guidance(for: blocker)
            if g.actionLabel == "Open Settings" {
                let path = try? #require(g.settingsPath)
                #expect(path?.contains("Settings") == true, "\(blocker) says Open Settings with no path")
            }
        }
    }

    @Test("The escape hatch exists and is never empty")
    func escapeHatchExists() {
        // Guideline 5.1.2(i): an app may not require a system capability to be usable. Lumo has
        // to work with Screen Time declined, and a flow that dead-ends here is a plausible
        // rejection — as well as being how an app earns a one-star review.
        #expect(!AuthorizationCopy.continueWithoutLocking.isEmpty)
    }

    // MARK: - Tone

    @Test("Cancellation is not framed as an error")
    func cancellationIsNotAnError() {
        // The user made a choice. Pestering them is how a permission prompt becomes the reason
        // someone deletes the app.
        let g = AuthorizationCopy.guidance(for: .canceled)
        #expect(g.isRetryable, "must remain offerable later")
        for word in ["error", "failed", "problem occurred", "denied"] {
            #expect(!g.title.lowercased().contains(word))
            #expect(!g.explanation.lowercased().contains(word))
        }
    }

    @Test("No blocker copy shames or blames the user")
    func copyDoesNotShame() {
        // Shaming copy is directly cited in competitors' one- and two-star reviews as the reason
        // for uninstalling, so this is a product requirement rather than a style note.
        let banned = ["you failed", "you should have", "your fault", "wasted", "lazy", "addicted"]
        for blocker in AuthorizationBlocker.allCases {
            let g = AuthorizationCopy.guidance(for: blocker)
            let text = (g.title + " " + g.explanation).lowercased()
            for phrase in banned {
                #expect(!text.contains(phrase), "\(blocker) copy contains '\(phrase)'")
            }
        }
    }

    @Test("Revocation copy reassures that coins and streak survive")
    func revocationCopyReassures() {
        // Losing Screen Time access unlocks every app at once, which looks exactly like losing
        // your progress. Saying otherwise, explicitly, is cheap.
        let g = AuthorizationCopy.guidance(for: .notAuthorized)
        let text = g.explanation.lowercased()
        #expect(text.contains("coins") || text.contains("streak"))
    }

    @Test("Simulator guidance states the platform limit plainly")
    func simulatorGuidanceIsExplicit() {
        // Costs hours if you assume your code is broken rather than the platform.
        let g = AuthorizationCopy.guidance(for: .simulatorUnsupported)
        #expect(g.explanation.lowercased().contains("simulator"))
        #expect(!g.isRetryable, "retrying in the Simulator can never work")
    }

    @Test("Device-restricted guidance does not promise a fix that does not exist")
    func restrictedGuidanceIsHonest() {
        // MDM or supervision is set by whoever manages the device. Offering a retry would be a
        // lie the user discovers by tapping it.
        let g = AuthorizationCopy.guidance(for: .deviceRestricted)
        #expect(!g.isRetryable)
        #expect(g.settingsPath == nil)
    }
}
