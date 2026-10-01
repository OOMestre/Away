import AppKit
import AwayCore
import SwiftUI

/// A window preview thumbnail card displaying an application window with
/// macOS-style window control buttons (Close, Minimize, Full Screen) that appear on hover.
public struct WindowThumbnailView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let id: String
    public let title: String
    public let isMinimized: Bool
    public let isFullScreen: Bool
    public let aspectRatio: CGFloat
    public let thumbnailImage: CGImage?

    public var onAction: ((WindowControlAction) -> Void)?
    public var onSelect: (() -> Void)?

    @State private var isHovered = false
    @State private var actionError: String?

    public init(
        item: WindowPreviewItem,
        thumbnail: CGImage? = nil,
        onAction: ((WindowControlAction) -> Void)? = nil,
        onSelect: (() -> Void)? = nil
    ) {
        self.id = "\(item.processID)-\(item.id)"
        self.title = item.title
        self.isMinimized = item.isMinimized
        self.isFullScreen = item.isFullScreen
        let width = item.frame.width > 0 ? item.frame.width : 16
        let height = item.frame.height > 0 ? item.frame.height : 10
        let ratio = width / height
        self.aspectRatio = min(max(ratio, 1.1), 1.9)
        self.thumbnailImage = thumbnail
        self.onAction = onAction
        self.onSelect = onSelect
    }

    public init(
        window: WindowInfo,
        thumbnail: CGImage? = nil,
        onAction: ((WindowControlAction) -> Void)? = nil,
        onSelect: (() -> Void)? = nil
    ) {
        self.id = "\(window.pid)-\(CFHash(window.element.element))"
        self.title = window.title
        self.isMinimized = window.isMinimized
        self.isFullScreen = window.isFullScreen
        let width = window.frame?.width ?? 16
        let height = window.frame?.height ?? 10
        let ratio = height > 0 ? (width / height) : (16.0 / 10.0)
        self.aspectRatio = min(max(ratio, 1.1), 1.9)
        self.thumbnailImage = thumbnail
        self.onAction = onAction
        self.onSelect = onSelect
    }

    public init(
        id: String,
        title: String,
        isMinimized: Bool = false,
        isFullScreen: Bool = false,
        aspectRatio: CGFloat = 16.0 / 10.0,
        thumbnail: CGImage? = nil,
        onAction: ((WindowControlAction) -> Void)? = nil,
        onSelect: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.isMinimized = isMinimized
        self.isFullScreen = isFullScreen
        self.aspectRatio = min(max(aspectRatio, 1.1), 1.9)
        self.thumbnailImage = thumbnail
        self.onAction = onAction
        self.onSelect = onSelect
    }

    public var body: some View {
        Button {
            onSelect?()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { isHovered = $0 }
        .help(title.isEmpty ? "Application window" : title)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title.isEmpty ? "Window thumbnail" : "Window: \(title)")
    }

    private var cardContent: some View {
        ZStack(alignment: .topLeading) {
            thumbnailCanvas

            // Bottom title footer
            VStack {
                Spacer()
                footerBar
            }

            // Top overlay with status badge and traffic light buttons
            VStack {
                HStack(alignment: .top) {
                    // Window control buttons: appear smoothly on hover
                    WindowButtonsView(
                        isMinimized: isMinimized,
                        isFullScreen: isFullScreen,
                        onAction: { action in
                            if let onAction {
                                onAction(action)
                            }
                        }
                    )
                    .opacity(isHovered ? 1.0 : 0.0)
                    .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isHovered)

                    Spacer()

                    // Optional status indicator badge
                    if isMinimized {
                        statusBadge(title: "Minimized", systemImage: "arrow.down.to.line")
                    } else if isFullScreen {
                        statusBadge(title: "Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                }
                .padding(8)

                Spacer()
            }
        }
        .frame(width: 220, height: 220 / aspectRatio)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isHovered ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.12),
                    lineWidth: isHovered ? 1.5 : 1.0
                )
        )
        .shadow(
            color: Color.black.opacity(isHovered ? 0.18 : 0.07),
            radius: isHovered ? 8 : 3,
            x: 0,
            y: isHovered ? 4 : 1
        )
        .scaleEffect(isHovered && !reduceMotion ? 1.02 : 1.0)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isHovered)
    }

    @ViewBuilder
    private var thumbnailCanvas: some View {
        if let thumbnailImage {
            Image(decorative: thumbnailImage, scale: 1.0, orientation: .up)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            // Elegant native placeholder when snapshot is not available
            ZStack {
                LinearGradient(
                    colors: [
                        Color(nsColor: .controlBackgroundColor),
                        Color(nsColor: .windowBackgroundColor)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 8) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.tertiary)

                    if !title.isEmpty {
                        Text(title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footerBar: some View {
        HStack(spacing: 4) {
            Text(title.isEmpty ? "Untitled" : title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.primary.opacity(0.08)),
            alignment: .top
        )
    }

    private func statusBadge(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
    }
}
