import AppKit
import AwayCore

/// Transparent, click-through windows follow the Dock's Accessibility frames.
@MainActor
final class DockIndicatorOverlay {
    private struct Mark: Equatable {
        let rect: CGRect
    }

    private final class Canvas: NSView {
        var marks: [Mark] = [] { didSet { needsDisplay = true } }
        var style: DockIndicatorStyle = .line { didSet { needsDisplay = true } }
        var color: NSColor = .systemBlue { didSet { needsDisplay = true } }

        override func draw(_ dirtyRect: NSRect) {
            for mark in marks {
                let path = NSBezierPath(roundedRect: mark.rect, xRadius: 3, yRadius: 3)
                if style == .glow {
                    NSGraphicsContext.saveGraphicsState()
                    let shadow = NSShadow()
                    shadow.shadowColor = color.withAlphaComponent(0.9)
                    shadow.shadowBlurRadius = 11
                    shadow.set()
                    color.setFill()
                    path.fill()
                    NSGraphicsContext.restoreGraphicsState()
                } else {
                    color.setFill()
                    path.fill()
                }
            }
        }
    }

    private let locator: DockItemLocating
    private var windows: [NSWindow] = []
    private var task: Task<Void, Never>?
    private var style: DockIndicatorStyle = .line
    private var color: NSColor = .systemBlue

    init(locator: DockItemLocating) { self.locator = locator }

    func start(style: DockIndicatorStyle, colorHex: String) {
        self.style = style
        color = Self.color(from: colorHex)
        guard task == nil else { refresh(); return }
        refresh()
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { break }
                self?.refresh()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func refresh() {
        guard let primaryHeight = NSScreen.screens.first?.frame.height,
              let listAX = locator.listFrame() else {
            windows.forEach { ($0.contentView as? Canvas)?.marks = [] }
            return
        }
        let list = ScreenCoordinates.appKitRect(fromAX: listAX, primaryScreenHeight: primaryHeight)
        let screens = NSScreen.screens
        if windows.count != screens.count {
            windows.forEach { $0.orderOut(nil) }
            windows = screens.map { screen in
                let window = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
                window.backgroundColor = .clear
                window.isOpaque = false
                window.hasShadow = false
                window.ignoresMouseEvents = true
                window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
                window.contentView = Canvas(frame: CGRect(origin: .zero, size: screen.frame.size))
                window.orderFrontRegardless()
                return window
            }
        }
        let items = locator.items().filter { $0.kind == .application && $0.isRunning }
        for (screen, window) in zip(screens, windows) {
            if window.frame != screen.frame { window.setFrame(screen.frame, display: true) }
            guard let canvas = window.contentView as? Canvas else { continue }
            canvas.style = style
            canvas.color = color
            let orientation = DockOrientation(listFrame: list, screenFrame: screen.frame)
            canvas.marks = items.compactMap { item in
                let frame = ScreenCoordinates.appKitRect(fromAX: item.frame, primaryScreenHeight: primaryHeight)
                guard screen.frame.intersects(frame), frame.width > 0, frame.height > 0 else { return nil }
                let bar = style == .bar
                let length = min(bar ? 28 : 13, orientation == .bottom ? frame.width * 0.55 : frame.height * 0.55)
                let thickness: CGFloat = bar ? 4 : 3
                let rect: CGRect
                switch orientation {
                case .bottom:
                    rect = CGRect(x: frame.midX - length / 2, y: frame.minY + 2, width: length, height: thickness)
                case .left:
                    rect = CGRect(x: frame.minX + 2, y: frame.midY - length / 2, width: thickness, height: length)
                case .right:
                    rect = CGRect(x: frame.maxX - thickness - 2, y: frame.midY - length / 2, width: thickness, height: length)
                }
                return Mark(rect: rect.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY))
            }
        }
    }

    private static func color(from hex: String) -> NSColor {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0x4A9EFF
        return NSColor(
            calibratedRed: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}
