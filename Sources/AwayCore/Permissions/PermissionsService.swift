import AppKit
import ApplicationServices
import CoreGraphics

public enum Permission: Hashable, Sendable {
    /// Read the Dock and control other apps' windows.
    case accessibility
    /// Capture window thumbnails.
    case screenRecording
    /// Send Apple Events to one app (for example media controls).
    case automation(bundleIdentifier: String)

    var settingsAnchor: String {
        switch self {
        case .accessibility: "Privacy_Accessibility"
        case .screenRecording: "Privacy_ScreenCapture"
        case .automation: "Privacy_Automation"
        }
    }
}

public enum PermissionStatus: Equatable, Sendable {
    case granted
    case denied
    /// macOS has not asked yet, or the target app is not running (automation).
    case notDetermined
}

public protocol PermissionChecking: Sendable {
    func status(of permission: Permission) -> PermissionStatus
    /// Shows the system prompt when macOS allows it; otherwise opens System Settings.
    func request(_ permission: Permission)
    func openSystemSettings(for permission: Permission)
}

public struct SystemPermissionsService: PermissionChecking, @unchecked Sendable {
    private let defaults: UserDefaults

    /// `defaults` remembers which system prompts were already shown, because
    /// macOS shows each prompt only once; later requests open System Settings.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func status(of permission: Permission) -> PermissionStatus {
        switch permission {
        case .accessibility:
            return AXIsProcessTrusted() ? .granted : .denied
        case .screenRecording:
            return CGPreflightScreenCaptureAccess() ? .granted : .denied
        case let .automation(bundleIdentifier):
            return Self.automationStatus(bundleIdentifier: bundleIdentifier, askUser: false)
        }
    }

    public func request(_ permission: Permission) {
        switch permission {
        case .accessibility:
            guard !AXIsProcessTrusted() else { return }
            if markPrompted("accessibility") {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(options)
            } else {
                openSystemSettings(for: permission)
            }
        case .screenRecording:
            guard !CGPreflightScreenCaptureAccess() else { return }
            if markPrompted("screenRecording") {
                CGRequestScreenCaptureAccess()
            } else {
                openSystemSettings(for: permission)
            }
        case let .automation(bundleIdentifier):
            // Blocks until the user answers, so never call it on the main thread.
            Task.detached {
                if Self.automationStatus(bundleIdentifier: bundleIdentifier, askUser: true) == .denied {
                    await MainActor.run { openSystemSettings(for: permission) }
                }
            }
        }
    }

    public func openSystemSettings(for permission: Permission) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(permission.settingsAnchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Returns `true` the first time it is called for `name`.
    private func markPrompted(_ name: String) -> Bool {
        let key = "permissions.prompted.\(name)"
        guard !defaults.bool(forKey: key) else { return false }
        defaults.set(true, forKey: key)
        return true
    }

    static func automationStatus(bundleIdentifier: String, askUser: Bool) -> PermissionStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
        guard let descriptor = target.aeDesc else { return .notDetermined }
        let result = AEDeterminePermissionToAutomateTarget(descriptor, typeWildCard, typeWildCard, askUser)
        switch result {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        default: return .notDetermined
        }
    }
}
