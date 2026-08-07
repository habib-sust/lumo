import XCTest

/// Regression tests for the UI-flow bugs that only appeared on a real device.
///
/// Each one names the bug it exists to catch. Between them they cover five of the eight bugs found
/// during the first hardware session — the five that were reachable by tapping. The other three
/// (monitor lock contention, slot reuse inheriting a window, the stubbed spend handler) are not
/// tappable and stay covered by unit tests and the device matrix.
final class SettingsUITests: LumoUITestCase {

    // MARK: - Sheets attached to List Sections dismissed themselves on first tap

    func testChangeAppsSheetSurvivesFirstTap() {
        launchApp()
        openSettings()

        // The original bug: presented, then vanished on the FIRST tap only, because each sheet was
        // attached to its own List Section rather than to a stable container.
        tapAndAssertSheetStays(
            LumoID.settingsChangeApps,
            expecting: app.buttons[LumoID.managePickEssential]
        )
    }

    func testDiagnosticsSheetSurvivesFirstTap() {
        launchApp()
        openSettings()
        // Probes a row that only the debug panel renders. An identifier on `navigationTitle`
        // attaches to the List rather than a queryable container, so it was never findable.
        tapAndAssertSheetStays(
            LumoID.settingsShowDiagnostics,
            expecting: app.staticTexts["App Group"]
        )
    }

    func testBothSheetsUsableInOneSession() {
        // The two sheets share a single presenter now. If that ever regresses to one-per-Section,
        // opening the second after the first is where it shows.
        launchApp()
        openSettings()

        app.buttons[LumoID.settingsChangeApps].tap()
        XCTAssertTrue(app.buttons[LumoID.managePickEssential].waitForExistence(timeout: 5))
        app.buttons[LumoID.manageDone].tap()

        let diagnostics = app.buttons[LumoID.settingsShowDiagnostics]
        XCTAssertTrue(diagnostics.waitForExistence(timeout: 5), "returned to Settings")
        diagnostics.tap()
        XCTAssertTrue(
            app.staticTexts["App Group"].waitForExistence(timeout: 5),
            "second sheet should open after the first has been dismissed"
        )
    }

    // MARK: - There was no route back to the pickers at all

    func testSettingsExposesARouteToBothPickers() {
        // After the first setup, hasCompletedSetup latched and there was no way to reach either
        // picker again. A blocklist you cannot edit is not a usable product.
        launchApp()
        openSettings()

        XCTAssertTrue(
            app.buttons[LumoID.settingsChangeApps].waitForExistence(timeout: 10),
            "Settings must offer a way to change apps"
        )
        app.buttons[LumoID.settingsChangeApps].tap()

        XCTAssertTrue(app.buttons[LumoID.managePickEssential].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[LumoID.managePickBlocked].exists)
    }

    // MARK: - The escape hatch must always be present

    func testUnlockEverythingIsAlwaysVisible() {
        // Competitor reviews include "impossible to delete: the app hides the delete button".
        // This is an ethical requirement, a review-score requirement, and an App Review requirement.
        launchApp(essential: 2, blocked: 3)
        openSettings()

        let teardown = app.staticTexts[LumoID.settingsUnlockLabel]
        XCTAssertTrue(
            teardown.waitForExistence(timeout: 10),
            "the teardown row must never be buried or conditional"
        )
        XCTAssertTrue(
            app.staticTexts["Opens every locked app immediately. No passcode needed."].exists,
            "the promise that it needs no passcode must be stated before tapping"
        )
    }

    func testHonestyPanelStatesTheLimits() {
        // Shipped deliberately: every competitor eats one-star reviews for platform behaviour they
        // never explain. These three claims are load-bearing and must not quietly disappear.
        launchApp()
        openSettings()

        XCTAssertTrue(app.staticTexts["Lumo can't see what you do"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Locking isn't unbreakable"].exists)
        XCTAssertTrue(app.staticTexts["Lumo is an ongoing arrangement"].exists)
    }

    // MARK: - Diagnostics

    func testDiagnosticsReportsSeededState() {
        // Also proves the seam itself works, so the tests below can trust their own setup.
        launchApp(essential: 3, blocked: 2, coins: 100)
        openSettings()
        app.buttons[LumoID.settingsShowDiagnostics].tap()

        XCTAssertTrue(app.staticTexts["App Group"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Buckets"].exists)
        XCTAssertTrue(app.staticTexts["Essential"].exists)
        // The App Group must resolve, or nothing cross-process works at all.
        XCTAssertTrue(app.staticTexts["OK"].exists, "App Group should resolve in the Simulator")
    }
}
