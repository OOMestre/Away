import AppKit
import ApplicationServices
import Foundation

/// Action that can be performed on an application window from its preview thumbnail.
public enum WindowControlAction: String, CaseIterable, Sendable {
    case close
    case minimize
    case fullScreen

    public var title: String {
        switch self {
        case .close: return "Close"
        case .minimize: return "Minimize"
        case .fullScreen: return "Full Screen"
        }
    }

    public var systemImage: String {
        switch self {
        case .close: return "xmark"
        case .minimize: return "minus"
        case .fullScreen: return "arrow.up.left.and.arrow.down.right"
        }
    }
}

public extension WindowManaging {
    /// Performs the given window control action on a `WindowInfo`.
    func perform(_ action: WindowControlAction, on window: WindowInfo) throws {
        switch action {
        case .close:
            try close(window)
        case .minimize:
            try setMinimized(!window.isMinimized, for: window)
        case .fullScreen:
            try setFullScreen(!window.isFullScreen, for: window)
        }
    }

    /// Finds a matching `WindowInfo` for the given `WindowPreviewItem`.
    func findWindow(matching item: WindowPreviewItem) -> WindowInfo? {
        if let direct = item.windowInfo {
            return direct
        }
        let appWindows = windows(of: item.processID)
        guard !appWindows.isEmpty else { return nil }

        // Match by synthesized element hash if present
        if let match = appWindows.first(where: {
            CGWindowID(bitPattern: Int32(truncatingIfNeeded: CFHash($0.element.element))) == item.id
        }) {
            return match
        }

        // Match by unique non-empty title
        let titleMatches = appWindows.filter { !$0.title.isEmpty && $0.title == item.title }
        if titleMatches.count == 1 {
            return titleMatches[0]
        }

        // Match by frame proximity
        if let match = appWindows.first(where: {
            guard let f = $0.frame else { return false }
            return abs(f.origin.x - item.frame.origin.x) < 10 && abs(f.origin.y - item.frame.origin.y) < 10
        }) {
            return match
        }

        if let match = titleMatches.first {
            return match
        }

        // Fallback only if there is a single window
        return appWindows.count == 1 ? appWindows.first : nil
    }

    /// Performs the given window control action on a `WindowPreviewItem`.
    func perform(_ action: WindowControlAction, on item: WindowPreviewItem) throws {
        if let direct = item.windowInfo {
            try perform(action, on: direct)
            return
        }
        guard let window = findWindow(matching: item) else {
            throw WindowActionError.unsupported
        }
        try perform(action, on: window)
    }

    /// Brings the window of the given `WindowPreviewItem` to the foreground and focuses it.
    ///
    /// Implements requirement A2: clicking a thumbnail focuses specifically that window,
    /// without pulling all windows of the application to the foreground.
    func focus(_ item: WindowPreviewItem) throws {
        if let direct = item.windowInfo {
            try focus(direct)
            return
        }
        guard let window = findWindow(matching: item) else {
            throw WindowActionError.unsupported
        }
        try focus(window)
    }
}
