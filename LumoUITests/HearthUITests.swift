import XCTest

/// The home screen and the spend sheet.
///
/// Worth its own file because the hearth introduces a **second** `.sheet(item:)` presenter, and the
/// last one of those shipped a bug where the sheet dismissed itself on first tap. That regression
/// was invisible to 213 unit tests and only showed up on a physical device, so it gets a test here
/// rather than another device session.
final class HearthUITests: LumoUITestCase {

    private enum ID {
        static let balance = "home.balance"
        static let spendCancel = "spend.cancel"
        static func locked(_ slot: Int) -> String { "home.locked.\(slot)" }
        static func tier(_ index: Int) -> String { "spend.tier.\(index)" }
    }

    // MARK: - The hearth itself

    func testHearthShowsSeededBalance() {
        launchApp(blocked: 2, coins: 120)

        let balance = app.staticTexts[ID.balance]
        XCTAssertTrue(balance.waitForExistence(timeout: 10), "balance never rendered")
        // The element is the combined number-plus-caption, because that is what VoiceOver should
        // read as one thing — so this checks the number is in there rather than equalling the label.
        XCTAssertTrue(
            balance.label.contains("120"),
            "balance did not show the seeded coins, got: \(balance.label)"
        )
    }

    func testHearthWithNothingLockedStillOffersSettings() {
        // The empty state must not be a dead end. A user who declined Screen Time, or has not
        // picked anything yet, still needs the route to Settings and to teardown.
        launchApp(blocked: 0, coins: 0)

        XCTAssertTrue(
            app.staticTexts["No apps locked yet."].waitForExistence(timeout: 10),
            "empty hearth did not say so"
        )
        XCTAssertTrue(app.buttons[LumoID.homeSettings].exists, "no route to Settings from an empty hearth")
    }

    func testLockedAppsAppearForEverySeededBucket() {
        launchApp(blocked: 3, coins: 50)

        for slot in 0..<3 {
            XCTAssertTrue(
                app.buttons[ID.locked(slot)].waitForExistence(timeout: 10),
                "locked app in slot \(slot) missing from the hearth"
            )
        }
    }

    // MARK: - Sheet stability
    //
    // Both presenters on this screen, because the device bug was that the FIRST tap dismissed
    // itself and every subsequent one worked — so a test that only taps once, or only tests one
    // route, would have passed while the bug shipped.

    func testSettingsSheetSurvivesItsFirstTap() {
        launchApp(blocked: 2, coins: 50)
        tapAndAssertSheetStays(
            LumoID.homeSettings,
            expecting: app.buttons[LumoID.settingsChangeApps]
        )
    }

    func testSpendSheetSurvivesItsFirstTap() {
        launchApp(blocked: 2, coins: 200)
        tapAndAssertSheetStays(
            ID.locked(0),
            expecting: app.buttons[ID.spendCancel]
        )
    }

    func testSpendSheetReopensAfterDismissal() {
        launchApp(blocked: 2, coins: 200)

        // Both routes share one `.sheet(item:)`, so the identity has to change cleanly between
        // presentations. Open, close, open a DIFFERENT bucket — the case where a stale item would
        // show the wrong app or refuse to present at all.
        app.buttons[ID.locked(0)].tap()
        XCTAssertTrue(app.buttons[ID.spendCancel].waitForExistence(timeout: 5))
        app.buttons[ID.spendCancel].tap()

        let secondTile = app.buttons[ID.locked(1)]
        XCTAssertTrue(secondTile.waitForExistence(timeout: 5), "hearth did not come back")
        secondTile.tap()
        XCTAssertTrue(
            app.buttons[ID.spendCancel].waitForExistence(timeout: 5),
            "the spend sheet refused to present a second time"
        )
    }

    func testSwitchingFromSpendToSettingsWorks() {
        launchApp(blocked: 2, coins: 200)

        app.buttons[ID.locked(0)].tap()
        XCTAssertTrue(app.buttons[ID.spendCancel].waitForExistence(timeout: 5))
        app.buttons[ID.spendCancel].tap()

        // The other route through the same presenter, immediately after. If the item were not
        // cleared on dismiss this would either do nothing or reopen the spend sheet.
        tapAndAssertSheetStays(
            LumoID.homeSettings,
            expecting: app.buttons[LumoID.settingsChangeApps]
        )
    }

    // MARK: - The ladder

    func testAffordableTiersAreOfferedAndUnaffordableOnesAreNotHidden() {
        // Default pricing is 6 / 12 / 23 coins for 15 / 30 / 60 minutes, derived from the
        // conservative baseline at the bottom of the admissible band. 8 affords only the cheapest —
        // the point of the test is the boundary, so the seed has to sit on it.
        launchApp(blocked: 1, coins: 8)

        app.buttons[ID.locked(0)].tap()
        XCTAssertTrue(app.buttons[ID.tier(0)].waitForExistence(timeout: 5), "no tiers offered")

        // Shown-but-disabled rather than hidden. Hiding makes the economy look smaller than it is,
        // and the user cannot form a goal from an option they never see.
        let top = app.buttons[ID.tier(2)]
        XCTAssertTrue(top.exists, "the unaffordable tier was hidden instead of shown as a target")
        XCTAssertFalse(top.isEnabled, "an unaffordable tier was tappable")
    }

    func testEmptyWalletIsNotADeadEnd() {
        launchApp(blocked: 1, coins: 0)

        app.buttons[ID.locked(0)].tap()
        XCTAssertTrue(
            app.staticTexts["Not enough yet. Finish something and come back."]
                .waitForExistence(timeout: 5),
            "an empty wallet produced no explanation"
        )
        XCTAssertTrue(app.buttons[ID.spendCancel].exists, "no way out of the spend sheet")
    }
}
