import AwayCore
import XCTest

private struct NoopRestarter: DockRestarting {
    func requestRestart() {}
}

final class DockSpacerLayoutTests: XCTestCase {
    private let app = PropertyListValue.dictionary([
        "tile-type": .string("file-tile"),
        "tile-data": .dictionary(["file-label": .string("Safari"), "custom": .int(42)]),
    ])

    func testAddMoveAndRemovePreserveOtherTiles() throws {
        var layout = try DockSpacerLayout(.array([app]))
        try layout.edit(.add(.large))
        try layout.edit(.add(.small))
        XCTAssertEqual(layout.spacerSize(at: 1), .large)
        XCTAssertEqual(layout.spacerSize(at: 2), .small)

        try layout.edit(.move(2, 0))
        XCTAssertEqual(layout.items[1], app)
        XCTAssertEqual(layout.spacerSize(at: 0), .small)

        try layout.edit(.remove(2))
        XCTAssertEqual(layout.items, [
            .dictionary(["tile-type": .string("small-spacer-tile"), "tile-data": .dictionary([:])]),
            app,
        ])
    }

    func testCannotMoveOrRemoveAnAppOrInvalidIndex() throws {
        var layout = try DockSpacerLayout(.array([app]))
        XCTAssertThrowsError(try layout.edit(.remove(0)))
        XCTAssertThrowsError(try layout.edit(.move(0, 0)))
        XCTAssertThrowsError(try layout.edit(.move(9, 0)))
        XCTAssertEqual(layout.items, [app])
    }

    func testMalformedListIsRejectedWithoutEditing() {
        XCTAssertThrowsError(try DockSpacerLayout(nil))
        XCTAssertThrowsError(try DockSpacerLayout(.string("unexpected")))
        XCTAssertThrowsError(try DockSpacerLayout(.array([.int(1)])))
    }

    func testMissingListIsNotReplacedWithOnlyASpacer() async throws {
        let domain = InMemoryPreferencesDomain()
        let backups = InMemoryDockBackupStore()
        let store = DockPreferencesStore(domain: domain, backups: backups, restarter: NoopRestarter())

        do {
            try await store.editSpacers(in: .apps, expected: nil, .add(.large))
            XCTFail("Expected the missing list to be rejected")
        } catch DockSpacerError.missingDockItems {
            XCTAssertNil(domain.value(forKey: "persistent-apps"))
            XCTAssertNil(try backups.loadOriginal())
        }
    }

    func testFoldersSideCanBeEditedWithoutChangingApps() async throws {
        let apps = PropertyListValue.array([app])
        let others = PropertyListValue.array([.dictionary(["tile-type": .string("directory-tile")])])
        let domain = InMemoryPreferencesDomain([
            "persistent-apps": apps,
            "persistent-others": others,
        ])
        let store = DockPreferencesStore(
            domain: domain,
            backups: InMemoryDockBackupStore(),
            restarter: NoopRestarter()
        )

        try await store.editSpacers(in: .others, expected: others, .add(.small))
        XCTAssertEqual(domain.value(forKey: "persistent-apps"), apps)
        let result = try DockSpacerLayout(domain.value(forKey: "persistent-others"))
        XCTAssertEqual(result.spacerSize(at: 1), .small)
    }

    func testStoreRejectsStaleEditAndUndoRestoresOriginalList() async throws {
        let original = PropertyListValue.array([app])
        let domain = InMemoryPreferencesDomain(["persistent-apps": original])
        let backups = InMemoryDockBackupStore()
        let store = DockPreferencesStore(domain: domain, backups: backups, restarter: NoopRestarter())
        let snapshot = try await store.spacerLayout(for: .apps)

        try await store.editSpacers(in: .apps, expected: snapshot.original, .add(.large))
        let changed = try DockSpacerLayout(domain.value(forKey: "persistent-apps"))
        XCTAssertEqual(changed.spacerSize(at: 1), .large)
        try await store.undo()
        XCTAssertEqual(domain.value(forKey: "persistent-apps"), original)

        domain.setValue(.array([app, .dictionary(["tile-type": .string("file-tile")])]), forKey: "persistent-apps")
        do {
            try await store.editSpacers(in: .apps, expected: snapshot.original, .add(.small))
            XCTFail("Expected stale edit to be rejected")
        } catch DockSpacerError.dockChanged {
            XCTAssertEqual(domain.value(forKey: "persistent-apps"), .array([app, .dictionary(["tile-type": .string("file-tile")])]))
        }
    }
}
