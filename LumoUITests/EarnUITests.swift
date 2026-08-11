import XCTest

/// The earning half of the loop.
///
/// Written because this path shipped as fully-tested LumoCore logic with **zero call sites** — the
/// wallet could only ever be zero and every price in the app was theoretical. Unit tests proved the
/// award maths and said nothing about whether anything called it, which is exactly the gap a UI
/// test closes.
final class EarnUITests: LumoUITestCase {

    private enum ID {
        static let earn = "home.earn"
        static let running = "home.running"
        static let balance = "home.balance"
        static let add = "habits.add"
        static let newName = "newHabit.name"
        static let newAdd = "newHabit.add"
        static let logSave = "log.save"
        static let finish = "timer.finish"
        static let pause = "timer.pause"
        static let elapsed = "timer.elapsed"
        static let awardTotal = "award.total"
        static let awardDismiss = "award.dismiss"
    }

    /// Creates a habit with a 1-minute target, so a retroactive log can clear the standard.
    private func addHabit(named name: String) {
        button(ID.earn).tap()
        button(ID.add).tap()

        let field = app.textFields[ID.newName]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "new-habit form never appeared")
        field.tap()
        field.typeText(name)

        // The stepper defaults to 10; step it down so a short logged session meets the target.
        let stepper = app.steppers.firstMatch
        if stepper.exists { stepper.buttons.element(boundBy: 0).tap() }

        button(ID.newAdd).tap()
    }

    func testCreatingAHabitAndSeeingItListed() {
        launchApp()
        addHabit(named: "Dishes")

        XCTAssertTrue(
            app.staticTexts["Dishes"].waitForExistence(timeout: 5),
            "the habit was not listed after being created"
        )
    }

    func testEmptyHabitListExplainsItself() {
        launchApp()
        button(ID.earn).tap()

        XCTAssertTrue(
            app.staticTexts["Nothing here yet."].waitForExistence(timeout: 5),
            "an empty habit list said nothing"
        )
    }

    // MARK: - The whole point

    func testLoggingASessionActuallyPaysCoins() {
        launchApp()
        // NOT zero: a fresh install is granted the week's house allowance immediately, which is
        // the designed floor — there is always some way past a shield, even in a bad week. So this
        // measures the delta rather than the absolute.
        let before = balanceValue()
        XCTAssertGreaterThanOrEqual(before, 0, "balance unreadable")

        addHabit(named: "Dishes")

        // Log 10 minutes against a 5-minute target: clears the standard, so it pays.
        app.buttons["Log it"].firstMatch.tap()
        button(ID.logSave).tap()

        // The award sheet is the competence feedback, and it must appear — a silent credit is the
        // bare-counter design the reward literature says undermines.
        XCTAssertTrue(
            app.staticTexts[ID.awardTotal].waitForExistence(timeout: 5),
            "no award feedback after a qualifying session"
        )
        button(ID.awardDismiss).tap()

        // Back on the hearth: the balance must actually have moved. This is the assertion that
        // would have caught GrantCycle and CoinAward having no callers.
        let after = balanceValue()
        XCTAssertGreaterThan(
            after, before,
            "a completed session paid nothing — is CoinAward actually called?"
        )
    }

    func testShortSessionEarnsNothingButIsNotFramedAsFailure() {
        launchApp()
        button(ID.earn).tap()
        button(ID.add).tap()

        let field = app.textFields[ID.newName]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Long thing")
        // Leave the target at its 10-minute default and log 1 minute against it.
        button(ID.newAdd).tap()

        app.buttons["Log it"].firstMatch.tap()
        let stepper = app.steppers.firstMatch
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        for _ in 0..<3 { stepper.buttons.element(boundBy: 0).tap() }
        button(ID.logSave).tap()

        // Performance-contingent: below the user's own target it pays nothing. But the copy must
        // stay informational — "this still counts toward today", never "you failed".
        let stillCounts = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'still counts'")).firstMatch
        XCTAssertTrue(
            waitScrolling(for: stillCounts),
            "a short session should be explained, not silently ignored"
        )
        XCTAssertFalse(
            app.staticTexts[ID.awardTotal].exists,
            "a session below target paid coins it should not have"
        )
    }

    // MARK: - The timer

    func testStartingATimerShowsItOnTheHearth() {
        launchApp()
        addHabit(named: "Reading")

        app.buttons.matching(NSPredicate(format: "label == 'Start'")).firstMatch.tap()
        app.buttons["Done"].tap()

        // The running session has to be visible from the home screen, or a backgrounded timer is
        // invisible and the user starts a second one.
        XCTAssertTrue(
            button(ID.running).waitForExistence(timeout: 5),
            "a running timer was not surfaced on the hearth"
        )
    }

    func testTimerSurvivesRelaunch() {
        launchApp()
        addHabit(named: "Reading")
        app.buttons.matching(NSPredicate(format: "label == 'Start'")).firstMatch.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(button(ID.running).waitForExistence(timeout: 5))

        // Relaunch WITHOUT resetting: the timer is persisted precisely so a session survives the
        // app being killed, which is the whole reason pausing is useful at all.
        launchApp(reset: false)

        XCTAssertTrue(
            button(ID.running).waitForExistence(timeout: 10),
            "the running timer did not survive a relaunch"
        )
    }

    func testPauseAndFinish() {
        launchApp()
        addHabit(named: "Reading")
        app.buttons.matching(NSPredicate(format: "label == 'Start'")).firstMatch.tap()
        app.buttons["Done"].tap()

        button(ID.running).tap()
        XCTAssertTrue(app.staticTexts[ID.elapsed].waitForExistence(timeout: 5), "no elapsed clock")

        button(ID.pause).tap()
        XCTAssertTrue(
            app.staticTexts["Paused"].waitForExistence(timeout: 3), "pause was not reflected")

        button(ID.finish).tap()
        // A few seconds is below any target, so this settles without paying — the assertion is that
        // finishing works at all and returns the user to a hearth with no running session.
        XCTAssertTrue(
            button(ID.earn).waitForExistence(timeout: 10),
            "after finishing, the hearth should offer earning again"
        )
    }

    // MARK: - Helpers

    private func balanceValue() -> Int {
        let element = app.staticTexts[ID.balance]
        guard element.waitForExistence(timeout: 10) else { return -1 }
        // The label is the combined "N, caption" element, so take the leading digits.
        let digits = element.label.prefix { $0.isNumber }
        return Int(digits) ?? -1
    }
}
