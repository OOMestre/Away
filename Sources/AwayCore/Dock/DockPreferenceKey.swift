import Foundation

/// Keys of the `com.apple.dock` domain that Away reads or writes.
public enum DockPreferenceKey: String, CaseIterable, Codable, Sendable {
    case autohide
    case autohideDelay = "autohide-delay"
    case autohideTimeModifier = "autohide-time-modifier"
    case staticOnly = "static-only"
    case showProcessIndicators = "show-process-indicators"
    case orientation
    case tileSize = "tilesize"
    case magnification
    case largeSize = "largesize"
    case minimizeEffect = "mineffect"
    case persistentApps = "persistent-apps"
    case persistentOthers = "persistent-others"

    public static let domain = "com.apple.dock"

    /// Keys that hold the user's own Dock items. Resetting to the macOS
    /// defaults never removes them; only a full restore does.
    public var isUserContent: Bool {
        self == .persistentApps || self == .persistentOthers
    }
}

/// One pending write. A `nil` value removes the key so macOS uses its default.
public struct DockPreferenceChange: Equatable, Sendable {
    public let key: DockPreferenceKey
    public let value: PropertyListValue?

    public init(_ key: DockPreferenceKey, _ value: PropertyListValue?) {
        self.key = key
        self.value = value
    }
}
