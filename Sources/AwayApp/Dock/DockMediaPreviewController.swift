import AppKit
import AwayCore
import Observation
import SwiftUI

@MainActor
@Observable
final class DockMediaPreviewModel {
    var app: MediaApp = .music
    var track: MediaTrack?
    var error: String?
    var permission: PermissionStatus = .notDetermined
    var isBusy = false

    @ObservationIgnored private let media: any MediaControlling
    @ObservationIgnored private let permissions: any PermissionChecking
    @ObservationIgnored private var requestID = 0

    init(media: any MediaControlling, permissions: any PermissionChecking) {
        self.media = media
        self.permissions = permissions
    }

    func show(_ app: MediaApp) {
        self.app = app
        track = nil
        error = nil
        isBusy = false
        requestID += 1
        permission = permissions.status(of: .automation(bundleIdentifier: app.rawValue))
        if permission == .granted { refresh() }
    }

    func allow() {
        let target = app
        permissions.request(.automation(bundleIdentifier: target.rawValue))
        Task { @MainActor in
            for _ in 0..<40 {
                try? await Task.sleep(for: .milliseconds(500))
                guard app == target else { return }
                permission = permissions.status(of: .automation(bundleIdentifier: target.rawValue))
                if permission == .granted {
                    refresh()
                    return
                }
            }
        }
    }

    func perform(_ action: MediaAction) {
        guard permission == .granted, !isBusy else { return }
        let target = app
        isBusy = true
        error = nil
        Task {
            do {
                try await media.perform(action, in: target)
                guard app == target else { return }
                isBusy = false
                refresh()
            } catch {
                guard app == target else { return }
                isBusy = false
                self.error = error.localizedDescription
            }
        }
    }

    func refresh() {
        let target = app
        requestID += 1
        let id = requestID
        Task {
            do {
                let result = try await media.nowPlaying(in: target)
                guard app == target, requestID == id else { return }
                track = result
                error = nil
            } catch {
                guard app == target, requestID == id else { return }
                track = nil
                self.error = error.localizedDescription
            }
        }
    }
}

private struct DockMediaPreview: View {
    @Bindable var model: DockMediaPreviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.app.name).font(.headline)
            if model.permission == .granted {
                if let track = model.track {
                    Text(track.title).fontWeight(.medium).lineLimit(1)
                    if !track.artist.isEmpty { Text(track.artist).foregroundStyle(.secondary).lineLimit(1) }
                } else {
                    Text("No current track").foregroundStyle(.secondary)
                }
                HStack {
                    Button(action: { model.perform(.previous) }) {
                        Image(systemName: "backward.end.fill")
                    }.accessibilityLabel("Previous track")
                    Button(action: { model.perform(.playPause) }) {
                        Image(systemName: "playpause.fill")
                    }.accessibilityLabel("Play or pause")
                    Button(action: { model.perform(.next) }) {
                        Image(systemName: "forward.end.fill")
                    }.accessibilityLabel("Next track")
                }
                .buttonStyle(.borderless)
                .disabled(model.isBusy)
            } else {
                Text("Allow Away to control \(model.app.name) in Automation settings.")
                    .foregroundStyle(.secondary)
                Button("Allow Automation…", action: model.allow)
            }
            if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.red).lineLimit(2)
            }
        }
        .padding(14)
        .frame(width: 260, alignment: .leading)
    }
}

@MainActor
final class DockMediaPreviewController {
    private let hover: DockHoverMonitor
    private let permissions: any PermissionChecking
    private let model: DockMediaPreviewModel
    private var panel: NSPanel?
    private var hoveredFrame: CGRect?
    private var dismissTask: Task<Void, Never>?

    init(hover: DockHoverMonitor, media: any MediaControlling, permissions: any PermissionChecking) {
        self.hover = hover
        self.permissions = permissions
        model = DockMediaPreviewModel(media: media, permissions: permissions)
    }

    func start() {
        guard permissions.status(of: .accessibility) == .granted else { return }
        hover.onChange = { [weak self] item in self?.handle(item) }
        if !hover.isRunning {
            hover.stop()
            hover.start()
        }
    }

    private func handle(_ item: DockItem?) {
        guard let item, item.isRunning,
              let bundleID = item.bundleIdentifier,
              let app = MediaApp(rawValue: bundleID) else {
            hoveredFrame = nil
            scheduleDismissal()
            return
        }
        dismissTask?.cancel()
        hoveredFrame = ScreenCoordinates.appKitRect(fromAX: item.frame, primaryScreenHeight: NSScreen.screens.first?.frame.height ?? 0)
        model.show(app)
        if let hoveredFrame { showPanel(near: hoveredFrame) }
    }

    private func showPanel(near icon: CGRect) {
        let panel = self.panel ?? makePanel()
        let screen = NSScreen.screens.first { $0.frame.intersects(icon) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        let size = panel.frame.size
        var x = icon.midX - size.width / 2
        var y = icon.maxY + 8
        if y + size.height > visible.maxY { y = icon.minY - size.height - 8 }
        x = min(max(x, visible.minX), visible.maxX - size.width)
        y = min(max(y, visible.minY), visible.maxY - size.height)
        panel.setFrameOrigin(CGPoint(x: x, y: y))
        panel.orderFront(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 288, height: 170),
                            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: DockMediaPreview(model: model))
        self.panel = panel
        return panel
    }

    private func scheduleDismissal() {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            while let panel = self.panel, panel.isVisible {
                if !panel.frame.contains(NSEvent.mouseLocation) {
                    panel.orderOut(nil)
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
            }
        }
    }
}
