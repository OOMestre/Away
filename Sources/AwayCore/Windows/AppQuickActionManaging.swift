import AppKit
import ApplicationServices
import Foundation

public enum AppActionError: Error, Equatable, LocalizedError {
    case appNotFound(pid_t)
    case cannotRelaunch(String)
    case actionFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .appNotFound(pid):
            return "Application with PID \(pid) was not found."
        case let .cannotRelaunch(reason):
            return "Failed to relaunch application: \(reason)"
        case let .actionFailed(reason):
            return "Failed to perform application action: \(reason)"
        }
    }
}

/// Policy governing application quick actions behavior.
public enum ForceQuitConfirmationPolicy {
    /// Determines whether force quitting an app requires user confirmation.
    /// Per specification: "Forçar encerramento pede confirmação, a não ser que o app esteja travado."
    public static func requiresConfirmation(isResponsive: Bool) -> Bool {
        return isResponsive
    }
}

/// Lists and triggers application-level quick actions from the preview panel.
public protocol AppQuickActionManaging: Sendable {
    /// Determines whether the application is currently responsive to user interface events.
    /// Returns `false` if the process is unresponsive (hung / spinning beachball) or has terminated.
    func isResponsive(pid: pid_t) -> Bool

    /// Opens a new window for the specified application.
    func openNewWindow(for pid: pid_t) async throws

    /// Restarts the target application by terminating it and launching a fresh instance.
    func relaunchApp(pid: pid_t) async throws

    /// Immediately forces the target application to terminate.
    func forceQuit(pid: pid_t) throws
}

/// Production implementation of `AppQuickActionManaging` using AppKit and Accessibility.
public final class SystemAppQuickActionService: AppQuickActionManaging, @unchecked Sendable {
    public struct RunningAppInfo: @unchecked Sendable {
        public let processIdentifier: pid_t
        public let bundleURL: URL?
        public let localizedName: String?
        public let isTerminated: Bool
        public let terminateHandler: @Sendable () -> Bool
        public let forceTerminateHandler: @Sendable () -> Bool
        public let activateHandler: @Sendable () -> Void

        public init(
            processIdentifier: pid_t,
            bundleURL: URL?,
            localizedName: String?,
            isTerminated: Bool,
            terminateHandler: @escaping @Sendable () -> Bool,
            forceTerminateHandler: @escaping @Sendable () -> Bool,
            activateHandler: @escaping @Sendable () -> Void
        ) {
            self.processIdentifier = processIdentifier
            self.bundleURL = bundleURL
            self.localizedName = localizedName
            self.isTerminated = isTerminated
            self.terminateHandler = terminateHandler
            self.forceTerminateHandler = forceTerminateHandler
            self.activateHandler = activateHandler
        }
    }

    public typealias ProcessLookup = @Sendable (pid_t) -> RunningAppInfo?
    public typealias AccessibilityChecker = @Sendable (pid_t) -> Bool
    public typealias AppLauncher = @Sendable (URL) async throws -> Void
    public typealias MenuActionTrigger = @Sendable (pid_t) -> Bool
    public typealias ShortcutSender = @Sendable (pid_t) -> Void

    private let processLookup: ProcessLookup
    private let accessibilityChecker: AccessibilityChecker
    private let appLauncher: AppLauncher
    private let menuActionTrigger: MenuActionTrigger
    private let newWindowShortcut: ShortcutSender

    public init(
        processLookup: ProcessLookup? = nil,
        accessibilityChecker: AccessibilityChecker? = nil,
        appLauncher: AppLauncher? = nil,
        menuActionTrigger: MenuActionTrigger? = nil,
        newWindowShortcut: ShortcutSender? = nil
    ) {
        self.processLookup = processLookup ?? Self.defaultProcessLookup
        self.accessibilityChecker = accessibilityChecker ?? Self.defaultAccessibilityChecker
        self.appLauncher = appLauncher ?? Self.defaultAppLauncher
        self.menuActionTrigger = menuActionTrigger ?? Self.defaultMenuActionTrigger
        self.newWindowShortcut = newWindowShortcut ?? Self.sendCommandN
    }

    public func isResponsive(pid: pid_t) -> Bool {
        guard pid > 0, let app = processLookup(pid), !app.isTerminated else {
            return false
        }
        return accessibilityChecker(pid)
    }

