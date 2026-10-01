import Foundation
import Observation

/// Configuration settings for Dock hover window previews.
public struct DockPreviewSettings: Equatable, Sendable {
    public static let defaultHoverDelay: TimeInterval = 0.3
    public static let minHoverDelay: TimeInterval = 0.05
    public static let maxHoverDelay: TimeInterval = 2.0
    public static let defaultThumbnailWidth: CGFloat = 220
    public static let minThumbnailWidth: CGFloat = 140
    public static let maxThumbnailWidth: CGFloat = 360

    public var isEnabled: Bool
    public var hoverDelay: TimeInterval
    public var thumbnailWidth: CGFloat
    public var showTitles: Bool
    public var showWindowButtons: Bool
    public var showQuickActions: Bool

    public init(
        isEnabled: Bool = true,
        hoverDelay: TimeInterval = Self.defaultHoverDelay,
        thumbnailWidth: CGFloat = Self.defaultThumbnailWidth,
        showTitles: Bool = true,
        showWindowButtons: Bool = true,
        showQuickActions: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.hoverDelay = min(max(hoverDelay, Self.minHoverDelay), Self.maxHoverDelay)
        self.thumbnailWidth = min(max(thumbnailWidth, Self.minThumbnailWidth), Self.maxThumbnailWidth)
        self.showTitles = showTitles
        self.showWindowButtons = showWindowButtons
        self.showQuickActions = showQuickActions
    }
}

/// Persists preview configuration in user defaults.
@MainActor
@Observable
public final class DockPreviewSettingsStore {
    public static let enabledKey = "dock.previews.enabled"
    public static let delayKey = "dock.previews.delay"
    public static let widthKey = "dock.previews.width"
    public static let titlesKey = "dock.previews.showTitles"
    public static let showButtonsKey = "dock.previews.showButtons"
    public static let quickActionsKey = "dock.previews.showQuickActions"

    private let defaults: UserDefaults

    public var settings: DockPreviewSettings {
        didSet { save() }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        let delay = defaults.object(forKey: Self.delayKey) as? Double ?? DockPreviewSettings.defaultHoverDelay
        let width = defaults.object(forKey: Self.widthKey) as? Double ?? Double(DockPreviewSettings.defaultThumbnailWidth)
        let titles = defaults.object(forKey: Self.titlesKey) as? Bool ?? true
        let showButtons = defaults.object(forKey: Self.showButtonsKey) as? Bool ?? true
        let quickActions = defaults.object(forKey: Self.quickActionsKey) as? Bool ?? true

        self.settings = DockPreviewSettings(
            isEnabled: isEnabled,
            hoverDelay: delay,
            thumbnailWidth: CGFloat(width),
            showTitles: titles,
            showWindowButtons: showButtons,
            showQuickActions: quickActions
        )
    }

    private func save() {
        defaults.set(settings.isEnabled, forKey: Self.enabledKey)
        defaults.set(settings.hoverDelay, forKey: Self.delayKey)
        defaults.set(Double(settings.thumbnailWidth), forKey: Self.widthKey)
        defaults.set(settings.showTitles, forKey: Self.titlesKey)
        defaults.set(settings.showWindowButtons, forKey: Self.showButtonsKey)
        defaults.set(settings.showQuickActions, forKey: Self.quickActionsKey)
    }
}
