import AppKit
import AwayCore
import SwiftUI

struct DockLayoutSection: View {
    @Environment(AppServices.self) private var services
    @State private var layouts: [DockSpacerSide: DockSpacerLayout] = [:]
    @State private var loadErrors: [DockSpacerSide: String] = [:]
    @State private var errorMessage: String?
    @State private var isEditing = false

    var body: some View {
        Section {
            if services.dockPreferences == nil {
                Text("Dock changes are unavailable.").foregroundStyle(.secondary)
            } else {
                side(.apps, title: "Apps")
                Divider()
                side(.others, title: "Folders & files")
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        } header: {
            Text("Spacers & Dividers")
        } footer: {
            Text("Add a large or small gap, then move it through the Dock with the arrow buttons. Every change can be undone in Backup & Restore.")
        }
        .task { await refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .awayDockPreferencesChanged)) { _ in
            Task { await refresh() }
        }
    }

    @ViewBuilder
    private func side(_ side: DockSpacerSide, title: String) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Menu("Add spacer") {
                Button("Large spacer") { run(side, .add(.large)) }
                Button("Small spacer") { run(side, .add(.small)) }
            }
            .disabled(isEditing || layouts[side] == nil)
            .accessibilityLabel("Add spacer to \(title)")
        }

        if let layout = layouts[side] {
            if layout.items.isEmpty {
                Text("No items on this side of the Dock.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(layout.items.indices, id: \.self) { index in
                    HStack {
                        if let size = layout.spacerSize(at: index) {
                            Label(layout.label(at: index), systemImage: size == .large ? "rectangle.dashed" : "line.3.horizontal")
                            Spacer()
                            Button { run(side, .move(index, index - 1)) } label: {
                                Image(systemName: "arrow.up")
                            }
                            .disabled(isEditing || index == 0)
                            .accessibilityLabel("Move \(layout.label(at: index)) up from position \(index + 1) in \(title)")
                            Button { run(side, .move(index, index + 1)) } label: {
                                Image(systemName: "arrow.down")
                            }
                            .disabled(isEditing || index == layout.items.count - 1)
                            .accessibilityLabel("Move \(layout.label(at: index)) down from position \(index + 1) in \(title)")
                            Button(role: .destructive) { run(side, .remove(index)) } label: {
                                Image(systemName: "trash")
                            }
                            .disabled(isEditing)
                            .accessibilityLabel("Remove \(layout.label(at: index)) from position \(index + 1) in \(title)")
                        } else {
                            Label(layout.label(at: index), systemImage: "app")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        } else if let loadError = loadErrors[side] {
            Text(loadError).foregroundStyle(.secondary)
        } else {
            ProgressView()
        }
    }

    private func run(_ side: DockSpacerSide, _ edit: DockSpacerEdit) {
        guard let store = services.dockPreferences, let layout = layouts[side], !isEditing else { return }
        isEditing = true
        Task {
            do {
                let changed = try await store.editSpacers(in: side, expected: layout.original, edit)
                errorMessage = nil
                if changed {
                    NotificationCenter.default.post(name: .awayDockPreferencesChanged, object: nil)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            await refresh()
            isEditing = false
        }
    }

    private func refresh() async {
        guard let store = services.dockPreferences else { return }
        for side in DockSpacerSide.allCases {
            do {
                layouts[side] = try await store.spacerLayout(for: side)
                loadErrors[side] = nil
            } catch {
                layouts[side] = nil
                loadErrors[side] = error.localizedDescription
            }
        }
    }
}
