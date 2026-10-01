import AwayCore
import SwiftUI

/// macOS window control buttons (traffic lights: Close, Minimize, Full Screen).
///
/// Designed to authentically replicate macOS window buttons with pixel-accurate
/// colors, borders, and inner glyphs that reveal when hovering over the button cluster.
public struct WindowButtonsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var isMinimized: Bool
    public var isFullScreen: Bool
    public var canClose: Bool
    public var canMinimize: Bool
    public var canFullScreen: Bool
    public var onAction: (WindowControlAction) -> Void

    @State private var isClusterHovered = false

    public init(
        isMinimized: Bool = false,
        isFullScreen: Bool = false,
        canClose: Bool = true,
        canMinimize: Bool = true,
        canFullScreen: Bool = true,
        onAction: @escaping (WindowControlAction) -> Void
    ) {
        self.isMinimized = isMinimized
        self.isFullScreen = isFullScreen
        self.canClose = canClose
        self.canMinimize = canMinimize
        self.canFullScreen = canFullScreen
        self.onAction = onAction
    }

    public var body: some View {
        HStack(spacing: 8) {
            button(
                action: .close,
                isEnabled: canClose,
                baseColor: Color(red: 1.0, green: 0.37, blue: 0.34),
                borderColor: Color(red: 0.88, green: 0.27, blue: 0.24),
                glyphColor: Color(red: 0.3, green: 0.0, blue: 0.0, opacity: 0.85),
                glyph: "xmark",
                glyphSize: 7,
                glyphWeight: .bold,
                label: "Close window",
                tooltip: "Close"
            )

            button(
                action: .minimize,
                isEnabled: canMinimize,
                baseColor: Color(red: 1.0, green: 0.74, blue: 0.18),
                borderColor: Color(red: 0.87, green: 0.63, blue: 0.14),
                glyphColor: Color(red: 0.38, green: 0.24, blue: 0.0, opacity: 0.85),
                glyph: "minus",
                glyphSize: 7,
                glyphWeight: .heavy,
                label: isMinimized ? "Unminimize window" : "Minimize window",
                tooltip: isMinimized ? "Unminimize" : "Minimize"
            )

            button(
                action: .fullScreen,
                isEnabled: canFullScreen,
                baseColor: Color(red: 0.15, green: 0.79, blue: 0.25),
                borderColor: Color(red: 0.1, green: 0.67, blue: 0.16),
                glyphColor: Color(red: 0.05, green: 0.28, blue: 0.05, opacity: 0.85),
                glyph: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                glyphSize: 6,
                glyphWeight: .bold,
                label: isFullScreen ? "Exit full screen" : "Enter full screen",
                tooltip: isFullScreen ? "Exit Full Screen" : "Enter Full Screen"
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
        .onHover { isClusterHovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Window controls")
    }

    @ViewBuilder
    private func button(
        action: WindowControlAction,
        isEnabled: Bool,
        baseColor: Color,
        borderColor: Color,
        glyphColor: Color,
        glyph: String,
        glyphSize: CGFloat,
        glyphWeight: Font.Weight,
        label: String,
        tooltip: String
    ) -> some View {
        Button {
            onAction(action)
        } label: {
            ZStack {
                Circle()
                    .fill(isEnabled ? baseColor : Color.secondary.opacity(0.35))
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isEnabled ? borderColor : Color.secondary.opacity(0.2),
                                lineWidth: 0.5
                            )
                    )

                if isEnabled {
                    Image(systemName: glyph)
                        .font(.system(size: glyphSize, weight: glyphWeight))
                        .foregroundStyle(glyphColor)
                        .opacity(isClusterHovered ? 1.0 : 0.0)
                        .animation(reduceMotion ? .none : .easeInOut(duration: 0.12), value: isClusterHovered)
                }
            }
            .frame(width: 12, height: 12)
            .contentShape(Circle())
        }
        .buttonStyle(WindowTrafficLightButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
        .help(tooltip)
        .accessibilityLabel(label)
    }
}

/// Custom button style for traffic lights providing a subtle native press effect.
private struct WindowTrafficLightButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && isEnabled ? 0.92 : 1.0)
            .brightness(configuration.isPressed && isEnabled ? -0.1 : 0.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
