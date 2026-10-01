import AwayCore
import SwiftUI

struct DockWindowPreviewSection: View {
    @Environment(AppServices.self) private var services

    @State private var showQuickActions = true
    @State private var confirmForceQuit = true

    var body: some View {
        Section {
            Toggle("Show App Quick Actions in Preview Footer", isOn: $showQuickActions)

            if showQuickActions {
                Toggle("Ask Confirmation on Force Quit", isOn: $confirmForceQuit)
                    .padding(.leading, 12)
            }
        } header: {
            Text("Window Previews & Quick Actions")
        } footer: {
            Text("Quick actions in the preview footer allow opening a new window, relaunching, or force quitting the application. Force quit always terminates immediately without confirmation if the app is unresponsive.")
        }
    }
}
