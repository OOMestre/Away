import AppKit
import CoreGraphics
import Foundation

/// Protocol for the UI panel presentation layer, allowing hermetic unit testing of the coordinator.
@MainActor
public protocol DockPreviewPresenting: AnyObject {
    var onMouseEnter: (() -> Void)? { get set }
    var onMouseExit: (() -> Void)? { get set }
    var isVisible: Bool { get }

    func show(
        item: DockItem,
        windows: [WindowPreviewItem],
        thumbnails: [CGWindowID: CGImage],
        targetFrame: CGRect,
        settings: DockPreviewSettings,
        hasScreenRecording: Bool,
        onSelect: @escaping (WindowPreviewItem) -> Void,
        onAction: @escaping (WindowControlAction, WindowPreviewItem) -> Void,
        onRequestScreenRecording: @escaping () -> Void
    )

    func update(
        windows: [WindowPreviewItem],
        thumbnails: [CGWindowID: CGImage]
    )

    func hide(animated: Bool)
}

/// Coordinates Dock icon hover detection, configurable delay, ScreenCaptureKit thumbnail
/// generation, and presentation of the window preview panel.
@MainActor
public final class DockPreviewCoordinator {
    private let dockHover: DockHoverMonitor
    private let settingsStore: DockPreviewSettingsStore
    private let thumbnailService: WindowThumbnailCapturing
    private let windowManager: WindowManaging
    private let permissions: PermissionChecking
    private let dockItems: DockItemLocating
    private let presenter: DockPreviewPresenting

    /// Items that open the panel even without windows (for example media
    /// players, whose preview also shows playback controls).
    public var showsWithoutWindows: (DockItem) -> Bool = { _ in false }

    /// Finds the process behind a Dock item. Injectable so tests need no real app.
    public var processID: (DockItem) -> pid_t? = { $0.runningProcessID }

    public private(set) var currentDockItem: DockItem?
    public private(set) var currentWindows: [WindowPreviewItem] = []
    public private(set) var thumbnails: [CGWindowID: CGImage] = [:]

    public private(set) var isMouseInDock: Bool = false
    public private(set) var isMouseInPanel: Bool = false

    private var hoverObservation: DockHoverObservation?
    private var openTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?

    public init(
        dockHover: DockHoverMonitor,
        settingsStore: DockPreviewSettingsStore,
        thumbnailService: WindowThumbnailCapturing,
        windowManager: WindowManaging,
        permissions: PermissionChecking,
        dockItems: DockItemLocating,
        presenter: DockPreviewPresenting
    ) {
        self.dockHover = dockHover
        self.settingsStore = settingsStore
        self.thumbnailService = thumbnailService
        self.windowManager = windowManager
        self.permissions = permissions
        self.dockItems = dockItems
        self.presenter = presenter

        setupPresenterTracking()
    }

    public func start() {
        guard hoverObservation == nil else { return }
        hoverObservation = dockHover.addObserver { [weak self] item in
            self?.dockHoverChanged(to: item)
        }
        dockHover.start()
    }

    /// Stops reacting to hover. The shared monitor keeps running for other features.
    public func stop() {
        cancelTasks()
        presenter.hide(animated: false)
        hoverObservation?.cancel()
        hoverObservation = nil
    }

    public func refresh() {
        if settingsStore.settings.isEnabled && !dockHover.isRunning {
            dockHover.start()
        }
    }

    private func setupPresenterTracking() {
        presenter.onMouseEnter = { [weak self] in
            self?.panelHoverChanged(isHovered: true)
        }
        presenter.onMouseExit = { [weak self] in
            self?.panelHoverChanged(isHovered: false)
        }
    }

