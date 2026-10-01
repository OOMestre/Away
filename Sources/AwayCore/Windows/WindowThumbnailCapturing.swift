import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

public enum WindowCaptureError: Error, Equatable, LocalizedError {
    case windowNotFound(CGWindowID)
    case captureFailed(String)
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case let .windowNotFound(id):
            return "Window with ID \(id) was not found."
        case let .captureFailed(reason):
            return "Failed to capture window thumbnail: \(reason)"
        case .permissionDenied:
            return "Screen Recording permission is required to capture window thumbnails."
        }
    }
}

/// Protocol for listing previewable windows and capturing thumbnails via ScreenCaptureKit.
public protocol WindowThumbnailCapturing: Sendable {
    /// Returns the previewable windows of the given application process.
    func previewableWindows(for processID: pid_t) async throws -> [WindowPreviewItem]

    /// Captures a thumbnail image for the specified window ID using ScreenCaptureKit.
    func captureThumbnail(for windowID: CGWindowID, targetSize: CGSize) async throws -> CGImage
}

/// Production thumbnail service using macOS ScreenCaptureKit (`SCScreenshotManager`).
/// Does not use obsolete APIs such as `CGWindowListCreateImage`.
public final class ScreenCaptureKitThumbnailService: WindowThumbnailCapturing, @unchecked Sendable {
    private let windowManager: WindowManaging
    private let lock = NSLock()
    private var cachedWindows: [CGWindowID: SCWindow] = [:]

    public init(windowManager: WindowManaging = AccessibilityWindowService()) {
        self.windowManager = windowManager
    }

    public func previewableWindows(for processID: pid_t) async throws -> [WindowPreviewItem] {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            // If ScreenCaptureKit fails (e.g. permission denied), fall back to Accessibility window list
            let axWindows = windowManager.windows(of: processID)
            guard !axWindows.isEmpty else {
                throw WindowCaptureError.permissionDenied
            }
            return axWindows.compactMap { ax -> WindowPreviewItem? in
                guard let frame = ax.frame, frame.width > 20, frame.height > 20 else { return nil }
                // Synthesize an ID based on hash/pid if AX does not have CGWindowID
                let synthID = CGWindowID(bitPattern: Int32(truncatingIfNeeded: CFHash(ax.element.element)))
                return WindowPreviewItem(
                    id: synthID,
                    processID: processID,
                    title: ax.title,
                    frame: frame,
                    isMinimized: ax.isMinimized,
                    isFullScreen: ax.isFullScreen,
                    isOnScreen: !ax.isMinimized,
                    windowInfo: ax
                )
            }
        }

        let axWindows = windowManager.windows(of: processID)

        let appWindows = content.windows.filter { window in
            guard window.owningApplication?.processID == processID else { return false }
            // Filter out system overlay/tooltips: windowLayer == 0 represents regular app windows
            guard window.windowLayer == 0 else { return false }
            // Filter out negligible helper windows
            guard window.frame.width > 20 && window.frame.height > 20 else { return false }
            return true
        }

        // Only the windows of the hovered app are kept, so closed windows
        // never accumulate in the cache.
        lock.withLock {
            cachedWindows = Dictionary(appWindows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
        }

        return appWindows.map { scWindow in
            let matchedAX = WindowMatcher.match(
                frame: scWindow.frame,
                title: scWindow.title,
                in: axWindows.map { (frame: $0.frame, title: $0.title) }
            ).map { axWindows[$0] }

            let scTitle = scWindow.title ?? ""
            let title = !scTitle.isEmpty ? scTitle : (matchedAX?.title ?? "")

            return WindowPreviewItem(
                id: scWindow.windowID,
                processID: processID,
                title: title,
                frame: scWindow.frame,
                isMinimized: matchedAX?.isMinimized ?? false,
                isFullScreen: matchedAX?.isFullScreen ?? false,
                isOnScreen: scWindow.isOnScreen,
                windowInfo: matchedAX
            )
        }
    }

    public func captureThumbnail(for windowID: CGWindowID, targetSize: CGSize) async throws -> CGImage {
        var scWindow = lock.withLock { cachedWindows[windowID] }

        if scWindow == nil {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            if let found = content.windows.first(where: { $0.windowID == windowID }) {
                scWindow = found
                lock.withLock { cachedWindows[windowID] = found }
            }
        }

        guard let targetWindow = scWindow else {
            throw WindowCaptureError.windowNotFound(windowID)
        }

        let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
        let config = SCStreamConfiguration()

        let scale: CGFloat = 2.0 // High-DPI / Retina scale for sharp previews
        let aspect = targetWindow.frame.height > 0 ? (targetWindow.frame.width / targetWindow.frame.height) : (16.0 / 10.0)
        let width = max(1, Int(targetSize.width * scale))
        let height = max(1, Int(CGFloat(width) / aspect))

        config.width = width
        config.height = height
        config.scalesToFit = true
        config.showsCursor = false

        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            throw WindowCaptureError.captureFailed(error.localizedDescription)
        }
    }
}

/// Pairs a ScreenCaptureKit window with its Accessibility window. Both use
/// top-left global coordinates. Position wins over title, because several
/// windows of one app often share a title.
public enum WindowMatcher {
    public static let tolerance: CGFloat = 10

    public static func match(frame: CGRect, title: String?, in candidates: [(frame: CGRect?, title: String)]) -> Int? {
        func isClose(_ other: CGRect?) -> Bool {
            guard let other else { return false }
            return abs(other.minX - frame.minX) < tolerance
                && abs(other.minY - frame.minY) < tolerance
                && abs(other.width - frame.width) < tolerance
                && abs(other.height - frame.height) < tolerance
        }

        let byFrame = candidates.indices.filter { isClose(candidates[$0].frame) }
        if byFrame.count == 1 { return byFrame[0] }
        if let title, !title.isEmpty {
            let pool = byFrame.isEmpty ? Array(candidates.indices) : byFrame
            let byTitle = pool.filter { candidates[$0].title == title }
            if byTitle.count == 1 { return byTitle[0] }
        }
        return byFrame.first
    }
}
