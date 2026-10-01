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

        let settingsStore = DockPreviewSettingsStore()
        let thumbnailService = ScreenCaptureKitThumbnailService(windowManager: windows)
        let panel = DockPreviewPanel()
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
        previewCoordinator.start()
    }
}
