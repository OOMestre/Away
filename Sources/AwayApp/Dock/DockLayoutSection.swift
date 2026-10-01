import AwayCore
import SwiftUI

/// Block B: settings applied through the Dock's own preferences.
struct DockLayoutSection: View {
    var body: some View {
        DockAutoHideSection()
        DockRunningAppsSection()
    }
}
