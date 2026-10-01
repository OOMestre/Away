import AwayCore
import SwiftUI

@main
@MainActor
struct AwayApp: App {
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
        }
        .windowResizability(.contentMinSize)
    }
}
