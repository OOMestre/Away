import AwayCore
import XCTest

final class FileDockBackupStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "AwayTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testPersistsOriginalAndHistory() throws {
        let store = FileDockBackupStore(directory: directory)
        XCTAssertNil(try store.loadOriginal())
        XCTAssertEqual(try store.loadHistory(), [])

        let original = DockBackup(date: Date(timeIntervalSince1970: 1), values: ["tilesize": .int(48), "autohide": .bool(true)])
        let entry = DockUndoEntry(date: Date(timeIntervalSince1970: 2), previousValues: ["tilesize": .double(0.5)], absentKeys: ["static-only"])
        try store.saveOriginal(original)
        try store.saveHistory([entry])

        let reloaded = FileDockBackupStore(directory: directory)
        XCTAssertEqual(try reloaded.loadOriginal(), original)
        XCTAssertEqual(try reloaded.loadHistory(), [entry])
    }
}

final class CoalescingDockRestarterTests: XCTestCase {
    func testBurstOfRequestsRestartsOnce() async throws {
        let restarted = expectation(description: "restart")
        restarted.assertForOverFulfill = true
        let restarter = CoalescingDockRestarter(delay: .milliseconds(50)) { restarted.fulfill() }

        for _ in 0..<10 {
            restarter.requestRestart()
        }

        await fulfillment(of: [restarted], timeout: 2)
        // Give a wrongly scheduled second restart the chance to fire.
        try await Task.sleep(for: .milliseconds(200))
    }
}

final class DockGeometryTests: XCTestCase {
    func testConvertsBetweenAXAndAppKitCoordinates() {
        let ax = CGRect(x: 100, y: 1000, width: 400, height: 80)
        let appKit = ScreenCoordinates.appKitRect(fromAX: ax, primaryScreenHeight: 1080)

        XCTAssertEqual(appKit, CGRect(x: 100, y: 0, width: 400, height: 80))
        XCTAssertEqual(ScreenCoordinates.axRect(fromAppKit: appKit, primaryScreenHeight: 1080), ax)
    }

    func testInfersOrientation() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        XCTAssertEqual(DockOrientation(listFrame: CGRect(x: 600, y: 1000, width: 700, height: 70), screenFrame: screen), .bottom)
        XCTAssertEqual(DockOrientation(listFrame: CGRect(x: 0, y: 200, width: 70, height: 600), screenFrame: screen), .left)
        XCTAssertEqual(DockOrientation(listFrame: CGRect(x: 1850, y: 200, width: 70, height: 600), screenFrame: screen), .right)
    }

    func testMapsDockItemSubroles() {
        XCTAssertEqual(DockItemKind(subrole: "AXApplicationDockItem"), .application)
        XCTAssertEqual(DockItemKind(subrole: "AXSpacerDockItem"), .spacer)
        XCTAssertEqual(DockItemKind(subrole: "AXTrashDockItem"), .trash)
        XCTAssertEqual(DockItemKind(subrole: "AXSomethingNew"), .other("AXSomethingNew"))
        XCTAssertEqual(DockItemKind(subrole: nil), .other(""))
    }

    func testUserContentKeys() {
        XCTAssertEqual(DockPreferenceKey.allCases.filter(\.isUserContent), [.persistentApps, .persistentOthers])
    }
}
