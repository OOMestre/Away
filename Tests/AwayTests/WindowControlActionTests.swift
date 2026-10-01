import ApplicationServices
import AwayCore
import XCTest

private final class MockWindowService: WindowManaging, @unchecked Sendable {
    var storedWindows: [pid_t: [WindowInfo]] = [:]
    var closedWindows: [WindowInfo] = []
    var minimizedStates: [(window: WindowInfo, minimized: Bool)] = []
    var fullScreenStates: [(window: WindowInfo, fullScreen: Bool)] = []
    var focusedWindows: [WindowInfo] = []

    var shouldThrowOnClose = false
    var shouldThrowOnMinimize = false
    var shouldThrowOnFullScreen = false
    var shouldThrowOnFocus = false

    func windows(of pid: pid_t) -> [WindowInfo] {
        storedWindows[pid] ?? []
    }

    func focus(_ window: WindowInfo) throws {
        if shouldThrowOnFocus { throw WindowActionError.unsupported }
        focusedWindows.append(window)
    }

    func close(_ window: WindowInfo) throws {
        if shouldThrowOnClose { throw WindowActionError.unsupported }
        closedWindows.append(window)
    }

    func setMinimized(_ minimized: Bool, for window: WindowInfo) throws {
        if shouldThrowOnMinimize { throw WindowActionError.unsupported }
        minimizedStates.append((window, minimized))
    }

    func setFullScreen(_ fullScreen: Bool, for window: WindowInfo) throws {
        if shouldThrowOnFullScreen { throw WindowActionError.unsupported }
        fullScreenStates.append((window, fullScreen))
    }
}

