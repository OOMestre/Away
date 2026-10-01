import CoreGraphics

/// Converts between AX/Quartz coordinates (origin top-left of the primary
/// screen, y grows down) and AppKit coordinates (origin bottom-left, y grows up).
public enum ScreenCoordinates {
    public static func appKitRect(fromAX rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryScreenHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    public static func axRect(fromAppKit rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        // The conversion is its own inverse.
        appKitRect(fromAX: rect, primaryScreenHeight: primaryScreenHeight)
    }
}
