import XCTest

/// Accessibility identifiers, mirrored from the app target.
///
/// Duplicated rather than shared because these are black-box tests: adding a package dependency to
/// the UI test target for eight strings would be more machinery than the duplication costs. If one
/// drifts, the corresponding test fails loudly at its `waitForExistence`, which is the failure mode
/// you want.
enum LumoID {
    static let homeSettings = "home.settings"
    static let settingsChangeApps = "settings.changeApps"
    static let settingsShowDiagnostics = "settings.showDiagnostics"
    static let settingsUnlockLabel = "settings.unlockEverything.label"
    static let managePickEssential = "manage.pickEssential"
    static let managePickBlocked = "manage.pickBlocked"
    static let manageDone = "manage.done"
    static let manageLockedCount = "manage.lockedCount"
    static let manageProtectedCount = "manage.protectedCount"
    static let debugRoot = "debug.root"
}

/// Shared harness.
///
/// Every test launches a **fresh, explicitly seeded** app rather than inheriting whatever the last
/// one left behind. Half the confusion during the device debugging session came from stale state
/// masquerading as new behaviour, so these tests refuse to depend on ordering.
class LumoUITestCase: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        // A failure mid-flow leaves the app in an unknown state; there is nothing to salvage by
        // continuing, and cascading failures obscure the real one.
        continueAfterFailure = false
    }

    /// Launches with a known state.
    ///
    /// `FamilyActivityPicker` is a system out-of-process view that does not function in the
    /// Simulator and returns opaque tokens that cannot be synthesised — so selections are seeded via
    /// launch arguments instead. That keeps the assertions that actually matter (does re-picking one
    /// list wipe the other, does a sheet survive its first tap) runnable in CI.
    @discardableResult
    func launchApp(
        essential: Int = 0,
        blocked: Int = 0,
        coins: Int = 0,
        skipOnboarding: Bool = true,
        reset: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-lumo-ui-testing"]
        if reset { args.append("-lumo-reset") }
        if skipOnboarding { args.append("-lumo-skip-onboarding") }
        if essential > 0 { args += ["-lumo-seed-essential", "\(essential)"] }
        if blocked > 0 { args += ["-lumo-seed-blocked", "\(blocked)"] }
        if coins > 0 { args += ["-lumo-seed-coins", "\(coins)"] }
        app.launchArguments = args
        app.launch()
        self.app = app
        return app
    }

    // MARK: - Navigation helpers

    func openSettings(file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[LumoID.homeSettings]
        XCTAssertTrue(
            button.waitForExistence(timeout: 10),
            "Settings entry point never appeared — the escape hatch must always be reachable",
            file: file, line: line
        )
        button.tap()
    }

    /// Waits for an element, scrolling the screen if it has not been laid out yet.
    ///
    /// A `List` is a lazy collection view: rows below the fold are not merely off-screen, they do
    /// not exist in the accessibility tree at all. So a plain `waitForExistence` on a lower row
    /// passes on a tall simulator and fails on a short one — which is exactly what happened here,
    /// with the same commit green on iPhone 17 and red on iPhone 17 Pro. A test whose result
    /// depends on the device it ran on is not testing what it claims to, and the failure it
    /// produces names the wrong thing.
    @discardableResult
    func waitScrolling(for element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        if element.waitForExistence(timeout: timeout) { return true }
        for _ in 0..<4 {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) { return true }
        }
        return false
    }

    /// Finds a button, scrolling to it if necessary. Fails the test by name if it never appears.
    @discardableResult
    func button(
        _ identifier: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let element = app.buttons[identifier]
        if !waitScrolling(for: element) {
            XCTFail("\(identifier) not found, even after scrolling", file: file, line: line)
        }
        return element
    }

    /// Taps a row and asserts the sheet is *still* there a moment later.
    ///
    /// The delay is the entire point. A sheet attached to an unstable host (a `List` Section, for
    /// instance) presents and then tears itself down on the next render pass, so an immediate
    /// existence check passes while the user sees it flash and vanish.
    func tapAndAssertSheetStays(
        _ identifier: String,
        expecting probe: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let row = button(identifier, file: file, line: line)
        XCTAssertTrue(row.exists, "\(identifier) not found", file: file, line: line)
        row.tap()

        XCTAssertTrue(
            probe.waitForExistence(timeout: 5),
            "sheet for \(identifier) never appeared",
            file: file, line: line
        )
        // Give SwiftUI several render passes to do the wrong thing.
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(
            probe.exists,
            "sheet for \(identifier) appeared and then dismissed itself — this is the regression where a presenter was attached to a List Section",
            file: file, line: line
        )
    }
}
