import AppKit
import AwayCore
import XCTest

@MainActor
final class DockPreviewCoordinatorTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settingsStore: DockPreviewSettingsStore!
    private var mockCapturer: MockWindowCapturer!
    private var mockWindowManager: MockWindowManager!
    private var mockPermissions: MockPermissionsService!
    private var mockLocator: MockDockLocator!
    private var mockPresenter: MockDockPreviewPresenter!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "test.coordinator.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settingsStore = DockPreviewSettingsStore(defaults: defaults)
        settingsStore.settings.hoverDelay = 0.05
        mockCapturer = MockWindowCapturer()
        mockWindowManager = MockWindowManager()
        mockPermissions = MockPermissionsService()
        mockLocator = MockDockLocator()
        mockPresenter = MockDockPreviewPresenter()
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    private func makeCoordinator(monitor: DockHoverMonitor) -> DockPreviewCoordinator {
        let coordinator = DockPreviewCoordinator(
            dockHover: monitor,
            settingsStore: settingsStore,
            thumbnailService: mockCapturer,
            windowManager: mockWindowManager,
            permissions: mockPermissions,
            dockItems: mockLocator,
            presenter: mockPresenter
        )
        coordinator.processID = { _ in 999 }
        return coordinator
    }

    private let musicItem = DockItem(
        index: 2,
        kind: .application,
        title: "Music",
        frame: CGRect(x: 200, y: 10, width: 48, height: 48),
        url: nil,
        isRunning: true
    )

    func testHoverOpensPanelWithWindowsAfterDelay() async {
        settingsStore.settings.hoverDelay = 0.05
        mockCapturer.windowsToReturn = [
            WindowPreviewItem(id: 1, processID: 999, title: "Doc", frame: CGRect(x: 0, y: 0, width: 600, height: 400))
        ]
        let coordinator = makeCoordinator(monitor: DockHoverMonitor())

        coordinator.dockHoverChanged(to: musicItem)
        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(mockPresenter.isVisible)
        XCTAssertEqual(coordinator.currentWindows.map(\.id), [1])
    }

    func testAppWithoutWindowsOpensOnlyWhenAllowed() async {
        settingsStore.settings.hoverDelay = 0.05
        mockCapturer.windowsToReturn = []
        let coordinator = makeCoordinator(monitor: DockHoverMonitor())

        coordinator.dockHoverChanged(to: musicItem)
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(mockPresenter.isVisible)

        coordinator.showsWithoutWindows = { $0.title == "Music" }
        coordinator.dockHoverChanged(to: nil)
        coordinator.dockHoverChanged(to: musicItem)
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(mockPresenter.isVisible)
    }

    func testIgnoredAppDoesNotOpen() async {
        settingsStore.settings.hoverDelay = 0.05
        mockCapturer.windowsToReturn = [
            WindowPreviewItem(id: 1, processID: 999, title: "Doc", frame: CGRect(x: 0, y: 0, width: 600, height: 400))
        ]
        let coordinator = makeCoordinator(monitor: DockHoverMonitor())
        let safari = DockItem(index: 1, kind: .application, title: "Safari", frame: .zero,
                              url: URL(fileURLWithPath: "/Applications/Safari.app"), isRunning: true)
        coordinator.ignoredBundleIdentifiers = ["com.apple.Safari"]

        coordinator.dockHoverChanged(to: safari)
        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(mockPresenter.isVisible)
        XCTAssertEqual(mockCapturer.previewableWindowsCalledCount, 0)
    }

    func testHoverOnNonRunningItemDoesNotOpen() async {
        let monitor = DockHoverMonitor()
        let coordinator = DockPreviewCoordinator(
            dockHover: monitor,
            settingsStore: settingsStore,
            thumbnailService: mockCapturer,
            windowManager: mockWindowManager,
            permissions: mockPermissions,
            dockItems: mockLocator,
            presenter: mockPresenter
        )

        let nonRunningItem = DockItem(
            index: 0,
            kind: .application,
            title: "Safari",
            frame: CGRect(x: 100, y: 10, width: 48, height: 48),
            url: URL(fileURLWithPath: "/Applications/Safari.app"),
            isRunning: false
        )

        coordinator.dockHoverChanged(to: nonRunningItem)
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(mockCapturer.previewableWindowsCalledCount, 0)
        XCTAssertFalse(mockPresenter.isVisible)
    }

    func testHoverOnNonApplicationItemDoesNotOpen() async {
        let monitor = DockHoverMonitor()
        let coordinator = DockPreviewCoordinator(
            dockHover: monitor,
            settingsStore: settingsStore,
            thumbnailService: mockCapturer,
            windowManager: mockWindowManager,
            permissions: mockPermissions,
            dockItems: mockLocator,
            presenter: mockPresenter
        )

        let trashItem = DockItem(
            index: 5,
            kind: .trash,
            title: "Trash",
            frame: CGRect(x: 500, y: 10, width: 48, height: 48),
            url: nil,
            isRunning: true
        )

        coordinator.dockHoverChanged(to: trashItem)
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(mockCapturer.previewableWindowsCalledCount, 0)
        XCTAssertFalse(mockPresenter.isVisible)
    }

    func testHoverOutBeforeDelayCancelsOpen() async {
        let monitor = DockHoverMonitor()
        settingsStore.settings.hoverDelay = 0.3

        let coordinator = DockPreviewCoordinator(
            dockHover: monitor,
            settingsStore: settingsStore,
            thumbnailService: mockCapturer,
            windowManager: mockWindowManager,
            permissions: mockPermissions,
            dockItems: mockLocator,
            presenter: mockPresenter
        )

        let item = DockItem(
            index: 1,
            kind: .application,
            title: "TestApp",
            frame: CGRect(x: 200, y: 10, width: 48, height: 48),
            url: nil,
            isRunning: true
        )

        // Hover starts
        coordinator.dockHoverChanged(to: item)

        // Mouse leaves after 50ms (before 300ms delay)
        try? await Task.sleep(for: .milliseconds(50))
        coordinator.dockHoverChanged(to: nil)

        // Wait another 300ms
        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(mockCapturer.previewableWindowsCalledCount, 0)
        XCTAssertFalse(mockPresenter.isVisible)
    }

    func testDisabledPreviewsIgnoreHover() async {
        let monitor = DockHoverMonitor()
        settingsStore.settings.isEnabled = false

        let coordinator = DockPreviewCoordinator(
            dockHover: monitor,
            settingsStore: settingsStore,
            thumbnailService: mockCapturer,
            windowManager: mockWindowManager,
            permissions: mockPermissions,
            dockItems: mockLocator,
            presenter: mockPresenter
        )

        let item = DockItem(
            index: 1,
            kind: .application,
            title: "TestApp",
            frame: CGRect(x: 200, y: 10, width: 48, height: 48),
            url: nil,
            isRunning: true
        )

        coordinator.dockHoverChanged(to: item)
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(mockCapturer.previewableWindowsCalledCount, 0)
        XCTAssertFalse(mockPresenter.isVisible)
    }

    func testHoverDelayClosesWhenMouseLeavesBothDockAndPanel() async {
        let monitor = DockHoverMonitor()
        settingsStore.settings.hoverDelay = 0.05

        mockCapturer.windowsToReturn = [
            WindowPreviewItem(
                id: 1,
                processID: 999,
                title: "Doc 1",
                frame: CGRect(x: 0, y: 0, width: 600, height: 400)
            )
        ]

        let coordinator = DockPreviewCoordinator(
            dockHover: monitor,
            settingsStore: settingsStore,
            thumbnailService: mockCapturer,
            windowManager: mockWindowManager,
            permissions: mockPermissions,
            dockItems: mockLocator,
            presenter: mockPresenter
        )

        // Hover out triggers dismissal after grace period
        coordinator.dockHoverChanged(to: nil)
        try? await Task.sleep(for: .milliseconds(250))

        XCTAssertFalse(mockPresenter.isVisible)
    }

    func testActionCloseRemovesWindowAndHidesWhenEmpty() {
        let monitor = DockHoverMonitor()
        let coordinator = DockPreviewCoordinator(
            dockHover: monitor,
            settingsStore: settingsStore,
            thumbnailService: mockCapturer,
            windowManager: mockWindowManager,
            permissions: mockPermissions,
            dockItems: mockLocator,
            presenter: mockPresenter
        )

        let window = WindowPreviewItem(
            id: 1,
            processID: 100,
            title: "To Close",
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )

        mockPresenter.shownWindows = [window]
        mockPresenter.isVisible = true

        coordinator.handleAction(.close, on: window)

        // Should hide presenter when windows become empty
        XCTAssertFalse(mockPresenter.isVisible)
    }

    func testSelectWindowFocusesSpecificWindowAndHidesPanel() {
        let monitor = DockHoverMonitor()
        let coordinator = DockPreviewCoordinator(
            dockHover: monitor,
            settingsStore: settingsStore,
            thumbnailService: mockCapturer,
            windowManager: mockWindowManager,
            permissions: mockPermissions,
            dockItems: mockLocator,
            presenter: mockPresenter
        )

        let dummyElement = AccessibilityElement.application(pid: 250)
        let windowInfo = WindowInfo(
            element: dummyElement,
            pid: 250,
            title: "Specific Window",
            frame: CGRect(x: 10, y: 10, width: 800, height: 600),
            isMinimized: false,
            isFullScreen: false,
            isStandard: true
        )
        let windowItem = WindowPreviewItem(window: windowInfo, id: 42)

        mockPresenter.shownWindows = [windowItem]
        mockPresenter.isVisible = true

        // User clicks on thumbnail
        coordinator.selectWindow(windowItem)

        // Panel must immediately hide
        XCTAssertFalse(mockPresenter.isVisible)
        // Specific window must be focused
        XCTAssertEqual(mockWindowManager.focusedWindow?.pid, 250)
        XCTAssertEqual(mockWindowManager.focusedWindow?.title, "Specific Window")
    }
}