final class WindowControlActionTests: XCTestCase {
    private func makeWindow(
        pid: pid_t = 100,
        title: String = "Test Window",
        frame: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600),
        isMinimized: Bool = false,
        isFullScreen: Bool = false
    ) -> WindowInfo {
        let dummyElement = AccessibilityElement.application(pid: pid)
        return WindowInfo(
            element: dummyElement,
            pid: pid,
            title: title,
            frame: frame,
            isMinimized: isMinimized,
            isFullScreen: isFullScreen,
            isStandard: true
        )
    }

    func testActionProperties() {
        XCTAssertEqual(WindowControlAction.allCases, [.close, .minimize, .fullScreen])

        XCTAssertEqual(WindowControlAction.close.title, "Close")
        XCTAssertEqual(WindowControlAction.close.systemImage, "xmark")

        XCTAssertEqual(WindowControlAction.minimize.title, "Minimize")
        XCTAssertEqual(WindowControlAction.minimize.systemImage, "minus")

        XCTAssertEqual(WindowControlAction.fullScreen.title, "Full Screen")
        XCTAssertEqual(WindowControlAction.fullScreen.systemImage, "arrow.up.left.and.arrow.down.right")
    }

    func testPerformCloseOnWindowInfo() throws {
        let mock = MockWindowService()
        let window = makeWindow()

        try mock.perform(.close, on: window)
        XCTAssertEqual(mock.closedWindows.count, 1)
        XCTAssertEqual(mock.closedWindows.first?.title, "Test Window")
    }

    func testPerformMinimizeTogglesState() throws {
        let mock = MockWindowService()

        let normalWindow = makeWindow(isMinimized: false)
        try mock.perform(.minimize, on: normalWindow)
        XCTAssertEqual(mock.minimizedStates.count, 1)
        XCTAssertTrue(mock.minimizedStates[0].minimized)

        let minimizedWindow = makeWindow(isMinimized: true)
        try mock.perform(.minimize, on: minimizedWindow)
        XCTAssertEqual(mock.minimizedStates.count, 2)
        XCTAssertFalse(mock.minimizedStates[1].minimized)
    }

    func testPerformFullScreenTogglesState() throws {
        let mock = MockWindowService()

        let normalWindow = makeWindow(isFullScreen: false)
        try mock.perform(.fullScreen, on: normalWindow)
        XCTAssertEqual(mock.fullScreenStates.count, 1)
        XCTAssertTrue(mock.fullScreenStates[0].fullScreen)

        let fullScreenWindow = makeWindow(isFullScreen: true)
        try mock.perform(.fullScreen, on: fullScreenWindow)
        XCTAssertEqual(mock.fullScreenStates.count, 2)
        XCTAssertFalse(mock.fullScreenStates[1].fullScreen)
    }

    func testPerformActionOnWindowPreviewItem() throws {
        let mock = MockWindowService()
        let window = makeWindow(pid: 200, title: "Notes Document")
        mock.storedWindows[200] = [window]

        let item = WindowPreviewItem(
            id: 1,
            processID: 200,
            title: "Notes Document",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600)
        )

        try mock.perform(.close, on: item)
        XCTAssertEqual(mock.closedWindows.count, 1)
        XCTAssertEqual(mock.closedWindows.first?.title, "Notes Document")

        try mock.focus(item)
        XCTAssertEqual(mock.focusedWindows.count, 1)
        XCTAssertEqual(mock.focusedWindows.first?.title, "Notes Document")
    }

    func testPerformActionThrowsWhenWindowNotFound() {
        let mock = MockWindowService()
        let item = WindowPreviewItem(
            id: 99,
            processID: 999,
            title: "Unknown",
            frame: .zero
        )

        XCTAssertThrowsError(try mock.perform(.close, on: item)) { error in
            XCTAssertEqual(error as? WindowActionError, .unsupported)
        }
    }

    func testErrorPropagation() {
        let mock = MockWindowService()
        mock.shouldThrowOnClose = true
        let window = makeWindow()

        XCTAssertThrowsError(try mock.perform(.close, on: window)) { error in
            XCTAssertEqual(error as? WindowActionError, .unsupported)
        }
    }

    func testFocusWindowPreviewItemWithDirectWindowInfo() throws {
        let mock = MockWindowService()
        let window = makeWindow(pid: 300, title: "Target Document")
        let item = WindowPreviewItem(window: window)

        try mock.focus(item)

        XCTAssertEqual(mock.focusedWindows.count, 1)
        XCTAssertEqual(mock.focusedWindows.first?.title, "Target Document")
        XCTAssertEqual(mock.focusedWindows.first?.pid, 300)
    }

    func testFocusSpecificWindowAmongMultipleWindowsOfSameProcess() throws {
        let mock = MockWindowService()
        let win1 = makeWindow(pid: 500, title: "Window 1", frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let win2 = makeWindow(pid: 500, title: "Window 2", frame: CGRect(x: 450, y: 0, width: 400, height: 300))
        let win3 = makeWindow(pid: 500, title: "Window 3", frame: CGRect(x: 900, y: 0, width: 400, height: 300))
        mock.storedWindows[500] = [win1, win2, win3]

        // User clicks on thumbnail for Window 2
        let item2 = WindowPreviewItem(window: win2, id: 2)
        try mock.focus(item2)

        // Only Window 2 should be focused, not the whole app or other windows
        XCTAssertEqual(mock.focusedWindows.count, 1)
        XCTAssertEqual(mock.focusedWindows.first?.title, "Window 2")

        // User clicks on thumbnail for Window 3
        let item3 = WindowPreviewItem(window: win3, id: 3)
        try mock.focus(item3)

        XCTAssertEqual(mock.focusedWindows.count, 2)
        XCTAssertEqual(mock.focusedWindows.last?.title, "Window 3")
    }

    func testFocusWindowWithIdenticalTitlesDistinguishesByDirectInfo() throws {
        let mock = MockWindowService()
        let winA = makeWindow(pid: 600, title: "Terminal", frame: CGRect(x: 10, y: 10, width: 500, height: 400))
        let winB = makeWindow(pid: 600, title: "Terminal", frame: CGRect(x: 600, y: 10, width: 500, height: 400))
        mock.storedWindows[600] = [winA, winB]

        let itemA = WindowPreviewItem(window: winA, id: 10)
        let itemB = WindowPreviewItem(window: winB, id: 20)

        // Clicking item B focuses winB specifically even though winA has the exact same title
        try mock.focus(itemB)
        XCTAssertEqual(mock.focusedWindows.count, 1)
        XCTAssertEqual(mock.focusedWindows.first?.frame, winB.frame)

        // Clicking item A focuses winA specifically
        try mock.focus(itemA)
        XCTAssertEqual(mock.focusedWindows.count, 2)
        XCTAssertEqual(mock.focusedWindows.last?.frame, winA.frame)
    }
}
