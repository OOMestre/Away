import AwayCore
import XCTest

private final class RecordingRestarter: DockRestarting, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var restarts: Int { lock.withLock { count } }
    func requestRestart() { lock.withLock { count += 1 } }
}

final class DockPreferencesStoreTests: XCTestCase {
    private var domain: InMemoryPreferencesDomain!
    private var backups: InMemoryDockBackupStore!
    private var restarter: RecordingRestarter!
    private var store: DockPreferencesStore!

    private let pinnedApps = PropertyListValue.array([.dictionary(["tile-type": .string("file-tile")])])

    override func setUp() {
        domain = InMemoryPreferencesDomain([
            "autohide": .bool(false),
            "tilesize": .int(48),
            "persistent-apps": pinnedApps,
        ])
        backups = InMemoryDockBackupStore()
        restarter = RecordingRestarter()
        store = DockPreferencesStore(domain: domain, backups: backups, restarter: restarter)
    }

    func testApplyWritesValuesAndRestartsOnce() async throws {
        let applied = try await store.apply([
            DockPreferenceChange(.autohide, .bool(true)),
            DockPreferenceChange(.autohideDelay, .double(0)),
        ])

        XCTAssertTrue(applied)
        XCTAssertEqual(domain.value(forKey: "autohide"), .bool(true))
        XCTAssertEqual(domain.value(forKey: "autohide-delay"), .double(0))
        XCTAssertEqual(domain.synchronizeCount, 1)
        XCTAssertEqual(restarter.restarts, 1)
    }

    func testApplyWithoutEffectiveChangesDoesNothing() async throws {
        let applied = try await store.apply([DockPreferenceChange(.autohide, .bool(false))])

        XCTAssertFalse(applied)
        XCTAssertEqual(restarter.restarts, 0)
        XCTAssertNil(try backups.loadOriginal())
        let canUndo = await store.canUndo
        XCTAssertFalse(canUndo)
    }

    func testRunningAppsOnlyCanBeTurnedOnOffAndUndone() async throws {
        try await store.apply([DockPreferenceChange(.staticOnly, .bool(true))])
        let enabled = await store.value(for: .staticOnly)
        XCTAssertEqual(enabled, .bool(true))

        try await store.apply([DockPreferenceChange(.staticOnly, .bool(false))])
        let disabled = await store.value(for: .staticOnly)
        XCTAssertEqual(disabled, .bool(false))

        try await store.undo()
        let restored = await store.value(for: .staticOnly)
        XCTAssertEqual(restored, .bool(true))

        try await store.undo()
        let original = await store.value(for: .staticOnly)
        XCTAssertNil(original)
        XCTAssertEqual(restarter.restarts, 4)
    }

    func testInstantAutoHideCanReturnToDefaultsAndBeUndone() async throws {
        try await store.apply([
            DockPreferenceChange(.autohide, .bool(true)),
            DockPreferenceChange(.autohideDelay, .double(0)),
            DockPreferenceChange(.autohideTimeModifier, .double(0)),
        ])

        XCTAssertEqual(domain.value(forKey: "autohide"), .bool(true))
        XCTAssertEqual(domain.value(forKey: "autohide-delay"), .double(0))
        XCTAssertEqual(domain.value(forKey: "autohide-time-modifier"), .double(0))
        XCTAssertEqual(restarter.restarts, 1)

        try await store.apply([
            DockPreferenceChange(.autohide, nil),
            DockPreferenceChange(.autohideDelay, nil),
            DockPreferenceChange(.autohideTimeModifier, nil),
        ])

        XCTAssertNil(domain.value(forKey: "autohide"))
        XCTAssertNil(domain.value(forKey: "autohide-delay"))
        XCTAssertNil(domain.value(forKey: "autohide-time-modifier"))
        XCTAssertEqual(restarter.restarts, 2)

        try await store.undo()
        XCTAssertEqual(domain.value(forKey: "autohide"), .bool(true))
        XCTAssertEqual(domain.value(forKey: "autohide-delay"), .double(0))
        XCTAssertEqual(domain.value(forKey: "autohide-time-modifier"), .double(0))
    }

