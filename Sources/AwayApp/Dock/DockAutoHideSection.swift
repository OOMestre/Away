import AwayCore
import SwiftUI

struct DockAutoHideSection: View {
    @Environment(AppServices.self) private var services
    @State private var delay: Timing = .systemDefault
    @State private var animation: Timing = .systemDefault
    @State private var autoHide = false
    @State private var savedAutoHide = false
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var errorMessage: String?

    private enum Timing: Hashable {
        case systemDefault
        case number(Double)

        init(_ value: PropertyListValue?) {
            if let number = value?.doubleValue, number.isFinite {
                self = .number(number)
            } else {
                self = .systemDefault
            }
        }

        var value: PropertyListValue? {
            if case let .number(number) = self { return .double(number) }
            return nil
        }

        func label(isAnimation: Bool) -> String {
            switch self {
            case .systemDefault: "macOS default"
            case .number(0): "Instant (0)"
            case let .number(number):
                number.formatted() + (isAnimation ? "× default duration" : " seconds")
            }
        }
    }

    private static let choices: [Timing] = [
        .systemDefault, .number(0), .number(0.25), .number(0.5),
        .number(0.75), .number(1), .number(1.5), .number(2),
    ]

    var body: some View {
        Section {
            Toggle("Automatically hide and show the Dock", isOn: $autoHide)
                .disabled(isLoading || isWorking || services.dockPreferences == nil)

            Picker("Delay before showing", selection: $delay) {
                timingOptions(including: delay, isAnimation: false)
            }
            .disabled(isLoading || isWorking || services.dockPreferences == nil)

            Picker("Show and hide animation duration", selection: $animation) {
                timingOptions(including: animation, isAnimation: true)
            }
            .disabled(isLoading || isWorking || services.dockPreferences == nil)

            HStack {
                Button("Apply") { applySelectedTiming() }
                Button("Instant auto-hide") {
                    run([
                        DockPreferenceChange(.autohide, .bool(true)),
                        DockPreferenceChange(.autohideDelay, .double(0)),
                        DockPreferenceChange(.autohideTimeModifier, .double(0)),
                    ])
                }
                Button("Restore macOS defaults") {
                    run([
                        DockPreferenceChange(.autohide, nil),
                        DockPreferenceChange(.autohideDelay, nil),
                        DockPreferenceChange(.autohideTimeModifier, nil),
                    ])
                }
            }
            .disabled(isLoading || isWorking || services.dockPreferences == nil)

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        } header: {
            Text("Auto-hide")
        } footer: {
            Text("Instant removes the wait and animation. Applying a change briefly restarts the Dock; Away saves the previous settings for Undo.")
        }
        .task { await refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .awayDockPreferencesChanged)) { _ in
            Task { await refresh() }
        }
    }

    @ViewBuilder
    private func timingOptions(including current: Timing, isAnimation: Bool) -> some View {
        ForEach(Self.choices, id: \.self) { choice in
            Text(choice.label(isAnimation: isAnimation)).tag(choice)
        }
        if !Self.choices.contains(current) {
            Text(current.label(isAnimation: isAnimation)).tag(current)
        }
    }

    private func applySelectedTiming() {
        var changes = [
            DockPreferenceChange(.autohideDelay, delay.value),
            DockPreferenceChange(.autohideTimeModifier, animation.value),
        ]
        if autoHide != savedAutoHide {
            changes.append(DockPreferenceChange(.autohide, .bool(autoHide)))
        }
        run(changes)
    }

    private func run(_ changes: [DockPreferenceChange]) {
        guard let store = services.dockPreferences else { return }
        isWorking = true
        Task {
            do {
                if try await store.apply(changes) {
                    NotificationCenter.default.post(name: .awayDockPreferencesChanged, object: nil)
                }
                errorMessage = nil
                await refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func refresh() async {
        guard let store = services.dockPreferences else {
            isLoading = false
            return
        }
        delay = Timing(await store.value(for: .autohideDelay))
        animation = Timing(await store.value(for: .autohideTimeModifier))
        let enabled = await store.value(for: .autohide)?.boolValue ?? false
        autoHide = enabled
        savedAutoHide = enabled
        isLoading = false
    }
}
