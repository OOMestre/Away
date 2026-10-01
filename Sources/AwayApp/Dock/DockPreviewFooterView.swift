import AwayCore
import SwiftUI

/// Footer of the Dock preview panel with app-level quick actions:
/// New Window, Relaunch and Force Quit. Force Quit asks for confirmation
/// unless the app is not responding.
struct DockPreviewFooterView: View {
    let processID: pid_t
    let appName: String
    /// Checked off the main thread by the panel; `nil` while unknown.
    let isResponsive: Bool?
    let actions: AppQuickActionManaging
    /// Called after an action that closes or replaces the app.
    let onFinished: () -> Void

    @State private var isConfirmingForceQuit = false
    @State private var isPerformingAction = false
    @State private var errorMessage: String?

    private var isHung: Bool { isResponsive == false }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            if isConfirmingForceQuit {
                confirmation
            } else {
                buttons
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            if isHung {
                Label("Not Responding", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
            }
            Spacer(minLength: 0)
            Button("New Window", systemImage: "plus.rectangle.on.rectangle") {
                run { try await actions.openNewWindow(for: processID) }
            }
            .disabled(isPerformingAction || isHung)
            .help("Open a new \(appName) window")

            Button("Relaunch", systemImage: "arrow.clockwise") {
                run(finishes: true) { try await actions.relaunchApp(pid: processID) }
            }
            .disabled(isPerformingAction)
            .help("Quit and reopen \(appName)")

            Button("Force Quit", systemImage: "xmark.octagon") {
                if ForceQuitConfirmationPolicy.requiresConfirmation(isResponsive: !isHung) {
                    isConfirmingForceQuit = true
                } else {
                    forceQuit()
                }
            }
            .disabled(isPerformingAction)
            .help("Force quit \(appName)")
        }
        .buttonStyle(.borderless)
        .labelStyle(.titleAndIcon)
        .font(.caption)
    }

    private var confirmation: some View {
        HStack(spacing: 8) {
            Text("Force quit \(appName)? Unsaved changes will be lost.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button("Cancel") { isConfirmingForceQuit = false }
                .controlSize(.small)
            Button("Force Quit", role: .destructive) {
                isConfirmingForceQuit = false
                forceQuit()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.small)
        }
    }

    private func forceQuit() {
        do {
            try actions.forceQuit(pid: processID)
            onFinished()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func run(finishes: Bool = false, _ operation: @escaping () async throws -> Void) {
        isPerformingAction = true
        errorMessage = nil
        Task {
            do {
                try await operation()
                if finishes { onFinished() }
            } catch {
                errorMessage = error.localizedDescription
            }
            isPerformingAction = false
        }
    }
}
