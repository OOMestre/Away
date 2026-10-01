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
///
/// The window list comes from Accessibility, which is fast and reports only
/// windows a person can use. ScreenCaptureKit is used only for the images:
/// listing every window on the system can take seconds, so one request runs
/// at a time, its result is reused briefly, and a slow answer never blocks
/// the preview (the panel opens with titles and thumbnails fill in later).
public final class ScreenCaptureKitThumbnailService: WindowThumbnailCapturing, @unchecked Sendable {
    public static let contentTimeout: Duration = .milliseconds(800)

    private let windowManager: WindowManaging
    private let shareableContent = ShareableContentCache()
    private let lock = NSLock()
    private var cachedWindows: [CGWindowID: SCWindow] = [:]

    public init(windowManager: WindowManaging = AccessibilityWindowService()) {
        self.windowManager = windowManager
    }

    public func previewableWindows(for processID: pid_t) async throws -> [WindowPreviewItem] {
        let clock = ContinuousClock()
        let start = clock.now
        let axWindows = windowManager.windows(of: processID)
        let systemWindows = await shareableContent.windows(timeout: Self.contentTimeout)

        let items: [WindowPreviewItem]
        if let systemWindows {
            items = matchedItems(processID: processID, axWindows: axWindows, systemWindows: systemWindows)
        } else {
            items = accessibilityItems(processID: processID, axWindows: axWindows)
        }
        AwayLog.previews.debug("pid \(processID): \(items.count) windows (ax \(axWindows.count), capture list \(systemWindows == nil ? "unavailable" : "ok")) in \(start.duration(to: clock.now))")
        return items
    }

    private func matchedItems(processID: pid_t, axWindows: [WindowInfo], systemWindows: [SCWindow]) -> [WindowPreviewItem] {
        let candidates = axWindows.map { (frame: $0.frame, title: $0.title) }
        let ownWindows = systemWindows.filter { $0.owningApplication?.processID == processID }
        let matches = ownWindows.reduce(into: [CGWindowID: WindowInfo]()) { result, window in
            guard let index = WindowMatcher.match(frame: window.frame, title: window.title, in: candidates) else { return }
            result[window.windowID] = axWindows[index]
        }
        let appWindows = ownWindows.filter { window in
            PreviewWindowFilter.isPreviewable(
                frame: window.frame,
                layer: window.windowLayer,
                hasAccessibilityMatch: matches[window.windowID] != nil,
                accessibilityAvailable: !axWindows.isEmpty
            )
        }

        // Only the windows of the hovered app are kept, so closed windows
        // never accumulate in the cache.
        lock.withLock {
            cachedWindows = Dictionary(appWindows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
        }

        return appWindows.map { scWindow in
            let matchedAX = matches[scWindow.windowID]
            let scTitle = scWindow.title ?? ""
            return WindowPreviewItem(
                id: scWindow.windowID,
                processID: processID,
                title: !scTitle.isEmpty ? scTitle : (matchedAX?.title ?? ""),
                frame: scWindow.frame,
                isMinimized: matchedAX?.isMinimized ?? false,
                isFullScreen: matchedAX?.isFullScreen ?? false,
                isOnScreen: scWindow.isOnScreen,
                windowInfo: matchedAX
            )
        }
    }

    /// Used when the capture list is not available (no Screen Recording, or
    /// ScreenCaptureKit is slow): titles and controls still work.
    private func accessibilityItems(processID: pid_t, axWindows: [WindowInfo]) -> [WindowPreviewItem] {
        axWindows.compactMap { window in
            guard let frame = window.frame,
                  window.isStandard || window.isMinimized,
                  PreviewWindowFilter.isPreviewable(frame: frame, layer: 0, hasAccessibilityMatch: true, accessibilityAvailable: true)
            else { return nil }
            return WindowPreviewItem(window: window)
        }
    }

    public func captureThumbnail(for windowID: CGWindowID, targetSize: CGSize) async throws -> CGImage {
        var scWindow = lock.withLock { cachedWindows[windowID] }
        if scWindow == nil {
            scWindow = await shareableContent.windows(timeout: Self.contentTimeout)?.first { $0.windowID == windowID }
        }
        guard let targetWindow = scWindow else {
            throw WindowCaptureError.windowNotFound(windowID)
        }

        let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
        let config = SCStreamConfiguration()
        let scale: CGFloat = 2.0 // Retina scale for sharp previews
        let aspect = targetWindow.frame.height > 0 ? (targetWindow.frame.width / targetWindow.frame.height) : (16.0 / 10.0)
        let width = max(1, Int(targetSize.width * scale))
        config.width = width
        config.height = max(1, Int(CGFloat(width) / aspect))
        config.scalesToFit = true
        config.showsCursor = false

        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            throw WindowCaptureError.captureFailed(error.localizedDescription)
        }
    }
}

/// Single-flight, short-lived cache of the system window list.
actor ShareableContentCache {
    private struct Snapshot: @unchecked Sendable {
        let date: ContinuousClock.Instant
        let windows: [SCWindow]
    }

    private let maxAge: Duration
    private var latest: Snapshot?
    private var inFlight: Task<Snapshot?, Never>?

    init(maxAge: Duration = .seconds(1)) {
        self.maxAge = maxAge
    }

    /// Fresh or recent windows, or `nil` if the list is unavailable or slower
    /// than `timeout`. A slow request keeps running and serves the next call.
    func windows(timeout: Duration) async -> [SCWindow]? {
        let clock = ContinuousClock()
        if let latest, latest.date.duration(to: clock.now) < maxAge {
            return latest.windows
        }
        let request = inFlight ?? makeRequest()
        let snapshot = await withTaskGroup(of: Snapshot?.self) { group in
            group.addTask { await request.value }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        if snapshot == nil {
            AwayLog.previews.notice("capture window list slower than \(timeout); showing titles only")
        }
        return snapshot?.windows
    }

    private func makeRequest() -> Task<Snapshot?, Never> {
        let task = Task<Snapshot?, Never> {
            let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return content.map { Snapshot(date: ContinuousClock().now, windows: $0.windows) }
        }
        inFlight = task
        Task {
            let snapshot = await task.value
            finish(snapshot)
        }
        return task
    }

    private func finish(_ snapshot: Snapshot?) {
        inFlight = nil
        if let snapshot { latest = snapshot }
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

/// Decides which ScreenCaptureKit windows are real app windows.
///
/// Apps own several invisible layer-0 windows, such as one menu bar strip per
/// Space (full width, about 30 pt tall). Accessibility only reports the
/// windows a person can use, so when it is available a window must match one.
public enum PreviewWindowFilter {
    public static let minimumSide: CGFloat = 60

    public static func isPreviewable(
        frame: CGRect,
        layer: Int,
        hasAccessibilityMatch: Bool,
        accessibilityAvailable: Bool
    ) -> Bool {
        guard layer == 0, frame.width >= minimumSide, frame.height >= minimumSide else { return false }
        return accessibilityAvailable ? hasAccessibilityMatch : true
    }
}
