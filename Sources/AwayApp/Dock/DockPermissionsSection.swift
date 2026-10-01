import AppKit
import AwayCore
import SwiftUI

struct DockPermissionsSection: View {
    @Environment(AppServices.self) private var services
    @State private var statuses: [Permission: PermissionStatus] = [:]

    private let rows: [(permission: Permission, title: String, reason: String)] = [
        (.accessibility, "Accessibility", "Read Dock icons and control windows of other apps."),
        (.screenRecording, "Screen Recording", "Show live thumbnails of open windows."),
    ]

    var body: some View {
        Section {
            ForEach(rows, id: \.title) { row in
                LabeledContent {
                    status(for: row.permission)
                } label: {
                    Text(row.title)
                    Text(row.reason)
                }
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("Away asks for a permission only when a feature needs it. Everything else keeps working without it.")
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    @ViewBuilder
    private func status(for permission: Permission) -> some View {
        if statuses[permission] == .granted {
            Label("Allowed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Button("Allow…") {
                services.permissions.request(permission)
            }
        }
    }

    private func refresh() {
        for row in rows {
            statuses[row.permission] = services.permissions.status(of: row.permission)
        }
    }
}
