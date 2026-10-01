import CoreGraphics
import Foundation

public enum DockItemKind: Equatable, Sendable {
    case application
    case folder
    case file
    case url
    case minimizedWindow
    case separator
    case spacer
    case trash
    case other(String)

    /// Maps the Dock's `AXSubrole` of an `AXDockItem`.
    public init(subrole: String?) {
        switch subrole {
        case "AXApplicationDockItem": self = .application
        case "AXFolderDockItem": self = .folder
        case "AXDocumentDockItem": self = .file
        case "AXURLDockItem": self = .url
        case "AXMinimizedWindowDockItem": self = .minimizedWindow
        case "AXSeparatorDockItem": self = .separator
        case "AXSpacerDockItem": self = .spacer
        case "AXTrashDockItem": self = .trash
        default: self = .other(subrole ?? "")
        }
    }
}

/// One icon in the Dock, as read through Accessibility.
public struct DockItem: Equatable, Sendable {
    public let index: Int
    public let kind: DockItemKind
    public let title: String
    /// Frame in AX coordinates. Use `ScreenCoordinates` to convert for AppKit windows.
    public let frame: CGRect
    /// Bundle URL for applications, target URL for files, folders and links.
    public let url: URL?
    public let isRunning: Bool

    public init(index: Int, kind: DockItemKind, title: String, frame: CGRect, url: URL?, isRunning: Bool) {
        self.index = index
        self.kind = kind
        self.title = title
        self.frame = frame
        self.url = url
        self.isRunning = isRunning
    }

    public var bundleIdentifier: String? {
        guard kind == .application, let url else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }
}

public enum DockOrientation: String, Sendable {
    case bottom
    case left
    case right

    /// Infers the Dock edge from the frame of its icon list and the screen
    /// that contains it, both in the same coordinate space.
    public init(listFrame: CGRect, screenFrame: CGRect) {
        if listFrame.width >= listFrame.height {
            self = .bottom
        } else if listFrame.midX < screenFrame.midX {
            self = .left
        } else {
            self = .right
        }
    }
}
