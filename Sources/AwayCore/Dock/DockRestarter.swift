import Foundation

/// Restarts the Dock so it reloads its preferences.
public protocol DockRestarting: Sendable {
    /// Asks for a restart. Implementations coalesce bursts into one restart.
    func requestRestart()
}

/// Debounces restart requests and runs `killall Dock` once per burst,
/// so dragging a slider never restarts the Dock in a loop.
public final class CoalescingDockRestarter: DockRestarting, @unchecked Sendable {
    private let delay: Duration
    private let restart: @Sendable () -> Void
    private let lock = NSLock()
    private var pending: Task<Void, Never>?

    public init(delay: Duration = .milliseconds(400), restart: @escaping @Sendable () -> Void = { CoalescingDockRestarter.killDock() }) {
        self.delay = delay
        self.restart = restart
    }

    public func requestRestart() {
        let delay = delay
        let restart = restart
        lock.withLock {
            pending?.cancel()
            pending = Task {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                restart()
            }
        }
    }

    public static func killDock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}
