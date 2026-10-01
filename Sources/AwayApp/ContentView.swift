import AwayCore
import SwiftUI

struct ContentView: View {
    @State private var selection: CustomizationArea? = .dock

    var body: some View {
        NavigationSplitView {
            List(CustomizationArea.allCases, selection: $selection) { area in
                Label(area.title, systemImage: area.systemImage)
                    .foregroundStyle(area.isAvailable ? .primary : .secondary)
                    .tag(area)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selection {
            case .dock:
                DockView()
            case let area?:
                AreaPlaceholderView(area: area)
            case nil:
                EmptyView()
            }
        }
    }
}

private struct AreaPlaceholderView: View {
    let area: CustomizationArea

    var body: some View {
        ContentUnavailableView(
            area.title,
            systemImage: area.systemImage,
            description: Text(area.isAvailable ? "Customization tools are on the way." : "Coming in a future release.")
        )
    }
}
