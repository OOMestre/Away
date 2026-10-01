import CoreGraphics

/// Helper for calculating the AppKit window frame for the Dock hover preview panel.
public enum DockPreviewGeometry {
    /// Computes the target AppKit rect for positioning the preview panel adjacent to a Dock item.
    ///
    /// - Parameters:
    ///   - dockItemRect: AppKit frame of the hovered Dock item.
    ///   - panelSize: Dimensions of the preview panel to place.
    ///   - orientation: Current screen orientation of the Dock (.bottom, .left, or .right).
    ///   - screenVisibleFrame: Visible bounds of the screen containing the Dock item (excluding menu bar and Dock).
    ///   - offset: Spacing between the Dock item and the preview panel (default: 8 pt).
    /// - Returns: Clamped AppKit rectangle inside the screen bounds.
    public static func panelFrame(
        for dockItemRect: CGRect,
        panelSize: CGSize,
        orientation: DockOrientation,
        screenVisibleFrame: CGRect,
        offset: CGFloat = 8
    ) -> CGRect {
        var origin = CGPoint.zero

        switch orientation {
        case .bottom:
            // Centered horizontally directly above the Dock item
            origin.x = dockItemRect.midX - (panelSize.width / 2)
            origin.y = dockItemRect.maxY + offset

        case .left:
            // Centered vertically to the right of the Dock item
            origin.x = dockItemRect.maxX + offset
            origin.y = dockItemRect.midY - (panelSize.height / 2)

        case .right:
            // Centered vertically to the left of the Dock item
            origin.x = dockItemRect.minX - panelSize.width - offset
            origin.y = dockItemRect.midY - (panelSize.height / 2)
        }

        // Clamp within the screen's visible area so the panel does not clip off-screen
        let minX = screenVisibleFrame.minX + offset
        let maxX = max(minX, screenVisibleFrame.maxX - panelSize.width - offset)
        origin.x = min(max(origin.x, minX), maxX)

        let minY = screenVisibleFrame.minY + offset
        let maxY = max(minY, screenVisibleFrame.maxY - panelSize.height - offset)
        origin.y = min(max(origin.y, minY), maxY)

        return CGRect(origin: origin, size: panelSize)
    }
}
