import AwayCore
import SwiftUI

/// Dock module screen. Each feature block owns one section file so parallel
/// work on different blocks does not touch the same code.
struct DockView: View {
    var body: some View {
        Form {
            DockPermissionsSection()
            DockWindowPreviewSection()
            DockLayoutSection()
            DockBadgesSection()
            DockMediaSection()
            DockBackupSection()
        }
        .formStyle(.grouped)
        .navigationTitle("Dock")
    }
}

/// Header for blocks that are not implemented yet.
struct DockComingSoonSection: View {
    let title: String
    let summary: String

    var body: some View {
        Section(title) {
            LabeledContent(summary) {
                Text("Coming soon").foregroundStyle(.secondary)
            }
        }
    }
}