    func testFirstApplyCapturesOriginalOnlyOnce() async throws {
        try await store.apply([DockPreferenceChange(.tileSize, .int(64))])
        try await store.apply([DockPreferenceChange(.tileSize, .int(32))])

        let original = try XCTUnwrap(backups.loadOriginal())
        XCTAssertEqual(original.values["tilesize"], .int(48))
        XCTAssertEqual(original.values["persistent-apps"], pinnedApps)
    }

    func testUndoRestoresPreviousValuesAndRemovesNewKeys() async throws {
        try await store.apply([
            DockPreferenceChange(.tileSize, .int(64)),
            DockPreferenceChange(.staticOnly, .bool(true)),
        ])

        let undone = try await store.undo()

        XCTAssertTrue(undone)
        XCTAssertEqual(domain.value(forKey: "tilesize"), .int(48))
        XCTAssertNil(domain.value(forKey: "static-only"))
        XCTAssertEqual(restarter.restarts, 2)
    }

    func testUndoIsStepByStepAndKeepsUnrelatedUserEdits() async throws {
        try await store.apply([DockPreferenceChange(.tileSize, .int(64))])
        try await store.apply([DockPreferenceChange(.tileSize, .int(32))])
        domain.setValue(.string("left"), forKey: "orientation")

        try await store.undo()
        XCTAssertEqual(domain.value(forKey: "tilesize"), .int(64))

        try await store.undo()
        XCTAssertEqual(domain.value(forKey: "tilesize"), .int(48))
        XCTAssertEqual(domain.value(forKey: "orientation"), .string("left"))

        let undoneAgain = try await store.undo()
        XCTAssertFalse(undoneAgain)
    }

    func testRestoreOriginalPutsBackTheWholeDomain() async throws {
        try await store.apply([
            DockPreferenceChange(.tileSize, .int(64)),
            DockPreferenceChange(.persistentApps, .array([])),
            DockPreferenceChange(.magnification, .bool(true)),
        ])

        let restored = try await store.restoreOriginal()

        XCTAssertTrue(restored)
        XCTAssertEqual(domain.allValues(), [
            "autohide": .bool(false),
            "tilesize": .int(48),
            "persistent-apps": pinnedApps,
        ])
        let canUndo = await store.canUndo
        XCTAssertFalse(canUndo)
    }

    func testRestoreOriginalWithoutBackupDoesNothing() async throws {
        let restored = try await store.restoreOriginal()
        XCTAssertFalse(restored)
        XCTAssertEqual(restarter.restarts, 0)
    }

    func testResetToSystemDefaultsKeepsPinnedItems() async throws {
        try await store.resetToSystemDefaults()

        XCTAssertEqual(domain.allValues(), ["persistent-apps": pinnedApps])

        try await store.undo()
        XCTAssertEqual(domain.value(forKey: "tilesize"), .int(48))
        XCTAssertEqual(domain.value(forKey: "autohide"), .bool(false))
    }

    func testHistoryIsCapped() async throws {
        for size in 0..<(DockPreferencesStore.historyLimit + 5) {
            try await store.apply([DockPreferenceChange(.tileSize, .int(size + 100))])
        }
        XCTAssertEqual(try backups.loadHistory().count, DockPreferencesStore.historyLimit)
    }
}

extension DockPreferencesStoreTests {
    func testUnrecordedChangesKeepUndoHistoryButTakeOriginalBackup() async throws {
        try await store.apply([DockPreferenceChange(.showProcessIndicators, .bool(false))], recordUndo: false)

        XCTAssertEqual(domain.value(forKey: "show-process-indicators"), .bool(false))
        XCTAssertNil(try backups.loadOriginal()?.values["show-process-indicators"])
        XCTAssertNotNil(try backups.loadOriginal())
        let canUndo = await store.canUndo
        XCTAssertFalse(canUndo)
    }
}
