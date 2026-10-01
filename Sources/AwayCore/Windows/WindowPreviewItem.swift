import CoreGraphics
import Foundation

/// Represents an application window ready for preview in the Dock hover panel.
public struct WindowPreviewItem: Identifiable, Equatable, Sendable {
    public let id: CGWindowID
    public let processID: pid_t
    public let title: String
    /// Window frame in AX/Quartz coordinates (origin at top-left of primary display).
    public let frame: CGRect
    public let isMinimized: Bool
    public let isFullScreen: Bool
    public let isOnScreen: Bool
    public let windowInfo: WindowInfo?

    public init(
        id: CGWindowID,
        processID: pid_t,
        title: String,
        frame: CGRect,
        isMinimized: Bool = false,
        isFullScreen: Bool = false,
        isOnScreen: Bool = true,
        windowInfo: WindowInfo? = nil
    ) {
        self.id = id
        self.processID = processID
        self.title = title
        self.frame = frame
        self.isMinimized = isMinimized
        self.isFullScreen = isFullScreen
        self.isOnScreen = isOnScreen
        self.windowInfo = windowInfo
    }

    public init(window: WindowInfo, id: CGWindowID? = nil) {
        let synthID = id ?? CGWindowID(bitPattern: Int32(truncatingIfNeeded: CFHash(window.element.element)))
        self.init(
            id: synthID,
            processID: window.pid,
            title: window.title,
            frame: window.frame ?? .zero,
            isMinimized: window.isMinimized,
            isFullScreen: window.isFullScreen,
            isOnScreen: !window.isMinimized,
            windowInfo: window
        )
    }
}
