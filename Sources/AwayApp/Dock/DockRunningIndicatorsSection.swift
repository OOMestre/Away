import AppKit
import AwayCore
import SwiftUI

struct DockRunningIndicatorsSection: View {
    @Environment(AppServices.self) private var services
    @State private var enabled = false
    @State private var style: DockIndicatorStyle = .line
    @State private var color = Color(red: 74 / 255, green: 158 / 255, blue: 1)
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            Toggle("Custom running app indicators", isOn: Binding(
                get: { enabled },
                set: { newValue in Task { await setEnabled(newValue) } }
            ))
            .disabled(busy || services.runningIndicators == nil)

            if enabled {
                Picker("Style", selection: $style) {
                    Text("Line").tag(DockIndicatorStyle.line)
                    Text("Colored bar").tag(DockIndicatorStyle.bar)
                    Text("Glow").tag(DockIndicatorStyle.glow)
                }
                .onChange(of: style) { _, value in Task { await saveStyle(value) } }

                ColorPicker("Color", selection: $color, supportsOpacity: false)
                    .onChange(of: color) { _, value in Task { await saveColor(value) } }
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        } header: {
            Text("Running App Indicators")
        } footer: {
            Text("Requires Accessibility access and Away to stay open. Native Dock dots return when you turn this off or quit Away.")
        }
        .task { await load() }
    }

    private func load() async {
        guard let indicator = services.runningIndicators else { return }
        enabled = await indicator.isEnabled
        style = await indicator.style
        color = Self.color(from: await indicator.colorHex)
    }

    private func setEnabled(_ value: Bool) async {
        guard let indicator = services.runningIndicators else { return }
        if value && services.permissions.status(of: .accessibility) != .granted {
            services.permissions.request(.accessibility)
            errorMessage = "Allow Accessibility access, then turn on custom indicators."
            return
        }
        busy = true
        defer { busy = false }
        do {
            try await indicator.setEnabled(value)
            enabled = value
            errorMessage = nil
            if value {
                services.indicatorOverlay.start(style: style, colorHex: await indicator.colorHex)
            } else {
                services.indicatorOverlay.stop()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveStyle(_ value: DockIndicatorStyle) async {
        guard let indicator = services.runningIndicators else { return }
        await indicator.setStyle(value)
        if enabled { services.indicatorOverlay.start(style: value, colorHex: await indicator.colorHex) }
    }

    private func saveColor(_ value: Color) async {
        guard let indicator = services.runningIndicators,
              let rgb = NSColor(value).usingColorSpace(.deviceRGB) else { return }
        let hex = String(format: "#%02X%02X%02X",
            Int((rgb.redComponent * 255).rounded()),
            Int((rgb.greenComponent * 255).rounded()),
            Int((rgb.blueComponent * 255).rounded()))
        await indicator.setColorHex(hex)
        if enabled { services.indicatorOverlay.start(style: style, colorHex: hex) }
    }

    private static func color(from hex: String) -> Color {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0x4A9EFF
        return Color(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}
