import AwayCore
import CoreGraphics
import XCTest

final class DockPreviewSettingsTests: XCTestCase {
    func testDefaultSettings() {
        let settings = DockPreviewSettings()
        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.hoverDelay, 0.3)
        XCTAssertEqual(settings.thumbnailWidth, 220)
        XCTAssertTrue(settings.showTitles)
        XCTAssertTrue(settings.showWindowButtons)
    }

    func testClampsHoverDelayAndThumbnailWidth() {
        let clampedMin = DockPreviewSettings(
            hoverDelay: 0.001,
            thumbnailWidth: 50
        )
        XCTAssertEqual(clampedMin.hoverDelay, DockPreviewSettings.minHoverDelay)
        XCTAssertEqual(clampedMin.thumbnailWidth, DockPreviewSettings.minThumbnailWidth)

        let clampedMax = DockPreviewSettings(
            hoverDelay: 100,
            thumbnailWidth: 1000
        )
        XCTAssertEqual(clampedMax.hoverDelay, DockPreviewSettings.maxHoverDelay)
        XCTAssertEqual(clampedMax.thumbnailWidth, DockPreviewSettings.maxThumbnailWidth)
    }

    func testGeometryCalculatesBottomDock() {
        let dockItem = CGRect(x: 400, y: 10, width: 64, height: 64)
        let panelSize = CGSize(width: 300, height: 200)
        let visibleScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)

        let frame = DockPreviewGeometry.panelFrame(
            for: dockItem,
            panelSize: panelSize,
            orientation: .bottom,
            screenVisibleFrame: visibleScreen,
            offset: 8
        )

        // MidX of dockItem is 432. Half of panel width is 150. Origin x should be 282.
        XCTAssertEqual(frame.origin.x, 282)
        // MaxY of dockItem is 74 + 8 = 82.
        XCTAssertEqual(frame.origin.y, 82)
        XCTAssertEqual(frame.size, panelSize)
    }

    func testGeometryClampsToScreenBounds() {
        let dockItem = CGRect(x: 10, y: 10, width: 64, height: 64)
        let panelSize = CGSize(width: 300, height: 200)
        let visibleScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)

        let frame = DockPreviewGeometry.panelFrame(
            for: dockItem,
            panelSize: panelSize,
            orientation: .bottom,
            screenVisibleFrame: visibleScreen,
            offset: 8
        )

        // Clamped at screen minX + offset = 8
        XCTAssertEqual(frame.origin.x, 8)
    }

    func testGeometryCalculatesLeftDock() {
        let dockItem = CGRect(x: 0, y: 400, width: 64, height: 64)
        let panelSize = CGSize(width: 300, height: 200)
        let visibleScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)

        let frame = DockPreviewGeometry.panelFrame(
            for: dockItem,
            panelSize: panelSize,
            orientation: .left,
            screenVisibleFrame: visibleScreen,
            offset: 8
        )

        // MaxX of dockItem is 64 + 8 = 72
        XCTAssertEqual(frame.origin.x, 72)
        // MidY of dockItem is 432. Half of panel height is 100. Origin y should be 332
        XCTAssertEqual(frame.origin.y, 332)
        XCTAssertEqual(frame.size, panelSize)
    }

    func testGeometryCalculatesRightDock() {
        let dockItem = CGRect(x: 1376, y: 400, width: 64, height: 64)
        let panelSize = CGSize(width: 300, height: 200)
        let visibleScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)

        let frame = DockPreviewGeometry.panelFrame(
            for: dockItem,
            panelSize: panelSize,
            orientation: .right,
            screenVisibleFrame: visibleScreen,
            offset: 8
        )

        // MinX of dockItem is 1376 - 300 - 8 = 1068
        XCTAssertEqual(frame.origin.x, 1068)
        // MidY of dockItem is 432. Half of panel height is 100. Origin y should be 332
        XCTAssertEqual(frame.origin.y, 332)
        XCTAssertEqual(frame.size, panelSize)
    }

    @MainActor
    func testSettingsStorePersistence() {
        let suite = "test.dock.previews.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = DockPreviewSettingsStore(defaults: defaults)
        XCTAssertTrue(store.settings.isEnabled)
        XCTAssertEqual(store.settings.hoverDelay, 0.3)

        store.settings.isEnabled = false
        store.settings.hoverDelay = 0.55
        store.settings.thumbnailWidth = 280
        store.settings.showTitles = false

        // Create a new store from the same defaults to verify persistence
        let reloaded = DockPreviewSettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.settings.isEnabled)
        XCTAssertEqual(reloaded.settings.hoverDelay, 0.55, accuracy: 0.001)
        XCTAssertEqual(reloaded.settings.thumbnailWidth, 280)
        XCTAssertFalse(reloaded.settings.showTitles)
    }
}
