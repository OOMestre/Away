import Foundation

/// Areas of the Mac that Away can customize.
///
/// The order is the product roadmap: the Dock ships first, widgets and
/// wallpapers follow in later releases.
public enum CustomizationArea: String, CaseIterable, Identifiable, Sendable {
    case dock
    case widgets
    case wallpaper

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dock: "Dock"
        case .widgets: "Widgets"
        case .wallpaper: "Wallpaper"
        }
    }

    public var systemImage: String {
        switch self {
        case .dock: "dock.rectangle"
        case .widgets: "square.grid.2x2"
        case .wallpaper: "photo.on.rectangle"
        }
    }

    /// Whether the area is available in the current build.
    public var isAvailable: Bool {
        self == .dock
    }
}
