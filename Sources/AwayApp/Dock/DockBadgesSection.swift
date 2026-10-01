import AwayCore
import SwiftUI

struct DockBadgesSection: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        Section {
            Toggle("Alert when an app stops responding", isOn: Binding(
                get: { services.unresponsiveAlerts.enabled },
                set: { services.unresponsiveAlerts.setEnabled($0) }
            ))
            ForEach(services.unresponsiveAlerts.unresponsiveApps) { app in
                LabeledContent("\(app.name) is not responding") {
                    Button("Force Quit…") {
                        services.unresponsiveAlerts.confirmForceQuit(app)
                    }
                }
            }
        } header: {
            Text("Icon Badges")
        } footer: {
            Text("Away checks open Dock apps every few seconds. Select the alert on an icon to confirm Force Quit. Accessibility permission is required.")
        }
    }
}
