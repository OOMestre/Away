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

    public init(
        id: CGWindowID,
        processID: pid_t,
        title: String,
        frame: CGRect,
        isMinimized: Bool = false,
        isFullScreen: Bool = false,
        isOnScreen: Bool = true
    ) {
        self.id = id
        self.processID = processID
        self.title = title
        self.frame = frame
        self.isMinimized = isMinimized
        self.isFullScreen = isFullScreen
        self.isOnScreen = isOnScreen
    }
}
