import AppKit
import AwayCore
import SwiftUI

struct DockWindowPreviewSection: View {
    @Environment(AppServices.self) private var services

    @State private var hasScreenRecording = false
    @State private var hasAccessibility = false

    var body: some View {
        @Bindable var settingsStore = services.previewSettings

        Section {
            Toggle(
                "Show previews on hover",
                isOn: $settingsStore.settings.isEnabled
            )

            if settingsStore.settings.isEnabled {
                LabeledContent {
                    HStack(spacing: 12) {
                        Slider(
                            value: $settingsStore.settings.hoverDelay,
                            in: 0.05...1.50,
                            step: 0.05
                        )
                        .frame(width: 140)

                        Text(String(format: "%.2f s", settingsStore.settings.hoverDelay))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                } label: {
                    Text("Hover delay")
                    Text("Time cursor must pause over an icon before previews open.")
                }

                LabeledContent("Delay presets") {
                    HStack(spacing: 8) {
                        Button("Fast") {
                            settingsStore.settings.hoverDelay = 0.15
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Standard") {
                            settingsStore.settings.hoverDelay = 0.30
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Relaxed") {
                            settingsStore.settings.hoverDelay = 0.60
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Picker("Thumbnail size", selection: $settingsStore.settings.thumbnailWidth) {
                    Text("Compact").tag(CGFloat(180))
                    Text("Standard").tag(CGFloat(220))
                    Text("Large").tag(CGFloat(280))
                }
                .pickerStyle(.segmented)

                Toggle(
                    "Show window titles",
                    isOn: $settingsStore.settings.showTitles
                )

                Toggle(
                    "Show window action buttons",
                    isOn: $settingsStore.settings.showWindowButtons
                )
                .help("Display macOS Close, Minimize and Full Screen buttons on thumbnail hover.")

                if !hasScreenRecording {
                    LabeledContent {
                        Button("Allow…") {
                            services.permissions.request(.screenRecording)
                        }
                    } label: {
                        Label("Screen Recording permission needed", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Required for ScreenCaptureKit window thumbnails.")
                    }
                }
            }
        } header: {
            Text("Window Previews")
        } footer: {
            Text("Hover over any running app icon in the Dock to preview its open windows. Hover over any thumbnail to reveal macOS window buttons (close, minimize, full screen).")
        }
        .onAppear(perform: checkPermissions)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkPermissions()
            services.previewCoordinator.refresh()
        }
    }

    private func checkPermissions() {
        hasScreenRecording = services.permissions.status(of: .screenRecording) == .granted
        hasAccessibility = services.permissions.status(of: .accessibility) == .granted
    }
}
