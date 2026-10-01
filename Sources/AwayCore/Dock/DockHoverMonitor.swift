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
    public typealias Handler = @MainActor (DockItem?) -> Void

    private var observers: [UUID: Handler] = [:]

    private var observer: AXObserver?
    private var list: AccessibilityElement?
    private var launchObserver: NSObjectProtocol?
    private var retryTask: Task<Void, Never>?

    public init() {}

    public var isRunning: Bool { observer != nil }

    /// Registers a handler called with the hovered item, or `nil` when the
    /// mouse leaves the icons. Several features can observe at the same time;
    /// keep the returned token alive for as long as you want updates.
    public func addObserver(_ handler: @escaping Handler) -> DockHoverObservation {
        let id = UUID()
        observers[id] = handler
        return DockHoverObservation { [weak self] in self?.observers[id] = nil }
    }

    func notify(_ item: DockItem?) {
        for handler in observers.values {
            handler(item)
        }
    }

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
        else {
            AwayLog.hover.notice("Dock list not available yet (Accessibility off or Dock starting)")
            return
        }

        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let monitor = Unmanaged<DockHoverMonitor>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.selectionChanged() }
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let added = AXObserverAddNotification(created, list.element, kAXSelectedChildrenChangedNotification as CFString, refcon)
        guard added == .success else {
            AwayLog.hover.error("could not observe Dock hover: AXError \(added.rawValue)")
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        observer = created
        self.list = list
        AwayLog.hover.info("observing Dock hover (Dock pid \(pid))")
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
        AwayLog.hover.info("Dock relaunched; reattaching")
        detach()
        notify(nil)
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
        notify(selected.flatMap { AccessibilityDockItemLocator.item(from: $0, index: index) })
    }
}

/// Keeps a `DockHoverMonitor` handler registered until cancelled or released.
@MainActor
public final class DockHoverObservation {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel?()
        onCancel = nil
    }

    deinit {
        // `deinit` is nonisolated; hop to the main actor to unregister.
        if let onCancel {
            Task { @MainActor in onCancel() }
        }
    }
}