    public func dockHoverChanged(to item: DockItem?) {
        guard settingsStore.settings.isEnabled else {
            hidePanel()
            return
        }

        if let item {
            isMouseInDock = true
            dismissTask?.cancel()
            dismissTask = nil

            guard item.kind == .application, item.isRunning else {
                hidePanel()
                return
            }

            if currentDockItem?.index == item.index && presenter.isVisible {
                // Already displaying previews for this item
                return
            }

            openTask?.cancel()
            let delay = settingsStore.settings.hoverDelay

            openTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                await self.showPreviews(for: item)
            }
        } else {
            isMouseInDock = false
            openTask?.cancel()
            openTask = nil

            scheduleDismissalIfNeeded()
        }
    }

    public func panelHoverChanged(isHovered: Bool) {
        isMouseInPanel = isHovered
        if isHovered {
            dismissTask?.cancel()
            dismissTask = nil
        } else {
            scheduleDismissalIfNeeded()
        }
    }

    private func scheduleDismissalIfNeeded() {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, let self else { return }
            if !self.isMouseInDock && !self.isMouseInPanel {
                self.hidePanel()
            }
        }
    }

    private func showPreviews(for item: DockItem) async {
        guard let pid = processID(item) else {
            hidePanel()
            return
        }

        let windows: [WindowPreviewItem]
        do {
            windows = try await thumbnailService.previewableWindows(for: pid)
        } catch {
            windows = []
        }

        guard !windows.isEmpty || showsWithoutWindows(item) else {
            hidePanel()
            return
        }

        currentDockItem = item
        currentWindows = windows
        thumbnails.removeAll()

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 1080
        let dockRectAppKit = ScreenCoordinates.appKitRect(fromAX: item.frame, primaryScreenHeight: primaryHeight)
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(dockRectAppKit) }) ?? NSScreen.main ?? NSScreen.screens[0]

        let orientation: DockOrientation
        if let listAXFrame = dockItems.listFrame() {
            let appKitListFrame = ScreenCoordinates.appKitRect(fromAX: listAXFrame, primaryScreenHeight: primaryHeight)
            orientation = DockOrientation(listFrame: appKitListFrame, screenFrame: screen.frame)
        } else {
            orientation = .bottom
        }

        let cardWidth = settingsStore.settings.thumbnailWidth
        let spacing: CGFloat = 12
        let horizontalPadding: CGFloat = 28
        let contentWidth = horizontalPadding + CGFloat(windows.count) * cardWidth + CGFloat(max(0, windows.count - 1)) * spacing
        let maxScreenWidth = screen.visibleFrame.width - 40
        let panelWidth = min(contentWidth, maxScreenWidth)

        let estimatedCardHeight = cardWidth / 1.6
        let panelHeight = estimatedCardHeight + 86
        let panelSize = CGSize(width: panelWidth, height: panelHeight)

        let targetFrame = DockPreviewGeometry.panelFrame(
            for: dockRectAppKit,
            panelSize: panelSize,
            orientation: orientation,
            screenVisibleFrame: screen.visibleFrame
        )

        let hasScreenRecording = permissions.status(of: .screenRecording) == .granted

        presenter.show(
            item: item,
            windows: currentWindows,
            thumbnails: thumbnails,
            targetFrame: targetFrame,
            settings: settingsStore.settings,
            hasScreenRecording: hasScreenRecording,
            onSelect: { [weak self] window in
                self?.selectWindow(window)
            },
            onAction: { [weak self] action, window in
                self?.handleAction(action, on: window)
            },
            onRequestScreenRecording: { [weak self] in
                self?.permissions.request(.screenRecording)
            }
        )

        // Capture thumbnails asynchronously with ScreenCaptureKit
        thumbnailTask?.cancel()
        thumbnailTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for window in windows {
                guard !Task.isCancelled else { return }
                let targetSize = CGSize(width: cardWidth, height: estimatedCardHeight)
                if let image = try? await self.thumbnailService.captureThumbnail(for: window.id, targetSize: targetSize) {
                    guard !Task.isCancelled else { return }
                    self.thumbnails[window.id] = image
                    self.presenter.update(windows: self.currentWindows, thumbnails: self.thumbnails)
                }
            }
        }
    }

    public func selectWindow(_ window: WindowPreviewItem) {
        hidePanel(animated: false)

        do {
            try windowManager.focus(window)
        } catch {
            NSRunningApplication(processIdentifier: window.processID)?.activate()
        }
    }

    public func handleAction(_ action: WindowControlAction, on window: WindowPreviewItem) {
        do {
            try windowManager.perform(action, on: window)
        } catch {
            // Action failed or unsupported
        }

        switch action {
        case .close:
            currentWindows.removeAll { $0.id == window.id }
            thumbnails.removeValue(forKey: window.id)

            if currentWindows.isEmpty, !(currentDockItem.map(showsWithoutWindows) ?? false) {
                hidePanel()
            } else {
                presenter.update(windows: currentWindows, thumbnails: thumbnails)
            }
        case .minimize:
            // Update minimized flag locally for responsive feedback
            if let index = currentWindows.firstIndex(where: { $0.id == window.id }) {
                let updated = WindowPreviewItem(
                    id: window.id,
                    processID: window.processID,
                    title: window.title,
                    frame: window.frame,
                    isMinimized: !window.isMinimized,
                    isFullScreen: window.isFullScreen,
                    isOnScreen: window.isOnScreen
                )
                currentWindows[index] = updated
                presenter.update(windows: currentWindows, thumbnails: thumbnails)
            }
        case .fullScreen:
            if let index = currentWindows.firstIndex(where: { $0.id == window.id }) {
                let updated = WindowPreviewItem(
                    id: window.id,
                    processID: window.processID,
                    title: window.title,
                    frame: window.frame,
                    isMinimized: window.isMinimized,
                    isFullScreen: !window.isFullScreen,
                    isOnScreen: window.isOnScreen
                )
                currentWindows[index] = updated
                presenter.update(windows: currentWindows, thumbnails: thumbnails)
            }
        }
    }

    public func hidePanel(animated: Bool = true) {
        cancelTasks()
        currentDockItem = nil
        currentWindows = []
        thumbnails.removeAll()
        presenter.hide(animated: animated)
    }

    private func cancelTasks() {
        openTask?.cancel()
        openTask = nil
        dismissTask?.cancel()
        dismissTask = nil
        thumbnailTask?.cancel()
        thumbnailTask = nil
    }
}
