import AppKit
import ApplicationServices

/// Reads the Dock's icons and their positions.
public protocol DockItemLocating: Sendable {
    /// Current Dock items, in Dock order. Empty when Accessibility is not granted.
    func items() -> [DockItem]
    /// Frame of the whole icon list in AX coordinates.
    func listFrame() -> CGRect?
}

/// Live implementation using the Dock process' Accessibility tree.
public struct AccessibilityDockItemLocator: DockItemLocating {
    public static let dockBundleIdentifier = "com.apple.dock"

    public init() {}

    public func items() -> [DockItem] {
        guard let list = Self.dockList() else { return [] }
        return list.children.enumerated().compactMap { index, element in
            Self.item(from: element, index: index)
        }
    }

    public func listFrame() -> CGRect? {
        Self.dockList()?.frame
    }

    static func dockPID() -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: dockBundleIdentifier).first?.processIdentifier
    }

    static func dockList() -> AccessibilityElement? {
        guard let pid = dockPID() else { return nil }
        return AccessibilityElement.application(pid: pid).children.first { $0.role == kAXListRole }
    }

    static func item(from element: AccessibilityElement, index: Int) -> DockItem? {
        guard element.role == "AXDockItem", let frame = element.frame else { return nil }
        return DockItem(
            index: index,
            kind: DockItemKind(subrole: element.subrole),
            title: element.title ?? "",
            frame: frame,
            url: element.url(kAXURLAttribute),
            isRunning: element.bool("AXIsApplicationRunning") ?? false
        )
    }
}
