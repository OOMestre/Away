import AwayCore
import SwiftUI

/// A thumbnail card displaying a window preview with its title positioned underneath,
/// truncated with an ellipsis when long.
public struct DockWindowThumbnailCard<Thumbnail: View>: View {
    public let title: String
    public let fallbackAppName: String?
    public let width: CGFloat
    public let showTitle: Bool
    public let thumbnail: () -> Thumbnail

    public init(
        title: String,
        fallbackAppName: String? = nil,
        width: CGFloat = 200,
        showTitle: Bool = true,
        @ViewBuilder thumbnail: @escaping () -> Thumbnail
    ) {
        self.title = title
        self.fallbackAppName = fallbackAppName
        self.width = width
        self.showTitle = showTitle
        self.thumbnail = thumbnail
    }

    public init(
        window: WindowInfo,
        fallbackAppName: String? = nil,
        width: CGFloat = 200,
        showTitle: Bool = true,
        @ViewBuilder thumbnail: @escaping () -> Thumbnail
    ) {
        self.init(
            title: window.title,
            fallbackAppName: fallbackAppName,
            width: width,
            showTitle: showTitle,
            thumbnail: thumbnail
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Thumbnail container
            thumbnail()
                .frame(width: width)

            // Window title underneath the thumbnail
            if showTitle {
                DockWindowTitleView(
                    title: title,
                    fallbackAppName: fallbackAppName,
                    maxWidth: width,
                    alignment: .leading
                )
            }
        }
        .frame(width: width)
    }
}
