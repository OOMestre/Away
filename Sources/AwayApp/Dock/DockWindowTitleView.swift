import AwayCore
import SwiftUI

/// Displays a window title underneath a thumbnail, truncated with an ellipsis when long.
public struct DockWindowTitleView: View {
    public let title: String
    public let fallbackAppName: String?
    public let maxWidth: CGFloat?
    public let alignment: Alignment

    public init(
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

    public init(
        window: WindowInfo,
        fallbackAppName: String? = nil,
        maxWidth: CGFloat? = nil,
        alignment: Alignment = .leading
    ) {
        self.init(
            title: window.title,
            fallbackAppName: fallbackAppName,
            maxWidth: maxWidth,
            alignment: alignment
        )
    }

    public var displayTitle: String {
        WindowTitleFormatter.displayTitle(for: title, fallbackAppName: fallbackAppName)
    }

    public var body: some View {
        Text(displayTitle)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: maxWidth, alignment: alignment)
            .help(displayTitle)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(displayTitle)
    }
}
