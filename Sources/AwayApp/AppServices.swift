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
    let appActions: AppQuickActionManaging

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
        appActions = SystemAppQuickActionService()
    }

    init(
        dockPreferences: DockPreferencesStore?,
        dockItems: DockItemLocating,
        windows: WindowManaging,
        permissions: PermissionChecking,
        dockHover: DockHoverMonitor,
        appActions: AppQuickActionManaging,
        setupError: String? = nil
    ) {
        self.dockPreferences = dockPreferences
        self.dockItems = dockItems
        self.windows = windows
        self.permissions = permissions
        self.dockHover = dockHover
        self.appActions = appActions
        self.setupError = setupError
    }
}
