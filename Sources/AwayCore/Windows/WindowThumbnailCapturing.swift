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
                    isOnScreen: !ax.isMinimized
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

        lock.withLock {
            for window in appWindows {
                cachedWindows[window.windowID] = window
            }
        }

        return appWindows.map { scWindow in
            let matchedAX = axWindows.first { ax in
                if let title = scWindow.title, !title.isEmpty, title == ax.title {
                    return true
                }
                if let axFrame = ax.frame {
                    let dx = abs(axFrame.origin.x - scWindow.frame.origin.x)
                    let dy = abs(axFrame.origin.y - scWindow.frame.origin.y)
                    return dx < 10 && dy < 10
                }
                return false
            }

            let scTitle = scWindow.title ?? ""
            let title = !scTitle.isEmpty ? scTitle : (matchedAX?.title ?? "")

            return WindowPreviewItem(
                id: scWindow.windowID,
                processID: processID,
                title: title,
                frame: scWindow.frame,
                isMinimized: matchedAX?.isMinimized ?? false,
                isFullScreen: matchedAX?.isFullScreen ?? false,
                isOnScreen: scWindow.isOnScreen
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
