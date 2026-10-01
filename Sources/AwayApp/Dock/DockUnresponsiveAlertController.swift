import AppKit
import AwayCore
import Observation

@MainActor
@Observable
final class DockUnresponsiveAlertController {
    struct RunningApp: Identifiable, Sendable {
        let pid: pid_t
        let bundleIdentifier: String
        let name: String
        var id: pid_t { pid }
    }

    private final class BadgeAction: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func clicked() { action() }
    }

    private struct Badge {
        let panel: NSPanel
        let action: BadgeAction
    }

    private let dockItems: DockItemLocating
    private let permissions: PermissionChecking
    private let probe: AppResponsivenessProbing
    private var tracker = UnresponsiveAppTracker()
    private var badges: [pid_t: Badge] = [:]
    private var task: Task<Void, Never>?

    private(set) var enabled: Bool
    private(set) var unresponsiveApps: [RunningApp] = []

    init(dockItems: DockItemLocating, permissions: PermissionChecking,
         probe: AppResponsivenessProbing = AccessibilityAppResponsivenessProbe()) {
        self.dockItems = dockItems
        self.permissions = permissions
        self.probe = probe
        enabled = UserDefaults.standard.object(forKey: "dock.unresponsiveAlertsEnabled") as? Bool ?? true
    }

    func start() {
        guard enabled, task == nil else { return }
        task = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.scan()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func setEnabled(_ value: Bool) {
        guard enabled != value else { return }
        enabled = value
        UserDefaults.standard.set(value, forKey: "dock.unresponsiveAlertsEnabled")
        if value {
            start()
        } else {
            task?.cancel()
            task = nil
            tracker = UnresponsiveAppTracker()
            unresponsiveApps = []
            clearBadges()
        }
    }

    private func scan() async {
        guard permissions.status(of: .accessibility) == .granted else {
            tracker = UnresponsiveAppTracker()
            unresponsiveApps = []
            clearBadges()
            return
        }

        let locator = dockItems
        let items = await Task.detached { locator.items() }.value
        guard !Task.isCancelled else { return }

        let byBundle = Dictionary(grouping: items.filter { $0.kind == .application },
                                  by: { $0.bundleIdentifier ?? "" })
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> RunningApp? in
            guard app.activationPolicy == .regular,
                  app.isFinishedLaunching,
                  let bundle = app.bundleIdentifier,
                  byBundle[bundle] != nil,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            else { return nil }
            return RunningApp(pid: app.processIdentifier, bundleIdentifier: bundle,
                              name: app.localizedName ?? bundle)
        }
        let checker = probe
        let results = await Task.detached { () -> [pid_t: AppProbeResult] in
            await withTaskGroup(of: (pid_t, AppProbeResult).self) { group in
                for app in apps {
                    group.addTask { (app.pid, checker.probe(pid: app.pid)) }
                }
                var values: [pid_t: AppProbeResult] = [:]
                for await (pid, result) in group { values[pid] = result }
                return values
            }
        }.value
        guard !Task.isCancelled else { return }

        let alerted = tracker.update(results: results, activePIDs: Set(apps.map(\.pid)))
        unresponsiveApps = apps.filter { alerted.contains($0.pid) }.sorted { $0.name < $1.name }
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        var visible: Set<pid_t> = []
        for app in apps where alerted.contains(app.pid) {
            guard let item = byBundle[app.bundleIdentifier]?.first,
                  screenHeight > 0 else { continue }
            let frame = ScreenCoordinates.appKitRect(fromAX: item.frame, primaryScreenHeight: screenHeight)
            guard NSScreen.screens.contains(where: { $0.frame.intersects(frame) }) else { continue }
            visible.insert(app.pid)
            showBadge(for: app, iconFrame: frame)
        }
        for pid in Set(badges.keys).subtracting(visible) { removeBadge(for: pid) }
    }

    private func showBadge(for app: RunningApp, iconFrame: CGRect) {
        let size: CGFloat = 24
        let frame = CGRect(x: iconFrame.maxX - size * 0.8,
                           y: iconFrame.maxY - size * 0.8,
                           width: size, height: size)
        if let badge = badges[app.pid] {
            badge.panel.setFrame(frame, display: true)
            return
        }

        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false

        let button = NSButton(frame: CGRect(origin: .zero, size: frame.size))
        button.isBordered = false
        button.image = NSImage(systemSymbolName: "exclamationmark.circle.fill",
                               accessibilityDescription: "App not responding")
        button.imageScaling = .scaleProportionallyUpOrDown
        button.contentTintColor = .systemRed
        button.toolTip = "\(app.name) is not responding. Force Quit…"
        button.setAccessibilityLabel("\(app.name) is not responding. Force Quit")
        let action = BadgeAction { [weak self] in self?.confirmForceQuit(app) }
        button.target = action
        button.action = #selector(BadgeAction.clicked)
        panel.contentView = button
        panel.orderFrontRegardless()
        badges[app.pid] = Badge(panel: panel, action: action)
    }

    func confirmForceQuit(_ app: RunningApp) {
        guard let running = NSRunningApplication(processIdentifier: app.pid),
              running.bundleIdentifier == app.bundleIdentifier else { return }
        let alert = NSAlert()
        alert.messageText = "Force Quit \(app.name)?"
        alert.informativeText = "Unsaved changes in this app will be lost."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Force Quit")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        _ = running.forceTerminate()
    }

    private func removeBadge(for pid: pid_t) {
        badges.removeValue(forKey: pid)?.panel.close()
    }

    private func clearBadges() {
        for pid in Array(badges.keys) { removeBadge(for: pid) }
    }
}
