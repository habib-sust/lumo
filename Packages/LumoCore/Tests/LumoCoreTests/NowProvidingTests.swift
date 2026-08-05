import Foundation
import Testing
@testable import LumoCore

@Suite("Clock seam")
struct NowProvidingTests {

    @Test("FixedNow never moves")
    func fixedNowIsStable() {
        let clock = FixedNow(.fixture)
        #expect(clock.now == .fixture)
        #expect(clock.now == clock.now)
    }

    @Test("MutableNow advances by exactly the requested interval")
    func mutableNowAdvances() {
        let clock = MutableNow(.fixture)
        clock.advance(by: 15 * 60)
        #expect(clock.now == Date.fixture.addingTimeInterval(900))
    }

    @Test("MutableNow accepts a backwards clock")
    func mutableNowGoesBackwards() {
        // Not a curiosity: the device clock is user-settable, which is why wall-clock
        // expiry is a cap rather than the sole defence. The reconciler has to cope.
        let clock = MutableNow(.fixture)
        clock.advance(by: -3600)
        #expect(clock.now < .fixture)
    }

    @Test("The Monday fixture really is a Monday in UTC")
    func fixtureIsMonday() throws {
        // The weekly grant is issued at local Monday midnight, so this fixture being a
        // Monday is load-bearing for the grant tests that come later.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        #expect(calendar.component(.weekday, from: .fixture) == 2) // 1 = Sunday
    }
}
