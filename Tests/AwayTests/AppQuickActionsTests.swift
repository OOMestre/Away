import AwayCore
import XCTest

private final class PIDRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [pid_t] = []
    var values: [pid_t] { lock.withLock { recorded } }
    func record(_ pid: pid_t) { lock.withLock { recorded.append(pid) } }
}

final class AppQuickActionsTests: XCTestCase {
    private var lookupCalls: [pid_t] = []
    private var checkerCalls: [pid_t] = []
    private var launcherCalls: [URL] = []
    private var menuTriggerCalls: [pid_t] = []

    private var mockAppTerminated = false
    private var terminateCallCount = 0
    private var forceTerminateCallCount = 0
    private var activateCallCount = 0

    private func makeSampleApp(pid: pid_t, isTerminated: Bool = false) -> SystemAppQuickActionService.RunningAppInfo {
        SystemAppQuickActionService.RunningAppInfo(
            processIdentifier: pid,
            bundleURL: URL(fileURLWithPath: "/Applications/TestApp.app"),
            localizedName: "TestApp",
            isTerminated: isTerminated || mockAppTerminated,
            terminateHandler: { [weak self] in
                self?.terminateCallCount += 1
                self?.mockAppTerminated = true
                return true
            },
            forceTerminateHandler: { [weak self] in
                self?.forceTerminateCallCount += 1
                self?.mockAppTerminated = true
                return true
            },
            activateHandler: { [weak self] in
                self?.activateCallCount += 1
            }
        )
    }

    func testIsResponsiveReturnsTrueForResponsiveApp() {
        let service = SystemAppQuickActionService(
            processLookup: { [weak self] pid in
                self?.lookupCalls.append(pid)
                return self?.makeSampleApp(pid: pid)
            },
            accessibilityChecker: { [weak self] pid in
                self?.checkerCalls.append(pid)
                return true
            }
        )

        XCTAssertTrue(service.isResponsive(pid: 1234))
        XCTAssertEqual(lookupCalls, [1234])
        XCTAssertEqual(checkerCalls, [1234])
    }

    func testIsResponsiveReturnsFalseForHungApp() {
        let service = SystemAppQuickActionService(
            processLookup: { [weak self] pid in
                self?.lookupCalls.append(pid)
                return self?.makeSampleApp(pid: pid)
            },
            accessibilityChecker: { [weak self] pid in
                self?.checkerCalls.append(pid)
                return false // Simulates AXError.cannotComplete
            }
        )

        XCTAssertFalse(service.isResponsive(pid: 1234))
        XCTAssertEqual(lookupCalls, [1234])
        XCTAssertEqual(checkerCalls, [1234])
    }

    func testIsResponsiveReturnsFalseForTerminatedOrUnknownApp() {
        let service = SystemAppQuickActionService(
            processLookup: { _ in nil },
            accessibilityChecker: { _ in true }
        )

        XCTAssertFalse(service.isResponsive(pid: 9999))
        XCTAssertFalse(service.isResponsive(pid: -1))
    }

    func testOpenNewWindowTriggersMenuActionWhenAvailable() async throws {
        let shortcuts = PIDRecorder()
        let service = SystemAppQuickActionService(
            processLookup: { [weak self] pid in
                self?.makeSampleApp(pid: pid)
            },
            menuActionTrigger: { [weak self] pid in
                self?.menuTriggerCalls.append(pid)
                return true
            },
            newWindowShortcut: { shortcuts.record($0) }
        )

        try await service.openNewWindow(for: 1234)

        XCTAssertEqual(menuTriggerCalls, [1234])
        XCTAssertEqual(activateCallCount, 1)
        XCTAssertTrue(shortcuts.values.isEmpty)
        XCTAssertTrue(launcherCalls.isEmpty)
    }

    func testOpenNewWindowSendsShortcutOnlyWhenMenuActionUnavailable() async throws {
        let shortcuts = PIDRecorder()
        let service = SystemAppQuickActionService(
            processLookup: { [weak self] pid in
                self?.makeSampleApp(pid: pid)
            },
            appLauncher: { [weak self] url in
                self?.launcherCalls.append(url)
            },
            menuActionTrigger: { [weak self] pid in
                self?.menuTriggerCalls.append(pid)
                return false
            },
            newWindowShortcut: { shortcuts.record($0) }
        )

        try await service.openNewWindow(for: 1234)

        XCTAssertEqual(menuTriggerCalls, [1234])
        XCTAssertEqual(activateCallCount, 1)
        XCTAssertEqual(shortcuts.values, [1234])
        XCTAssertTrue(launcherCalls.isEmpty, "Reopening the app as well could open a second window")
    }

    func testOpenNewWindowThrowsWhenAppNotFound() async {
        let service = SystemAppQuickActionService(
            processLookup: { _ in nil }
        )

        do {
            try await service.openNewWindow(for: 5555)
            XCTFail("Expected appNotFound error")
        } catch let AppActionError.appNotFound(pid) {
            XCTAssertEqual(pid, 5555)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRelaunchAppPolitelyTerminatesResponsiveAppAndRelaunches() async throws {
        let service = SystemAppQuickActionService(
            processLookup: { [weak self] pid in
                self?.makeSampleApp(pid: pid)
            },
            accessibilityChecker: { _ in true }, // responsive
            appLauncher: { [weak self] url in
                self?.launcherCalls.append(url)
            }
        )

        try await service.relaunchApp(pid: 1234)

        XCTAssertEqual(terminateCallCount, 1)
        XCTAssertEqual(forceTerminateCallCount, 0)
        XCTAssertEqual(launcherCalls, [URL(fileURLWithPath: "/Applications/TestApp.app")])
    }

    func testRelaunchAppForceTerminatesFrozenAppAndRelaunches() async throws {
        let service = SystemAppQuickActionService(
            processLookup: { [weak self] pid in
                self?.makeSampleApp(pid: pid)
            },
            accessibilityChecker: { _ in false }, // frozen / not responding
            appLauncher: { [weak self] url in
                self?.launcherCalls.append(url)
            }
        )

        try await service.relaunchApp(pid: 1234)

        XCTAssertEqual(terminateCallCount, 0)
        XCTAssertEqual(forceTerminateCallCount, 1)
        XCTAssertEqual(launcherCalls, [URL(fileURLWithPath: "/Applications/TestApp.app")])
    }

    func testForceQuitInvokesForceTerminate() throws {
        let service = SystemAppQuickActionService(
            processLookup: { [weak self] pid in
                self?.makeSampleApp(pid: pid)
            }
        )

        try service.forceQuit(pid: 1234)

        XCTAssertEqual(forceTerminateCallCount, 1)
    }

    func testForceQuitNeverSignalsAnUnknownPID() {
        let service = SystemAppQuickActionService(processLookup: { _ in nil })
        XCTAssertThrowsError(try service.forceQuit(pid: 4321)) { error in
            XCTAssertEqual(error as? AppActionError, .appNotFound(4321))
        }
    }

    func testForceQuitThrowsForInvalidPID() {
        let service = SystemAppQuickActionService()
        XCTAssertThrowsError(try service.forceQuit(pid: 0))
    }

    func testForceQuitConfirmationPolicyRequiresConfirmationOnlyWhenResponsive() {
        XCTAssertTrue(ForceQuitConfirmationPolicy.requiresConfirmation(isResponsive: true))
        XCTAssertFalse(ForceQuitConfirmationPolicy.requiresConfirmation(isResponsive: false))
    }
}
