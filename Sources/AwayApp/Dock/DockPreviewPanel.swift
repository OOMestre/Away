import AppKit
import AwayCore
import SwiftUI

/// Non-activating floating panel that hosts the Dock window previews.
@MainActor
final class DockPreviewPanel: NSPanel, DockPreviewPresenting {
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?

    /// One hosting view for the panel's lifetime. Replacing it on every update
    /// would drop the mouse tracking area and the SwiftUI hover state.
    private var hostingView: NSHostingView<DockPreviewContentView>?

    private var currentItem: DockItem?
    private var currentWindows: [WindowPreviewItem] = []
    private var currentThumbnails: [CGWindowID: CGImage] = [:]
    private var currentSettings: DockPreviewSettings?
    private var hasScreenRecording: Bool = false
    private var onSelectCallback: ((WindowPreviewItem) -> Void)?
    private var onActionCallback: ((WindowControlAction, WindowPreviewItem) -> Void)?
    private var onRequestScreenRecordingCallback: (() -> Void)?

    private let quickActions: AppQuickActionManaging
    private let responsiveness: AppResponsivenessProbing
    /// Last probe result per app; `nil` while the check is running.
    private var isResponsive: [pid_t: Bool] = [:]
    private var probeTask: Task<Void, Never>?

    /// Extra content for a Dock item, such as media controls. Set by features
    /// that add to the preview instead of opening their own panel.
    var accessoryProvider: ((DockItem) -> AnyView?)?

    init(quickActions: AppQuickActionManaging, responsiveness: AppResponsivenessProbing = AccessibilityAppResponsivenessProbe()) {
        self.quickActions = quickActions
        self.responsiveness = responsiveness
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        alphaValue = 0
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onMouseEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouseExit?()
    }

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
    ) {
        self.currentItem = item
        self.currentWindows = windows
        self.currentThumbnails = thumbnails
        self.currentSettings = settings
        self.hasScreenRecording = hasScreenRecording
        self.onSelectCallback = onSelect
        self.onActionCallback = onAction
        self.onRequestScreenRecordingCallback = onRequestScreenRecording

        setFrame(targetFrame, display: false)
        renderContentView()
        orderFront(nil)
        probeResponsiveness(of: item)

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().alphaValue = 1.0
            }
        } else {
            alphaValue = 1.0
        }
    }

    func update(
        windows: [WindowPreviewItem],
        thumbnails: [CGWindowID: CGImage]
    ) {
        self.currentWindows = windows
        self.currentThumbnails = thumbnails
        renderContentView()
    }

    private func renderContentView() {
        guard let item = currentItem, let settings = currentSettings else { return }
        let appIcon = item.url.flatMap { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSRunningApplication.runningApplications(withBundleIdentifier: item.bundleIdentifier ?? "").first?.icon

        let footer = settings.showQuickActions ? item.runningProcessID.map { pid in
            DockPreviewFooterView(
                processID: pid,
                appName: item.title,
                isResponsive: isResponsive[pid],
                actions: quickActions,
                onFinished: { [weak self] in self?.hide(animated: true) }
            )
        } : nil

        let view = DockPreviewContentView(
            appTitle: item.title,
            appIcon: appIcon,
            windows: currentWindows,
            thumbnails: currentThumbnails,
            thumbnailWidth: settings.thumbnailWidth,
            showTitles: settings.showTitles,
            showWindowButtons: settings.showWindowButtons,
            hasScreenRecording: hasScreenRecording,
            footer: footer,
            accessory: accessoryProvider?(item),
            onSelect: { [weak self] window in
                self?.onSelectCallback?(window)
            },
            onAction: { [weak self] action, window in
                self?.onActionCallback?(action, window)
            },
            onRequestScreenRecording: { [weak self] in
                self?.onRequestScreenRecordingCallback?()
            }
        )

        if let hostingView {
            hostingView.rootView = view
        } else {
            let hostingView = NSHostingView(rootView: view)
            hostingView.addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            ))
            contentView = hostingView
            self.hostingView = hostingView
        }
        fitHeightToContent()
    }

    /// The footer and accessories change the height; keep the edge next to
    /// the Dock fixed and grow away from it.
    private func fitHeightToContent() {
        guard let hostingView else { return }
        let height = hostingView.fittingSize.height
        guard height > 0, abs(height - frame.height) > 0.5 else { return }
        var newFrame = frame
        newFrame.size.height = height
        if let visible = screen?.visibleFrame, newFrame.maxY > visible.maxY {
            newFrame.origin.y = max(visible.minY, visible.maxY - height)
        }
        setFrame(newFrame, display: true)
    }

    /// AX calls to a hung app block for the messaging timeout, so never on the main thread.
    private func probeResponsiveness(of item: DockItem) {
        probeTask?.cancel()
        guard let pid = item.runningProcessID else { return }
        isResponsive[pid] = nil
        let probe = responsiveness
        probeTask = Task { [weak self] in
            let result = await Task.detached { probe.probe(pid: pid) }.value
            guard let self, !Task.isCancelled, self.currentItem?.runningProcessID == pid else { return }
            self.isResponsive[pid] = result != .timedOut
            self.renderContentView()
        }
    }

    func hide(animated: Bool) {
        probeTask?.cancel()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if animated && !reduceMotion && alphaValue > 0 {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                animator().alphaValue = 0.0
            }, completionHandler: { [weak self] in
                self?.orderOut(nil)
            })
        } else {
            alphaValue = 0.0
            orderOut(nil)
        }
    }
}
