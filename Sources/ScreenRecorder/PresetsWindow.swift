import SwiftUI

/// The window where the user adds, edits and removes export presets.
struct PresetsWindow: View {
    @ObservedObject var presets: PresetStore
    @State private var selection: UUID?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(presets.presets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                Divider()
                HStack(spacing: 4) {
                    Button(action: addPreset) { Image(systemName: "plus") }
                        .help("Add a preset")
                    Button(action: removeSelected) { Image(systemName: "minus") }
                        .help("Remove the selected preset")
                        .disabled(selection == nil)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
            .frame(width: 200)

            Divider()

            Group {
                if let index = presets.presets.firstIndex(where: { $0.id == selection }) {
                    PresetEditor(preset: $presets.presets[index])
                } else {
                    Text("Select a preset, or click + to add one.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 360)
        }
        .frame(height: 280)
        .onAppear {
            if selection == nil { selection = presets.presets.first?.id }
        }
    }

    private func addPreset() {
        selection = presets.addPreset().id
    }

    private func removeSelected() {
        guard let id = selection else { return }
        presets.removePreset(id: id)
        selection = presets.presets.first?.id
    }
}

private struct PresetEditor: View {
    @Binding var preset: ExportPreset

    var body: some View {
        Form {
            TextField("Name", text: $preset.name)
            Picker("Quality", selection: $preset.quality) {
                ForEach(ExportQuality.allCases) { quality in
                    Text(quality.title).tag(quality)
                }
            }
            Picker("Format", selection: $preset.container) {
                ForEach(ExportContainer.allCases) { container in
                    Text(container.title).tag(container)
                }
            }
            .disabled(preset.quality.requiresMov)
            Toggle("Include audio", isOn: $preset.includeAudio)
            if preset.quality.requiresMov {
                Text("ProRes always exports as QuickTime (MOV).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
