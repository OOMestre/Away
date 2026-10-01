import AwayCore
import Observation
import SwiftUI

/// Now-playing state for the media app shown in the Dock preview.
@MainActor
@Observable
final class DockMediaControlsModel {
    private(set) var app: MediaApp?
    private(set) var track: MediaTrack?
    private(set) var error: String?
    private(set) var permission: PermissionStatus = .notDetermined
    private(set) var isBusy = false

    @ObservationIgnored private let media: any MediaControlling
    @ObservationIgnored private let permissions: any PermissionChecking
    @ObservationIgnored private var requestID = 0

    init(media: any MediaControlling, permissions: any PermissionChecking) {
        self.media = media
        self.permissions = permissions
    }

    /// Switches to `app` when the preview opens for it. Repeated calls for the
    /// same app keep the current state.
    func show(_ app: MediaApp) {
        guard self.app != app else { return }
        self.app = app
        track = nil
        error = nil
        isBusy = false
        permission = permissions.status(of: .automation(bundleIdentifier: app.rawValue))
        if permission == .granted { refresh() }
    }

    func allow() {
        guard let target = app else { return }
        permissions.request(.automation(bundleIdentifier: target.rawValue))
        Task {
            // macOS reports the answer asynchronously; poll briefly while the prompt is open.
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
        guard let target = app, permission == .granted, !isBusy else { return }
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
        guard let target = app else { return }
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

/// Media row shown inside the Dock preview for Music and Spotify.
struct DockMediaControlsView: View {
    @Bindable var model: DockMediaControlsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            if model.permission == .granted {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.track?.title ?? "Nothing playing")
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        if let artist = model.track?.artist, !artist.isEmpty {
                            Text(artist)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    Button("Previous track", systemImage: "backward.fill") { model.perform(.previous) }
                    Button("Play or pause", systemImage: "playpause.fill") { model.perform(.playPause) }
                    Button("Next track", systemImage: "forward.fill") { model.perform(.next) }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(model.isBusy)
            } else if let app = model.app {
                HStack {
                    Text("Allow Away to control \(app.name) to show playback controls.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Allow…", action: model.allow)
                        .controlSize(.small)
                }
            }
            if let error = model.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }
}
