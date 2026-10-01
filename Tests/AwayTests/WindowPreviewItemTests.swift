import AwayCore
import CoreGraphics
import XCTest

final class WindowPreviewItemTests: XCTestCase {
    func testWindowPreviewItemProperties() {
        let item = WindowPreviewItem(
            id: 101,
            processID: 555,
            title: "Away Window",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            isFullScreen: false,
            isOnScreen: true
        )

        XCTAssertEqual(item.id, 101)
        XCTAssertEqual(item.processID, 555)
        XCTAssertEqual(item.title, "Away Window")
        XCTAssertEqual(item.frame.width, 800)
        XCTAssertEqual(item.frame.height, 600)
        XCTAssertFalse(item.isMinimized)
        XCTAssertFalse(item.isFullScreen)
        XCTAssertTrue(item.isOnScreen)
    }

    func testWindowPreviewItemEquality() {
        let item1 = WindowPreviewItem(
            id: 42,
            processID: 100,
            title: "Test",
            frame: CGRect(x: 0, y: 0, width: 200, height: 100)
        )
        let item2 = WindowPreviewItem(
            id: 42,
            processID: 100,
            title: "Test",
            frame: CGRect(x: 0, y: 0, width: 200, height: 100)
        )
        let item3 = WindowPreviewItem(
            id: 43,
            processID: 100,
            title: "Different",
            frame: CGRect(x: 0, y: 0, width: 200, height: 100)
        )

        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
    }

    func testWindowCaptureErrorDescriptions() {
        let notFound = WindowCaptureError.windowNotFound(99)
        XCTAssertTrue(notFound.localizedDescription.contains("99"))

        let failed = WindowCaptureError.captureFailed("TCC denied")
        XCTAssertTrue(failed.localizedDescription.contains("TCC denied"))

        let denied = WindowCaptureError.permissionDenied
        XCTAssertTrue(denied.localizedDescription.contains("Screen Recording"))
    }

    func testMockThumbnailCapturer() async throws {
        let capturer = MockThumbnailCapturer()
        let windows = try await capturer.previewableWindows(for: 123)
        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0].title, "Document 1")

        let thumbnail = try await capturer.captureThumbnail(for: 1, targetSize: CGSize(width: 200, height: 120))
        XCTAssertEqual(thumbnail.width, 10)
        XCTAssertEqual(thumbnail.height, 10)
    }

    func testWindowPreviewItemInitFromWindowInfo() {
        let dummy = AccessibilityElement.application(pid: 777)
        let window = WindowInfo(
            element: dummy,
            pid: 777,
            title: "Code Editor",
            frame: CGRect(x: 20, y: 30, width: 900, height: 700),
            isMinimized: false,
            isFullScreen: true,
            isStandard: true
        )
        let item = WindowPreviewItem(window: window, id: 999)

        XCTAssertEqual(item.id, 999)
        XCTAssertEqual(item.processID, 777)
        XCTAssertEqual(item.title, "Code Editor")
        XCTAssertEqual(item.frame.width, 900)
        XCTAssertFalse(item.isMinimized)
        XCTAssertTrue(item.isFullScreen)
        XCTAssertEqual(item.windowInfo, window)
    }
}

private final class MockThumbnailCapturer: WindowThumbnailCapturing, @unchecked Sendable {
    func previewableWindows(for processID: pid_t) async throws -> [WindowPreviewItem] {
        [
            WindowPreviewItem(
                id: 1,
                processID: processID,
                title: "Document 1",
                frame: CGRect(x: 0, y: 0, width: 800, height: 600)
            ),
            WindowPreviewItem(
                id: 2,
                processID: processID,
                title: "Document 2",
                frame: CGRect(x: 50, y: 50, width: 800, height: 600)
            )
        ]
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
        ) else {
            throw WindowCaptureError.captureFailed("Context allocation failed")
        }
        guard let image = context.makeImage() else {
            throw WindowCaptureError.captureFailed("Image creation failed")
        }
        return image
    }
}

final class WindowMatcherTests: XCTestCase {
    private let left = CGRect(x: 0, y: 25, width: 800, height: 600)
    private let right = CGRect(x: 820, y: 25, width: 800, height: 600)

    func testPrefersPositionOverSharedTitle() {
        let candidates: [(frame: CGRect?, title: String)] = [(left, "Downloads"), (right, "Downloads")]
        XCTAssertEqual(WindowMatcher.match(frame: right, title: "Downloads", in: candidates), 1)
    }

    func testUsesTitleToBreakPositionTies() {
        let candidates: [(frame: CGRect?, title: String)] = [(left, "A"), (left, "B")]
        XCTAssertEqual(WindowMatcher.match(frame: left, title: "B", in: candidates), 1)
    }

    func testFallsBackToUniqueTitleWhenWindowMoved() {
        let candidates: [(frame: CGRect?, title: String)] = [(nil, "Inbox"), (right, "Drafts")]
        XCTAssertEqual(WindowMatcher.match(frame: left, title: "Inbox", in: candidates), 0)
    }

    func testReturnsNilWithoutEvidence() {
        let candidates: [(frame: CGRect?, title: String)] = [(right, "Same"), (nil, "Same")]
        XCTAssertNil(WindowMatcher.match(frame: left, title: "Same", in: candidates))
        XCTAssertNil(WindowMatcher.match(frame: left, title: nil, in: candidates))
    }
}
