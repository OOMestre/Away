import ApplicationServices
import Foundation

public enum AppProbeResult: Sendable, Equatable {
    case responsive
    case timedOut
    case unavailable
}

public protocol AppResponsivenessProbing: Sendable {
    func probe(pid: pid_t) -> AppProbeResult
}

/// AX messaging has its own timeout, so a hung process cannot hold a scan forever.
public struct AccessibilityAppResponsivenessProbe: AppResponsivenessProbing {
    public init() {}

    public func probe(pid: pid_t) -> AppProbeResult {
        let app = AccessibilityElement.application(pid: pid, messagingTimeout: 0.3)
        var value: CFTypeRef?
        switch AXUIElementCopyAttributeValue(app.element, kAXRoleAttribute as CFString, &value) {
        case .success: return .responsive
        case .cannotComplete: return .timedOut
        default: return .unavailable
        }
    }
}

/// Requires two consecutive AX timeouts and drops stale results when an app exits.
public struct UnresponsiveAppTracker: Sendable {
    private var timeoutCounts: [pid_t: Int] = [:]

    public init() {}

    public mutating func update(
        results: [pid_t: AppProbeResult],
        activePIDs: Set<pid_t>
    ) -> Set<pid_t> {
        timeoutCounts = timeoutCounts.filter { activePIDs.contains($0.key) }
        for pid in activePIDs {
            switch results[pid] {
            case .timedOut:
                timeoutCounts[pid] = min(2, (timeoutCounts[pid] ?? 0) + 1)
            case .responsive, .unavailable, .none:
                timeoutCounts.removeValue(forKey: pid)
            }
        }
        return Set(timeoutCounts.compactMap { $0.value >= 2 ? $0.key : nil })
    }
}
