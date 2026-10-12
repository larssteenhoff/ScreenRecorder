import Foundation

/// Owns the saved export presets and the auto-export choice, persisted in UserDefaults.
@MainActor
final class PresetStore: ObservableObject {
    @Published var presets: [ExportPreset] {
        didSet { save() }
    }

    /// The preset that exports each new recording automatically; nil means no auto-export.
    @Published var autoExportPresetID: UUID? {
        didSet { save() }
    }

    private static let presetsKey = "exportPresets"
    private static let autoExportKey = "autoExportPresetID"
    private let defaults = UserDefaults.standard

    init() {
        if let data = defaults.data(forKey: Self.presetsKey),
           let saved = try? JSONDecoder().decode([ExportPreset].self, from: data) {
            presets = saved
        } else {
            presets = ExportPreset.defaults
        }
        autoExportPresetID = defaults.string(forKey: Self.autoExportKey).flatMap(UUID.init(uuidString:))
    }

    var autoExportPreset: ExportPreset? {
        presets.first { $0.id == autoExportPresetID }
    }

    func addPreset() -> ExportPreset {
        let preset = ExportPreset(name: "New Preset", quality: .hevcHighest, container: .mp4, includeAudio: true)
        presets.append(preset)
        return preset
    }

    func removePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        if autoExportPresetID == id {
            autoExportPresetID = nil
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: Self.presetsKey)
        }
        defaults.set(autoExportPresetID?.uuidString, forKey: Self.autoExportKey)
    }
}
