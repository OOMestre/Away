import AwayCore
import SwiftUI

/// Displays a window title underneath a thumbnail, truncated with an ellipsis when long.
struct DockWindowTitleView: View {
    let title: String
    let fallbackAppName: String?
    let maxWidth: CGFloat?
    let alignment: Alignment

    init(
        title: String,
        fallbackAppName: String? = nil,
        maxWidth: CGFloat? = nil,
        alignment: Alignment = .leading
    ) {
        self.title = title
        self.fallbackAppName = fallbackAppName
        self.maxWidth = maxWidth
        self.alignment = alignment
    }

    var displayTitle: String {
        WindowTitleFormatter.displayTitle(for: title, fallbackAppName: fallbackAppName)
    }

    var body: some View {
        Text(displayTitle)
            .font(.caption2)
            .fontWeight(.medium)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: maxWidth, alignment: alignment)
            .help(displayTitle)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(displayTitle)
    }
}
