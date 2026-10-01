import AwayCore
import XCTest

final class AppResponsivenessTests: XCTestCase {
    func testRequiresConsecutiveTimeoutsAndRecovers() {
        var tracker = UnresponsiveAppTracker()
        XCTAssertEqual(tracker.update(results: [42: .timedOut], activePIDs: [42]), [])
        XCTAssertEqual(tracker.update(results: [42: .timedOut], activePIDs: [42]), [42])
        XCTAssertEqual(tracker.update(results: [42: .responsive], activePIDs: [42]), [])
        XCTAssertEqual(tracker.update(results: [42: .timedOut], activePIDs: [42]), [])
    }

    func testUnavailableAndExitedAppsNeverRemainAlerted() {
        var tracker = UnresponsiveAppTracker()
        _ = tracker.update(results: [42: .timedOut], activePIDs: [42])
        XCTAssertEqual(tracker.update(results: [42: .unavailable], activePIDs: [42]), [])
        _ = tracker.update(results: [42: .timedOut], activePIDs: [42])
        XCTAssertEqual(tracker.update(results: [42: .timedOut], activePIDs: [42]), [42])
        XCTAssertEqual(tracker.update(results: [:], activePIDs: []), [])
        XCTAssertEqual(tracker.update(results: [42: .timedOut], activePIDs: [42]), [])
    }
}
