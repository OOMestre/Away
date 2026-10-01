import AwayCore
import SwiftUI

@main
@MainActor
struct AwayApp: App {
    @NSApplicationDelegateAdaptor(AwayApplicationDelegate.self) private var delegate
    @State private var services = AppServices()

    init() {
        // Launched as a bare SwiftPM executable during development; promote it
        // to a regular foreground app so the window appears in front.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Away") {
            ContentView()
                .environment(services)
                .frame(minWidth: 760, minHeight: 500)
                .task {
                    delegate.services = services
                    services.unresponsiveAlerts.start()
                    await services.resumeIndicators()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { await services.resumeIndicators() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .awayDockPreferencesChanged)) { _ in
                    // Undo, restore or reset can bring the native dots back
                    // while custom indicators are on.
                    Task { await services.resumeIndicators() }
                }
        }
        .windowResizability(.contentMinSize)
    }
}

@MainActor
final class AwayApplicationDelegate: NSObject, NSApplicationDelegate {
    var services: AppServices?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let services else { return .terminateNow }
        Task {
            do {
                try await services.suspendIndicators()
                sender.reply(toApplicationShouldTerminate: true)
            } catch {
                sender.reply(toApplicationShouldTerminate: false)
            }
        }
        return .terminateLater
    }
}
