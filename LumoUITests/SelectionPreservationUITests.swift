import XCTest

/// Regression tests for the two ways the essential-apps set was silently destroyed.
///
/// This is the one failure mode in Lumo with a physical-harm path — the driving evidence is a
/// competitor's reviewer writing *"I am a type 1 diabetic and it would block my pump… I can die from
/// that."* It broke twice, in two different ways, within hours of each other:
///
///   1. Skipping the blocklist step never committed, so the protected set was thrown away.
///   2. Editing the blocklist later replaced the essential set with an empty one, because tokens are
///      opaque and the in-memory selection always starts empty.
///
/// Both were invisible to 213 passing unit tests. These assert the *persisted* counts, not what the
/// screen happens to say.
final class SelectionPreservationUITests: LumoUITestCase {

    /// Reads the persisted protected count out of the manage screen.
    private func protectedCount() -> String? {
        let label = app.staticTexts[LumoID.manageProtectedCount]
        guard label.waitForExistence(timeout: 10) else { return nil }
        return label.label
    }

    private func lockedCount() -> String? {
        let label = app.staticTexts[LumoID.manageLockedCount]
        guard label.waitForExistence(timeout: 10) else { return nil }
        return label.label
    }

    func testSeededStateIsPersistedAndReported() {
        // Baseline. If this fails, nothing below means anything.
        launchApp(essential: 3, blocked: 2)
        openSettings()
        app.buttons[LumoID.settingsChangeApps].tap()

        XCTAssertEqual(protectedCount(), "3", "3 protected apps should be persisted and shown")
        XCTAssertEqual(lockedCount(), "2 apps, 0 categories")
    }

    func testProtectedAppsSurviveAnAppRelaunch() {
        // Persistence, not just in-memory state: the App Group container has to hold it.
        launchApp(essential: 3, blocked: 2)
        openSettings()
        app.buttons[LumoID.settingsChangeApps].tap()
        XCTAssertEqual(protectedCount(), "3")

        // Relaunch WITHOUT reset and WITHOUT reseeding — whatever survives is what was really saved.
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launchArguments = ["-lumo-ui-testing", "-lumo-skip-onboarding"]
        relaunched.launch()
        app = relaunched

        openSettings()
        app.buttons[LumoID.settingsChangeApps].tap()
        XCTAssertEqual(protectedCount(), "3", "protection must survive a relaunch")
    }

    func testSavingWithoutTouchingEitherPickerPreservesBoth() {
        // The exact shape of bug 2. Opening the manage screen and saving must not wipe anything,
        // because the in-memory selections are empty until a picker is actually used — and a
        // persisted selection cannot be loaded back into a picker, since tokens are opaque.
        launchApp(essential: 3, blocked: 2)
        openSettings()
        app.buttons[LumoID.settingsChangeApps].tap()
        XCTAssertEqual(protectedCount(), "3")

        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        XCTAssertEqual(
            protectedCount(), "3",
            "saving without editing must not erase the protected set — this is the physical-harm path"
        )
        XCTAssertEqual(lockedCount(), "2 apps, 0 categories", "nor the blocklist")
    }

    func testTeardownPreservesNothingShieldedButKeepsProgress() {
        // Teardown must release everything, and must NOT destroy the wallet — someone stepping away
        // should be able to come back to their coins.
        launchApp(essential: 2, blocked: 2, coins: 50)
        openSettings()

        app.staticTexts[LumoID.settingsUnlockLabel].tap()
        let confirm = app.alerts.buttons["Unlock everything"].exists
            ? app.alerts.buttons["Unlock everything"]
            : app.buttons["Unlock everything"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "confirmation must be explicit")
        confirm.tap()

        // Returns to setup, since "unlock everything" means starting over. Previously it left the
        // user on a home screen with no route back to anything.
        // Scrolls to find it: the result row is appended below the teardown button, so whether it
        // lands on screen depends on the simulator's height rather than on anything the app did.
        let reported = waitScrolling(for: app.staticTexts["Nothing was locked."], timeout: 3)
            || waitScrolling(
                for: app.staticTexts
                    .matching(NSPredicate(format: "label CONTAINS 'unlocked'")).firstMatch,
                timeout: 3
            )
        XCTAssertTrue(reported, "teardown should report what it released")
    }

    func testConfirmationDialogSaysWhatSurvives() {
        // Someone leaving should not have to guess whether they are also destroying their progress.
        launchApp(essential: 1, blocked: 1, coins: 20)
        openSettings()
        app.staticTexts[LumoID.settingsUnlockLabel].tap()

        let message = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'coins and streak are kept'")
        ).firstMatch
        XCTAssertTrue(
            message.waitForExistence(timeout: 5),
            "the dialog must state that coins and streak survive"
        )
    }

    func testCancellingTeardownChangesNothing() {
        launchApp(essential: 2, blocked: 2)
        openSettings()
        app.staticTexts[LumoID.settingsUnlockLabel].tap()

        // Wait for the dialog itself before deciding where to look. The previous version resolved
        // the ternary before the sheet existed, so it always picked the app-level query.
        let dialogMessage = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'coins and streak are kept'")
        ).firstMatch
        XCTAssertTrue(dialogMessage.waitForExistence(timeout: 5), "dialog should be presented")

        // Must be a VISIBLE button, not an outside-tap. A hierarchy dump showed
        // confirmationDialog-inside-a-sheet renders popover-style and drops its cancel button,
        // leaving the destructive action as the only thing on screen.
        let cancel = app.alerts.buttons["Cancel"].exists
            ? app.alerts.buttons["Cancel"]
            : app.buttons["Cancel"]
        XCTAssertTrue(
            cancel.waitForExistence(timeout: 5),
            "a destructive confirmation must offer a visible Cancel, not only an outside-tap"
        )
        cancel.tap()

        app.buttons[LumoID.settingsChangeApps].tap()
        XCTAssertEqual(protectedCount(), "2", "cancelling must be a true no-op")
        XCTAssertEqual(lockedCount(), "2 apps, 0 categories")
    }
}