// MARK: - Mocks for Hermetic Tests

private final class MockDockPreviewPresenter: DockPreviewPresenting, @unchecked Sendable {
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var isVisible: Bool = false
    var shownWindows: [WindowPreviewItem] = []
    var shownThumbnails: [CGWindowID: CGImage] = [:]

    func show(
        item: DockItem,
        windows: [WindowPreviewItem],
        thumbnails: [CGWindowID: CGImage],
        targetFrame: CGRect,
        settings: DockPreviewSettings,
        hasScreenRecording: Bool,
        onSelect: @escaping (WindowPreviewItem) -> Void,
        onAction: @escaping (WindowControlAction, WindowPreviewItem) -> Void,
        onRequestScreenRecording: @escaping () -> Void
    ) {
        isVisible = true
        shownWindows = windows
        shownThumbnails = thumbnails
    }

    func update(windows: [WindowPreviewItem], thumbnails: [CGWindowID: CGImage]) {
        shownWindows = windows
        shownThumbnails = thumbnails
    }

    func hide(animated: Bool) {
        isVisible = false
        shownWindows = []
        shownThumbnails = [:]
    }
}

private final class MockWindowCapturer: WindowThumbnailCapturing, @unchecked Sendable {
    var previewableWindowsCalledCount = 0
    var windowsToReturn: [WindowPreviewItem] = []

