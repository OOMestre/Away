import AppKit
import AwayCore
import SwiftUI

/// SwiftUI content rendered inside the floating Dock window preview panel.
struct DockPreviewContentView: View {
    let appTitle: String
    let appIcon: NSImage?
    let windows: [WindowPreviewItem]
    let thumbnails: [CGWindowID: CGImage]
    let thumbnailWidth: CGFloat
    let showTitles: Bool
    let showWindowButtons: Bool
    let hasScreenRecording: Bool

    /// Quick actions footer; `nil` hides it.
    let footer: DockPreviewFooterView?
    /// Extra content below the windows, such as media controls.
    let accessory: AnyView?

    let onSelect: (WindowPreviewItem) -> Void
    let onAction: (WindowControlAction, WindowPreviewItem) -> Void
    let onRequestScreenRecording: () -> Void

    init(
        appTitle: String,
        appIcon: NSImage?,
        windows: [WindowPreviewItem],
        thumbnails: [CGWindowID: CGImage],
        thumbnailWidth: CGFloat,
        showTitles: Bool,
        showWindowButtons: Bool = true,
        hasScreenRecording: Bool,
        footer: DockPreviewFooterView? = nil,
        accessory: AnyView? = nil,
        onSelect: @escaping (WindowPreviewItem) -> Void,
        onAction: @escaping (WindowControlAction, WindowPreviewItem) -> Void,
        onRequestScreenRecording: @escaping () -> Void
    ) {
        self.appTitle = appTitle
        self.appIcon = appIcon
        self.windows = windows
        self.thumbnails = thumbnails
        self.thumbnailWidth = thumbnailWidth
        self.showTitles = showTitles
        self.showWindowButtons = showWindowButtons
        self.hasScreenRecording = hasScreenRecording
        self.footer = footer
        self.accessory = accessory
        self.onSelect = onSelect
        self.onAction = onAction
        self.onRequestScreenRecording = onRequestScreenRecording
    }

    @State private var hoveredWindowID: CGWindowID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if !hasScreenRecording {
                permissionCallout
            }

            if !windows.isEmpty {
                cardsRow
            }

            if let accessory {
                accessory
            }

            if let footer {
                Divider()
                footer
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
        }
        .frame(minWidth: 260)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.secondary)
            }

            Text(appTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Text("•")
                .foregroundStyle(.secondary)

            Text(windows.count == 1 ? "1 window" : "\(windows.count) windows")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
    }

    private var permissionCallout: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.trianglebadge.exclamationmark")
                .foregroundStyle(.orange)

            Text("Screen Recording needed for thumbnails")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Allow…") {
                onRequestScreenRecording()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var cardsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(windows) { window in
                windowCard(for: window)
            }
        }
    }

    @ViewBuilder
    private func windowCard(for window: WindowPreviewItem) -> some View {
        let isHovered = hoveredWindowID == window.id
        let aspect: CGFloat = {
            if window.frame.height > 0 {
                return min(max(window.frame.width / window.frame.height, 0.8), 2.2)
            }
            return 16.0 / 10.0
        }()
        let cardHeight = thumbnailWidth / aspect

        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail container
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))

                    if let cgImage = thumbnails[window.id] {
                        Image(decorative: cgImage, scale: 2.0, orientation: .up)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else if hasScreenRecording {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "macwindow")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: thumbnailWidth, height: cardHeight)
                .opacity(window.isMinimized ? 0.55 : 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isHovered ? Color.accentColor : Color.primary.opacity(0.1),
                            lineWidth: isHovered ? 2 : 1
                        )
                )

                // Window control buttons (Close, Minimize, Full Screen) in macOS style, appearing on hover
                if showWindowButtons {
                    VStack {
                        HStack {
                            WindowButtonsView(
                                isMinimized: window.isMinimized,
                                isFullScreen: window.isFullScreen,
                                onAction: { action in
                                    onAction(action, window)
                                }
                            )
                            .opacity(isHovered ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.15), value: isHovered)

                            Spacer()
                        }
                        .padding(6)

                        Spacer()
                    }
                }

                // Minimized badge
                if window.isMinimized {
                    VStack {
                        Spacer()
                        HStack {
                            Label("Minimized", systemImage: "minus")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial, in: Capsule())
                            Spacer()
                        }
                        .padding(6)
                    }
                }
            }

            // Window title
            if showTitles {
                DockWindowTitleView(title: window.title, fallbackAppName: appTitle, maxWidth: thumbnailWidth)
                    .foregroundStyle(window.isMinimized ? .secondary : .primary)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredWindowID = hovering ? window.id : nil
        }
        .onTapGesture {
            onSelect(window)
        }
        .help(window.isMinimized ? "Click to restore and bring window to front" : "Click to bring window to front")
        .accessibilityElement(children: .contain)
        .accessibilityLabel(WindowTitleFormatter.displayTitle(for: window.title, fallbackAppName: appTitle))
        .accessibilityHint("Click to bring this window to the front")
        .accessibilityAction(named: "Focus window") {
            onSelect(window)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
    }
}
