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
    let runningIndicators: DockRunningIndicators?
    let indicatorOverlay: DockIndicatorOverlay

    /// Set when the backup folder could not be created; Dock changes stay disabled.
    let setupError: String?

    init() {
        do {
            let store = DockPreferencesStore(backups: try FileDockBackupStore.applicationSupport())
            dockPreferences = store
            runningIndicators = DockRunningIndicators(
                dock: store,
                settings: SystemPreferencesDomain(domain: Bundle.main.bundleIdentifier ?? "com.oomestre.away")
            )
            setupError = nil
        } catch {
            dockPreferences = nil
            runningIndicators = nil
            setupError = error.localizedDescription
        }
        dockItems = AccessibilityDockItemLocator()
        windows = AccessibilityWindowService()
        permissions = SystemPermissionsService()
        dockHover = DockHoverMonitor()
        indicatorOverlay = DockIndicatorOverlay(locator: dockItems, hover: dockHover)
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

    func resumeIndicators() async {
        guard let runningIndicators else { return }
        do {
            guard permissions.status(of: .accessibility) == .granted else {
                indicatorOverlay.stop()
                try await runningIndicators.suspend()
                return
            }
            try await runningIndicators.resume()
            if await runningIndicators.isEnabled {
                indicatorOverlay.start(
                    style: await runningIndicators.style,
                    colorHex: await runningIndicators.colorHex
                )
            }
        } catch {
            indicatorOverlay.stop()
        }
    }

    func suspendIndicators() async throws {
        let wasEnabled = await runningIndicators?.isEnabled ?? false
        try await runningIndicators?.suspend()
        indicatorOverlay.stop()
        // The shared Dock restarter debounces by 400 ms; keep Away alive until
        // its restart request has run so the native dots are visible on exit.
        if wasEnabled { try? await Task.sleep(for: .milliseconds(650)) }
    }
}
