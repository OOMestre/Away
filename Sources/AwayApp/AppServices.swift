import AwayCore
import Observation
import SwiftUI

/// Composition root: the live services shared by every feature.
///
/// Features read these from the environment instead of creating their own,
/// so there is one Dock store, one permissions checker and one hover monitor.
@MainActor
@Observable
final class AppServices {
    let dockPreferences: DockPreferencesStore?
    let dockItems: DockItemLocating
    let windows: WindowManaging
    let permissions: PermissionChecking
    let dockHover: DockHoverMonitor
    let unresponsiveAlerts: DockUnresponsiveAlertController
    let appActions: AppQuickActionManaging
    let media: MediaControlling
    let mediaControls: DockMediaControlsModel
    let previewSettings: DockPreviewSettingsStore
    let windowThumbnails: WindowThumbnailCapturing
    let previewCoordinator: DockPreviewCoordinator

    /// Set when the backup folder could not be created; Dock changes stay disabled.
    let setupError: String?

    init() {
        do {
            dockPreferences = DockPreferencesStore(backups: try FileDockBackupStore.applicationSupport())
            setupError = nil
        } catch {
            dockPreferences = nil
            setupError = error.localizedDescription
        }
        dockItems = AccessibilityDockItemLocator()
        windows = AccessibilityWindowService()
        permissions = SystemPermissionsService()
        dockHover = DockHoverMonitor()
        unresponsiveAlerts = DockUnresponsiveAlertController(dockItems: dockItems, permissions: permissions)
        appActions = SystemAppQuickActionService()
        media = AppleScriptMediaController()
        let mediaControls = DockMediaControlsModel(media: media, permissions: permissions)
        self.mediaControls = mediaControls

        let settingsStore = DockPreviewSettingsStore()
        let thumbnailService = ScreenCaptureKitThumbnailService(windowManager: windows)
        let panel = DockPreviewPanel(quickActions: appActions)
        panel.accessoryProvider = { item in
            guard let app = item.bundleIdentifier.flatMap(MediaApp.init(rawValue:)) else { return nil }
            mediaControls.show(app)
            return AnyView(DockMediaControlsView(model: mediaControls))
        }
        previewSettings = settingsStore
        windowThumbnails = thumbnailService
        previewCoordinator = DockPreviewCoordinator(
            dockHover: dockHover,
            settingsStore: settingsStore,
            thumbnailService: thumbnailService,
            windowManager: windows,
            permissions: permissions,
            dockItems: dockItems,
            presenter: panel
        )
        // Media players stay useful with every window closed.
        previewCoordinator.showsWithoutWindows = { item in
            item.bundleIdentifier.flatMap(MediaApp.init(rawValue:)) != nil
        }
        previewCoordinator.start()
    }
}
