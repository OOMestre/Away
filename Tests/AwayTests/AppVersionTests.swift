import AwayCore
import XCTest

final class AppVersionTests: XCTestCase {
    func testParsesPlainAndPrefixedVersions() {
        XCTAssertEqual(AppVersion("1.2.3")?.description, "1.2.3")
        XCTAssertEqual(AppVersion("v1.2.3")?.description, "1.2.3")
        XCTAssertEqual(AppVersion("v1.2.3-beta.4")?.prerelease, "beta.4")
    }

    func testRejectsMalformedVersions() {
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("1.2"))
        XCTAssertNil(AppVersion("1.2.x"))
    }

    func testOrdering() throws {
        let beta1 = try XCTUnwrap(AppVersion("1.0.0-beta.1"))
        let beta10 = try XCTUnwrap(AppVersion("1.0.0-beta.10"))
        let stable = try XCTUnwrap(AppVersion("1.0.0"))
        let patch = try XCTUnwrap(AppVersion("1.0.1"))

        XCTAssertLessThan(beta1, beta10)
        XCTAssertLessThan(beta10, stable)
        XCTAssertLessThan(stable, patch)
    }
}

final class CustomizationAreaTests: XCTestCase {
    func testDockIsTheFirstAvailableArea() {
        XCTAssertEqual(CustomizationArea.allCases.first, .dock)
        XCTAssertEqual(CustomizationArea.allCases.filter(\.isAvailable), [.dock])
    }
}
