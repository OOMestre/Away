import AwayCore
import XCTest

final class WindowTitleFormatterTests: XCTestCase {
    func testCleanStripsLineBreaksAndTabs() {
        let input = "  Window\nTitle\r\nWith\tTabs  "
        let expected = "Window Title With Tabs"
        XCTAssertEqual(WindowTitleFormatter.clean(input), expected)
    }

    func testCleanPreservesNormalSpacing() {
        let input = "Safari — GitHub — Away"
        XCTAssertEqual(WindowTitleFormatter.clean(input), "Safari — GitHub — Away")
    }

    func testDisplayTitleWithValidTitle() {
        let result = WindowTitleFormatter.displayTitle(for: "Document.swift", fallbackAppName: "Xcode")
        XCTAssertEqual(result, "Document.swift")
    }

    func testDisplayTitleFallsBackToAppNameWhenTitleIsEmpty() {
        let result = WindowTitleFormatter.displayTitle(for: "", fallbackAppName: "Finder")
        XCTAssertEqual(result, "Finder")
    }

    func testDisplayTitleFallsBackToAppNameWhenTitleIsWhitespace() {
        let result = WindowTitleFormatter.displayTitle(for: "   \n\t  ", fallbackAppName: "Notes")
        XCTAssertEqual(result, "Notes")
    }

    func testDisplayTitleFallsBackToUntitledWhenBothEmpty() {
        let result1 = WindowTitleFormatter.displayTitle(for: "", fallbackAppName: nil)
        XCTAssertEqual(result1, "Untitled")

        let result2 = WindowTitleFormatter.displayTitle(for: "   ", fallbackAppName: "  ")
        XCTAssertEqual(result2, "Untitled")
    }

    func testTruncateKeepsShortTextUntouched() {
        let text = "Away Settings"
        XCTAssertEqual(WindowTitleFormatter.truncate(text, maxLength: 20), "Away Settings")
    }

    func testTruncateKeepsExactLengthUntouched() {
        let text = "12345"
        XCTAssertEqual(WindowTitleFormatter.truncate(text, maxLength: 5), "12345")
    }

    func testTruncateAppendsEllipsisWhenLonger() {
        let text = "This is a very long window title that should be truncated"
        let truncated = WindowTitleFormatter.truncate(text, maxLength: 20)
        XCTAssertEqual(truncated.count, 20)
        XCTAssertTrue(truncated.hasSuffix("…"))
        XCTAssertEqual(truncated, "This is a very long…")
    }

    func testTruncateCustomEllipsis() {
        let text = "A very long title here"
        let truncated = WindowTitleFormatter.truncate(text, maxLength: 15, ellipsis: "...")
        XCTAssertLessThanOrEqual(truncated.count, 15)
        XCTAssertTrue(truncated.hasSuffix("..."))
        XCTAssertEqual(truncated, "A very long...")
    }

    func testTruncateEdgeCases() {
        XCTAssertEqual(WindowTitleFormatter.truncate("Hello", maxLength: 0), "")
        XCTAssertEqual(WindowTitleFormatter.truncate("Hello", maxLength: -1), "")
        XCTAssertEqual(WindowTitleFormatter.truncate("Hello", maxLength: 1, ellipsis: "..."), ".")
        XCTAssertEqual(WindowTitleFormatter.truncate("Hello", maxLength: 3, ellipsis: "..."), "...")
    }

    func testTruncateUnicodeAndEmojis() {
        let text = "🚀 Away — Customização Completa do macOS"
        let truncated = WindowTitleFormatter.truncate(text, maxLength: 15)
        XCTAssertEqual(truncated.count, 15)
        XCTAssertTrue(truncated.hasPrefix("🚀 Away —"))
        XCTAssertTrue(truncated.hasSuffix("…"))
    }

    func testIsTruncated() {
        XCTAssertFalse(WindowTitleFormatter.isTruncated("Short", maxLength: 10))
        XCTAssertFalse(WindowTitleFormatter.isTruncated("Exact", maxLength: 5))
        XCTAssertTrue(WindowTitleFormatter.isTruncated("Longer text", maxLength: 5))
        XCTAssertFalse(WindowTitleFormatter.isTruncated("Any text", maxLength: 0))
    }
}
