import AwayCore
import XCTest

private final class IndicatorRestarter: DockRestarting, @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.withLock { value } }
    func requestRestart() { lock.withLock { value += 1 } }
}

final class DockRunningIndicatorsTests: XCTestCase {
    private func makeSystem(_ native: PropertyListValue? = nil) -> (
        DockRunningIndicators, InMemoryPreferencesDomain, InMemoryPreferencesDomain, IndicatorRestarter
    ) {
        let dockDomain = InMemoryPreferencesDomain(native.map { ["show-process-indicators": $0] } ?? [:])
        let settings = InMemoryPreferencesDomain()
        let restarter = IndicatorRestarter()
        let dock = DockPreferencesStore(
            domain: dockDomain, backups: InMemoryDockBackupStore(), restarter: restarter
        )
        return (DockRunningIndicators(dock: dock, settings: settings), dockDomain, settings, restarter)
    }

    func testEnableAndDisableRestoreExplicitTrue() async throws {
        let (feature, dock, _, restarter) = makeSystem(.bool(true))
        try await feature.setEnabled(true)
        XCTAssertEqual(dock.value(forKey: "show-process-indicators"), .bool(false))
        try await feature.setEnabled(false)
        XCTAssertEqual(dock.value(forKey: "show-process-indicators"), .bool(true))
        XCTAssertEqual(restarter.count, 2)
    }

    func testEnableAndDisableRestoreAbsentKey() async throws {
        let (feature, dock, _, restarter) = makeSystem()
        try await feature.setEnabled(true)
        try await feature.setEnabled(false)
        XCTAssertNil(dock.value(forKey: "show-process-indicators"))
        XCTAssertEqual(restarter.count, 2)
    }

    func testSuspendAndResumePreserveChoiceAcrossRelaunch() async throws {
        let (feature, dockDomain, settings, restarter) = makeSystem(.bool(true))
        try await feature.setEnabled(true)
        try await feature.suspend()
        XCTAssertEqual(dockDomain.value(forKey: "show-process-indicators"), .bool(true))

        let reopenedDock = DockPreferencesStore(
            domain: dockDomain, backups: InMemoryDockBackupStore(), restarter: restarter
        )
        let reopened = DockRunningIndicators(dock: reopenedDock, settings: settings)
        try await reopened.resume()
        let reopenedEnabled = await reopened.isEnabled
        XCTAssertTrue(reopenedEnabled)
        XCTAssertEqual(dockDomain.value(forKey: "show-process-indicators"), .bool(false))
        try await reopened.setEnabled(false)
        XCTAssertEqual(dockDomain.value(forKey: "show-process-indicators"), .bool(true))
    }

    func testStyleAndColorPersistWithoutChangingDock() async {
        let (feature, dock, settings, restarter) = makeSystem()
        await feature.setStyle(.glow)
        await feature.setColorHex("#A1b2c3")
        await feature.setColorHex("invalid")
        let reopenedDock = DockPreferencesStore(
            domain: dock, backups: InMemoryDockBackupStore(), restarter: restarter
        )
        let reopened = DockRunningIndicators(dock: reopenedDock, settings: settings)
        let reopenedStyle = await reopened.style
        let reopenedColor = await reopened.colorHex
        XCTAssertEqual(reopenedStyle, .glow)
        XCTAssertEqual(reopenedColor, "#A1B2C3")
        XCTAssertEqual(restarter.count, 0)
    }
}