    func previewableWindows(for processID: pid_t) async throws -> [WindowPreviewItem] {
        previewableWindowsCalledCount += 1
        return windowsToReturn
    }

    func captureThumbnail(for windowID: CGWindowID, targetSize: CGSize) async throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: 10,
            height: 10,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            throw WindowCaptureError.captureFailed("Mock context failed")
        }
        return image
    }
}

private final class MockWindowManager: WindowManaging, @unchecked Sendable {
    var focusedWindow: WindowInfo?
    var closedWindow: WindowInfo?

    func windows(of pid: pid_t) -> [WindowInfo] { [] }
    func focus(_ window: WindowInfo) throws { focusedWindow = window }
    func close(_ window: WindowInfo) throws { closedWindow = window }
    func setMinimized(_ minimized: Bool, for window: WindowInfo) throws {}
    func setFullScreen(_ fullScreen: Bool, for window: WindowInfo) throws {}
}

private final class MockPermissionsService: PermissionChecking, @unchecked Sendable {
    var screenRecordingStatus: PermissionStatus = .granted

    func status(of permission: Permission) -> PermissionStatus {
        if permission == .screenRecording { return screenRecordingStatus }
        return .granted
    }

    func request(_ permission: Permission) {}
    func openSystemSettings(for permission: Permission) {}
}

private final class MockDockLocator: DockItemLocating, @unchecked Sendable {
    func items() -> [DockItem] { [] }
    func listFrame() -> CGRect? { CGRect(x: 100, y: 0, width: 800, height: 70) }
}
