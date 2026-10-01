import ApplicationServices
import Foundation

/// Thin, typed wrapper over `AXUIElement`.
///
/// AX calls are synchronous IPC with the target app. Call them off the main
/// thread when the target may be slow, and keep the messaging timeout short.
public struct AccessibilityElement: @unchecked Sendable {
    public let element: AXUIElement

    public init(_ element: AXUIElement) {
        self.element = element
    }

    public static func application(pid: pid_t, messagingTimeout: Float = 0.5) -> AccessibilityElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return AccessibilityElement(element)
    }

    public func attribute<T>(_ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    public func string(_ name: String) -> String? { attribute(name) }

    public func bool(_ name: String) -> Bool? {
        (attribute(name) as NSNumber?)?.boolValue
    }

    public func url(_ name: String) -> URL? {
        (attribute(name) as NSURL?) as URL?
    }

    public func elements(_ name: String) -> [AccessibilityElement] {
        guard let values: [AXUIElement] = attribute(name) else { return [] }
        return values.map(AccessibilityElement.init)
    }

    public func element(_ name: String) -> AccessibilityElement? {
        guard let value: CFTypeRef = attribute(name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return AccessibilityElement(value as! AXUIElement)
    }

    public var role: String? { string(kAXRoleAttribute) }
    public var subrole: String? { string(kAXSubroleAttribute) }
    public var title: String? { string(kAXTitleAttribute) }
    public var children: [AccessibilityElement] { elements(kAXChildrenAttribute) }

    /// Frame in AX coordinates (origin at the top-left of the primary screen).
    public var frame: CGRect? {
        guard let position: AXValue = attribute(kAXPositionAttribute),
              let size: AXValue = attribute(kAXSizeAttribute)
        else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &origin), AXValueGetValue(size, .cgSize, &extent) else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    @discardableResult
    public func set(_ name: String, to value: CFTypeRef) -> AXError {
        AXUIElementSetAttributeValue(element, name as CFString, value)
    }

    @discardableResult
    public func perform(_ action: String) -> AXError {
        AXUIElementPerformAction(element, action as CFString)
    }

    public var pid: pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }
}

extension AccessibilityElement: Equatable, Hashable {
    public static func == (lhs: AccessibilityElement, rhs: AccessibilityElement) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(element))
    }
}
