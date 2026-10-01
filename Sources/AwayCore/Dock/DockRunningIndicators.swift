import Foundation

public enum DockIndicatorStyle: String, CaseIterable, Sendable {
    case line
    case bar
    case glow
}

/// Owns the reversible native-dot change and the local appearance settings.
/// The saved value distinguishes an absent Dock key from an explicit `false`.
public actor DockRunningIndicators {
    private enum Key {
        static let enabled = "running-indicators.enabled"
        static let style = "running-indicators.style"
        static let color = "running-indicators.color"
        static let previous = "running-indicators.previous"
        static let wasAbsent = "running-indicators.was-absent"
    }

    private let dock: DockPreferencesStore
    private let settings: PreferencesDomain

    public init(dock: DockPreferencesStore, settings: PreferencesDomain) {
        self.dock = dock
        self.settings = settings
    }

    public var isEnabled: Bool { settings.value(forKey: Key.enabled)?.boolValue ?? false }
    public var style: DockIndicatorStyle {
        DockIndicatorStyle(rawValue: settings.value(forKey: Key.style)?.stringValue ?? "") ?? .line
    }
    public var colorHex: String { settings.value(forKey: Key.color)?.stringValue ?? "#4A9EFF" }

    public func setStyle(_ style: DockIndicatorStyle) {
        settings.setValue(.string(style.rawValue), forKey: Key.style)
        settings.synchronize()
    }

    public func setColorHex(_ hex: String) {
        guard hex.count == 7, hex.first == "#",
              hex.dropFirst().allSatisfy({ $0.isHexDigit }) else { return }
        settings.setValue(.string(hex.uppercased()), forKey: Key.color)
        settings.synchronize()
    }

    public func setEnabled(_ enabled: Bool) async throws {
        guard enabled != isEnabled else { return }
        if enabled {
            let previous = await dock.value(for: .showProcessIndicators)
            settings.setValue(previous, forKey: Key.previous)
            settings.setValue(.bool(previous == nil), forKey: Key.wasAbsent)
            settings.setValue(.bool(true), forKey: Key.enabled)
            settings.synchronize()
            do {
                try await dock.apply([.init(.showProcessIndicators, .bool(false))], recordUndo: false)
            } catch {
                settings.setValue(.bool(false), forKey: Key.enabled)
                clearPrevious()
                throw error
            }
        } else {
            try await restoreNativeIndicators()
            settings.setValue(.bool(false), forKey: Key.enabled)
            clearPrevious()
        }
    }

    /// Re-applies the setting on relaunch, including after an interrupted enable.
    public func resume() async throws {
        guard isEnabled else { return }
        try await dock.apply([.init(.showProcessIndicators, .bool(false))], recordUndo: false)
    }

    /// The overlay disappears when Away quits, so show native dots until relaunch.
    public func suspend() async throws {
        guard isEnabled else { return }
        try await restoreNativeIndicators()
    }

    private func restoreNativeIndicators() async throws {
        let previous: PropertyListValue? = settings.value(forKey: Key.wasAbsent)?.boolValue == true
            ? nil : settings.value(forKey: Key.previous)
        try await dock.apply([.init(.showProcessIndicators, previous)], recordUndo: false)
    }

    private func clearPrevious() {
        settings.setValue(nil, forKey: Key.previous)
        settings.setValue(nil, forKey: Key.wasAbsent)
        settings.synchronize()
    }
}
