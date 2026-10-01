import AppKit
import ApplicationServices

/// A window of another app, as seen through Accessibility.
public struct WindowInfo: Equatable, Sendable {
    public let element: AccessibilityElement
    public let pid: pid_t
    public let title: String
    /// Frame in AX coordinates.
    public let frame: CGRect?
    public let isMinimized: Bool
    public let isFullScreen: Bool
    /// `true` for regular document windows (`AXStandardWindow`); panels, sheets
    /// and utility windows are `false`.
    public let isStandard: Bool

    public init(element: AccessibilityElement, pid: pid_t, title: String, frame: CGRect?, isMinimized: Bool, isFullScreen: Bool, isStandard: Bool) {
        self.element = element
        self.pid = pid
        self.title = title
        self.frame = frame
        self.isMinimized = isMinimized
        self.isFullScreen = isFullScreen
        self.isStandard = isStandard
    }
}

public enum WindowActionError: Error, Equatable {
    case accessibility(AXError)
    case unsupported
}

/// Lists and controls windows of other apps.
///
/// Only windows in the current Space are visible to Accessibility.
public protocol WindowManaging: Sendable {
    func windows(of pid: pid_t) -> [WindowInfo]
    func focus(_ window: WindowInfo) throws
    func close(_ window: WindowInfo) throws
    func setMinimized(_ minimized: Bool, for window: WindowInfo) throws
    func setFullScreen(_ fullScreen: Bool, for window: WindowInfo) throws
}

public struct AccessibilityWindowService: WindowManaging {
    static let fullScreenAttribute = "AXFullScreen"

    public init() {}

    public func windows(of pid: pid_t) -> [WindowInfo] {
        AccessibilityElement.application(pid: pid).elements(kAXWindowsAttribute).map { window in
            WindowInfo(
                element: window,
                pid: pid,
                title: window.title ?? "",
                frame: window.frame,
                isMinimized: window.bool(kAXMinimizedAttribute) ?? false,
                isFullScreen: window.bool(Self.fullScreenAttribute) ?? false,
                isStandard: window.subrole == kAXStandardWindowSubrole
            )
        }
    }

    public func focus(_ window: WindowInfo) throws {
        if window.isMinimized {
            try check(window.element.set(kAXMinimizedAttribute, to: kCFBooleanFalse))
        }
        try check(window.element.perform(kAXRaiseAction))
        window.element.set(kAXMainAttribute, to: kCFBooleanTrue)
        NSRunningApplication(processIdentifier: window.pid)?.activate()
    }

    public func close(_ window: WindowInfo) throws {
        guard let button = window.element.element(kAXCloseButtonAttribute) else {
            throw WindowActionError.unsupported
        }
        try check(button.perform(kAXPressAction))
    }

    public func setMinimized(_ minimized: Bool, for window: WindowInfo) throws {
        try check(window.element.set(kAXMinimizedAttribute, to: minimized ? kCFBooleanTrue : kCFBooleanFalse))
    }

    public func setFullScreen(_ fullScreen: Bool, for window: WindowInfo) throws {
        try check(window.element.set(Self.fullScreenAttribute, to: fullScreen ? kCFBooleanTrue : kCFBooleanFalse))
    }

    private func check(_ error: AXError) throws {
        guard error == .success else { throw WindowActionError.accessibility(error) }
    }
}
