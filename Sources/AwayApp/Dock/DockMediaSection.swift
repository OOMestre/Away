import AwayCore
import AppKit
import SwiftUI

struct DockMediaSection: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        Section("Media Controls") {
            Text("Hover over a running Music or Spotify icon in the Dock to see the current track and control playback in the preview.")
            Text("Accessibility lets Away detect the Dock icon. Automation is requested separately for each player when you choose Allow in its preview.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
