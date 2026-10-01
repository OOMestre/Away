import AwayCore
import SwiftUI

struct DockRunningAppsSection: View {
    @Environment(AppServices.self) private var services
    @State private var runningAppsOnly = false
    @State private var isLoading = true
    @State private var isApplying = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            Toggle("Only open apps", isOn: Binding(
                get: { runningAppsOnly },
                set: { updateRunningAppsOnly($0) }
            ))
            .disabled(isLoading || isApplying || services.dockPreferences == nil)

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        } header: {
            Text("Running Apps")
        } footer: {
            Text("Shows only apps that are currently running in the Dock. Pinned apps return when you turn this off. The Dock restarts briefly after a change.")
        }
        .task { await refresh() }
    }

    private func updateRunningAppsOnly(_ newValue: Bool) {
        guard let store = services.dockPreferences, !isApplying else { return }
        runningAppsOnly = newValue
        isApplying = true

        Task {
            do {
                try await store.apply([DockPreferenceChange(.staticOnly, .bool(newValue))])
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            runningAppsOnly = await store.value(for: .staticOnly)?.boolValue ?? false
            isApplying = false
        }
    }

    private func refresh() async {
        guard let store = services.dockPreferences else {
            isLoading = false
            return
        }
        runningAppsOnly = await store.value(for: .staticOnly)?.boolValue ?? false
        isLoading = false
    }
}
