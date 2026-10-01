import AppKit
import ApplicationServices

/// Reports which Dock icon is under the mouse, using the Dock's own
/// `AXSelectedChildrenChanged` notification instead of polling.
///
/// Survives Dock restarts (for example after `killall Dock`) by re-attaching
/// when the Dock process launches again. Call `stop()` before releasing it:
/// the Accessibility observer holds an unretained reference to the monitor.
@MainActor
public final class DockHoverMonitor {
    /// Called with the hovered item, or `nil` when the mouse leaves the icons.
    public var onChange: ((DockItem?) -> Void)?

    private var observer: AXObserver?
    private var list: AccessibilityElement?
    private var launchObserver: NSObjectProtocol?
    private var retryTask: Task<Void, Never>?

    public init() {}

    public var isRunning: Bool { observer != nil }

    public func start() {
        guard launchObserver == nil else { return }
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == AccessibilityDockItemLocator.dockBundleIdentifier else { return }
            MainActor.assumeIsolated { self?.reattachAfterDockLaunch() }
        }
        attach()
    }

    public func stop() {
        retryTask?.cancel()
        retryTask = nil
        detach()
        if let launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(launchObserver)
        }
        launchObserver = nil
    }

    private func attach() {
        detach()
        guard let pid = AccessibilityDockItemLocator.dockPID(),
              let list = AccessibilityDockItemLocator.dockList()
        else { return }

        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let monitor = Unmanaged<DockHoverMonitor>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.selectionChanged() }
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverAddNotification(created, list.element, kAXSelectedChildrenChangedNotification as CFString, refcon) == .success else {
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        observer = created
        self.list = list
    }

    private func detach() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        list = nil
    }

    /// The new Dock needs a moment to build its Accessibility tree.
    private func reattachAfterDockLaunch() {
        detach()
        onChange?(nil)
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            for _ in 0..<10 {
                try? await Task.sleep(for: .milliseconds(300))
                guard let self, !Task.isCancelled else { return }
                self.attach()
                if self.isRunning { return }
            }
        }
    }

    private func selectionChanged() {
        guard let list else { return }
        let selected = list.elements(kAXSelectedChildrenAttribute).first
        let index = selected.flatMap { list.children.firstIndex(of: $0) } ?? 0
        onChange?(selected.flatMap { AccessibilityDockItemLocator.item(from: $0, index: index) })
    }
}
