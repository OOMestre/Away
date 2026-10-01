import AppKit
import AwayCore
import SwiftUI

/// Footer view placed at the bottom of the Dock window preview hover panel,
/// offering quick actions for the inspected application:
/// - New Window
/// - Relaunch app
/// - Force Quit (asks confirmation unless the app is unresponsive/frozen).
public struct DockPreviewFooterView: View {
    @Environment(AppServices.self) private var envServices: AppServices?

    private let customActions: AppQuickActionManaging?
    public let processID: pid_t
    public let appName: String

    @State private var isConfirmingForceQuit = false
    @State private var isPerformingAction = false
    @State private var errorMessage: String?

    public init(
        processID: pid_t,
        appName: String,
        actions: AppQuickActionManaging? = nil
    ) {
        self.processID = processID
        self.appName = appName
        self.customActions = actions
    }

    public init?(
        item: DockItem,
        actions: AppQuickActionManaging? = nil
    ) {
        guard item.kind == .application, item.isRunning else { return nil }
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            if let bundleID = item.bundleIdentifier {
                return $0.bundleIdentifier == bundleID
            }
            return $0.bundleURL == item.url
        }) else { return nil }

        self.init(
            processID: app.processIdentifier,
            appName: app.localizedName ?? item.title,
            actions: actions
        )
    }

    private var actionsService: AppQuickActionManaging {
        if let customActions { return customActions }
        if let envServices { return envServices.appActions }
        return SystemAppQuickActionService()
    }

    private var isAppResponsive: Bool {
        actionsService.isResponsive(pid: processID)
    }

    public var body: some View {
        VStack(spacing: 6) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            if isConfirmingForceQuit {
                confirmationView
            } else {
                actionsView
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .confirmationDialog(
            "Force quit \(appName)?",
            isPresented: $isConfirmingForceQuit,
            titleVisibility: .visible
        ) {
            Button("Force Quit", role: .destructive) {
                performForceQuit()
            }
            Button("Cancel", role: .cancel) {
                isConfirmingForceQuit = false
            }
        } message: {
            Text("Any unsaved changes will be lost.")
        }
    }

    private var actionsView: some View {
        HStack(spacing: 8) {
            if !isAppResponsive {
                Label("Not Responding", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
            }

            Spacer()

            Button {
                openNewWindow()
            } label: {
                Label("New Window", systemImage: "plus.rectangle")
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .disabled(isPerformingAction || !isAppResponsive)
            .help("Open a new window for \(appName)")

            Button {
                relaunchApp()
            } label: {
                Label("Relaunch", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .disabled(isPerformingAction)
            .help("Relaunch \(appName)")

            Button(role: .destructive) {
                handleForceQuitClicked()
            } label: {
                Label("Force Quit", systemImage: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundStyle(.red)
            .disabled(isPerformingAction)
            .help("Force quit \(appName)")
        }
    }

    private var confirmationView: some View {
        HStack(spacing: 8) {
            Text("Force quit \(appName)?")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Cancel", role: .cancel) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isConfirmingForceQuit = false
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Force Quit", role: .destructive) {
                isConfirmingForceQuit = false
                performForceQuit()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.small)
        }
        .transition(.opacity)
    }


    private func handleForceQuitClicked() {
        if !ForceQuitConfirmationPolicy.requiresConfirmation(isResponsive: isAppResponsive) {
            // App is hung / not responding: terminate immediately without asking confirmation!
            performForceQuit()
        } else {
            // App is responsive: require confirmation before force-quitting
            withAnimation(.easeInOut(duration: 0.15)) {
                isConfirmingForceQuit = true
            }
        }
    }

    private func openNewWindow() {
        isPerformingAction = true
        errorMessage = nil
        Task {
            do {
                try await actionsService.openNewWindow(for: processID)
            } catch {
                errorMessage = error.localizedDescription
            }
            isPerformingAction = false
        }
    }

    private func relaunchApp() {
        isPerformingAction = true
        errorMessage = nil
        Task {
            do {
                try await actionsService.relaunchApp(pid: processID)
            } catch {
                errorMessage = error.localizedDescription
            }
            isPerformingAction = false
        }
    }

    private func performForceQuit() {
        isPerformingAction = true
        errorMessage = nil
        do {
            try actionsService.forceQuit(pid: processID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isPerformingAction = false
    }
}
