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

    init() {
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

        renderContentView()
        setFrame(targetFrame, display: true)
        orderFront(nil)

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

        let view = DockPreviewContentView(
            appTitle: item.title,
            appIcon: appIcon,
            windows: currentWindows,
            thumbnails: currentThumbnails,
            thumbnailWidth: settings.thumbnailWidth,
            showTitles: settings.showTitles,
            showWindowButtons: settings.showWindowButtons,
            hasScreenRecording: hasScreenRecording,
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
    }

    func hide(animated: Bool) {
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