    public func openNewWindow(for pid: pid_t) async throws {
        guard let app = processLookup(pid), !app.isTerminated else {
            throw AppActionError.appNotFound(pid)
        }

        // Prefer the app's own File > New Window menu item; otherwise send ⌘N
        // to that app only. Never both, so at most one window opens.
        app.activateHandler()
        if !menuActionTrigger(pid) {
            newWindowShortcut(pid)
        }
    }

    public func relaunchApp(pid: pid_t) async throws {
        guard let app = processLookup(pid), let bundleURL = app.bundleURL else {
            throw AppActionError.appNotFound(pid)
        }

        let responsive = isResponsive(pid: pid)
        if !responsive {
            _ = app.forceTerminateHandler()
        } else {
            _ = app.terminateHandler()
        }

        // Wait for process to exit
        var didExit = false
        for _ in 0..<30 {
            if let current = processLookup(pid), current.isTerminated {
                didExit = true
                break
            } else if processLookup(pid) == nil {
                didExit = true
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        if !didExit {
            _ = app.forceTerminateHandler()
            for _ in 0..<15 {
                if let current = processLookup(pid), current.isTerminated {
                    break
                } else if processLookup(pid) == nil {
                    break
                }
                try await Task.sleep(for: .milliseconds(100))
            }
        }

        // Launch fresh instance
        do {
            try await appLauncher(bundleURL)
        } catch {
            throw AppActionError.cannotRelaunch(error.localizedDescription)
        }
    }

    /// Force quits through `NSRunningApplication` only. A bare PID is never
    /// signalled: if the app is gone, the PID may already belong to another process.
    public func forceQuit(pid: pid_t) throws {
        guard pid > 0, let app = processLookup(pid) else { throw AppActionError.appNotFound(pid) }
        guard app.isTerminated || app.forceTerminateHandler() else {
            throw AppActionError.actionFailed("macOS did not allow \(app.localizedName ?? "the app") to be force quit.")
        }
    }

    // MARK: - Defaults

    public static let defaultProcessLookup: ProcessLookup = { pid in
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        return RunningAppInfo(
            processIdentifier: app.processIdentifier,
            bundleURL: app.bundleURL,
            localizedName: app.localizedName,
            isTerminated: app.isTerminated,
            terminateHandler: { app.terminate() },
            forceTerminateHandler: { app.forceTerminate() },
            activateHandler: { app.activate() }
        )
    }

    public static let defaultAccessibilityChecker: AccessibilityChecker = { pid in
        AccessibilityAppResponsivenessProbe().probe(pid: pid) != .timedOut
    }

    public static let defaultAppLauncher: AppLauncher = { url in
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
    }

    public static let defaultMenuActionTrigger: MenuActionTrigger = { pid in
        let appElement = AccessibilityElement.application(pid: pid, messagingTimeout: 0.3)
        guard let menuBar = appElement.element(kAXMenuBarAttribute) else { return false }

        return findAndPressNewWindow(in: menuBar, depth: 0)
    }

    private static func findAndPressNewWindow(in element: AccessibilityElement, depth: Int) -> Bool {
        guard depth < 4 else { return false }
        if isNewWindowMenuItem(element) {
            return element.perform(kAXPressAction) == .success
        }
        for child in element.children {
            if findAndPressNewWindow(in: child, depth: depth + 1) {
                return true
            }
        }
        return false
    }

    private static func isNewWindowMenuItem(_ element: AccessibilityElement) -> Bool {
        let rawTitle = element.title ?? ""
        let lower = rawTitle.lowercased()

        if lower.contains("tab") || lower.contains("aba") ||
           lower.contains("folder") || lower.contains("pasta") ||
           lower.contains("smart") || lower.contains("inteligente") {
            return false
        }

        if lower.contains("new window") || lower.contains("nova janela") ||
           lower.contains("new document") || lower.contains("novo documento") ||
           lower == "new" || lower == "novo" {
            return true
        }

        if let cmdChar: String = element.string("AXMenuItemCmdChar"), cmdChar.uppercased() == "N" {
            let modifiers: Int? = element.attribute("AXMenuItemCmdModifiers")
            if modifiers == nil || modifiers == 0 {
                return true
            }
        }

        return false
    }

    public static let sendCommandN: ShortcutSender = { pid in
        // Keycode 0x2D is 'N' (kVK_ANSI_N)
        if let eventDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: true) {
            eventDown.flags = .maskCommand
            eventDown.postToPid(pid)
        }
        if let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: false) {
            eventUp.flags = .maskCommand
            eventUp.postToPid(pid)
        }
    }
}
