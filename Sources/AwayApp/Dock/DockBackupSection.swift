import AwayCore
import SwiftUI

struct DockBackupSection: View {
    @Environment(AppServices.self) private var services
    @State private var canUndo = false
    @State private var hasOriginal = false
    @State private var confirmation: Confirmation?
    @State private var errorMessage: String?

    private enum Confirmation: Identifiable {
        case restoreOriginal
        case resetDefaults

        var id: Self { self }
    }

    var body: some View {
        Section {
            if let setupError = services.setupError {
                Label("Dock changes are disabled: \(setupError)", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            LabeledContent("Undo the last change Away made") {
                Button("Undo") { run { try await $0.undo() } }
                    .disabled(!canUndo)
            }
            LabeledContent("Restore the Dock exactly as it was before Away") {
                Button("Restore…") { confirmation = .restoreOriginal }
                    .disabled(!hasOriginal)
            }
            LabeledContent("Reset Dock settings to the macOS defaults, keeping your apps") {
                Button("Reset…") { confirmation = .resetDefaults }
                    .disabled(services.dockPreferences == nil)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        } header: {
            Text("Backup & Restore")
        } footer: {
            Text("Away saves your Dock settings before its first change. The Dock restarts briefly when settings are applied.")
        }
        .task { await refresh() }
        .confirmationDialog(
            confirmation == .restoreOriginal ? "Restore the original Dock?" : "Reset to the macOS defaults?",
            isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }),
            presenting: confirmation
        ) { action in
            switch action {
            case .restoreOriginal:
                Button("Restore", role: .destructive) { run { try await $0.restoreOriginal() } }
            case .resetDefaults:
                Button("Reset", role: .destructive) { run { try await $0.resetToSystemDefaults() } }
            }
        } message: { action in
            switch action {
            case .restoreOriginal:
                Text("Every Dock setting and item goes back to how it was before Away changed anything. Changes made since then are lost.")
            case .resetDefaults:
                Text("Size, position, auto-hide and other settings go back to the macOS defaults. Your apps and folders stay in the Dock. You can undo this.")
            }
        }
    }

    private func run(_ operation: @escaping (DockPreferencesStore) async throws -> Bool) {
        guard let store = services.dockPreferences else { return }
        Task {
            do {
                _ = try await operation(store)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            await refresh()
        }
    }

    private func refresh() async {
        guard let store = services.dockPreferences else { return }
        canUndo = await store.canUndo
        hasOriginal = await store.hasOriginalBackup
    }
}
