import AVFoundation

enum ExportError: LocalizedError {
    case cannotCreateSession(String)
    case incompatible(String)

    var errorDescription: String? {
        switch self {
        case .cannotCreateSession(let preset):
            return "Cannot export with \"\(preset)\". Choose another quality in Export Presets."
        case .incompatible(let preset):
            return "The recording cannot be exported with \"\(preset)\". Choose another quality or container in Export Presets."
        }
    }
}

/// Converts a finished recording into a new file with the settings of one preset.
enum Exporter {
    /// Writes the export next to the source file and returns its URL.
    /// `progress` receives values from 0 to 1 on an arbitrary thread.
    static func export(_ source: URL, with preset: ExportPreset, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let asset = AVURLAsset(url: source)
        let input = preset.includeAudio ? asset : try await videoOnlyComposition(of: asset)
        let container = preset.effectiveContainer
        let presetName = preset.quality.exportSessionPreset

        guard await AVAssetExportSession.compatibility(ofExportPreset: presetName, with: input, outputFileType: container.fileType) else {
            throw ExportError.incompatible(preset.name)
        }
        guard let session = AVAssetExportSession(asset: input, presetName: presetName) else {
            throw ExportError.cannotCreateSession(preset.name)
        }

        let destination = uniqueURL(for: source, preset: preset)
        let progressTask = Task {
            for await state in session.states(updateInterval: 0.2) {
                if case .exporting(let exportProgress) = state {
                    progress(exportProgress.fractionCompleted)
                }
            }
        }
        defer { progressTask.cancel() }

        try await session.export(to: destination, as: container.fileType)
        return destination
    }

    private static func videoOnlyComposition(of asset: AVURLAsset) async throws -> AVAsset {
        let composition = AVMutableComposition()
        let duration = try await asset.load(.duration)
        for track in try await asset.loadTracks(withMediaType: .video) {
            guard let target = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                continue
            }
            try target.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: .zero)
            target.preferredTransform = try await track.load(.preferredTransform)
        }
        return composition
    }

    /// "<recording> - <preset>.<ext>", with " 2", " 3" … added when that name exists.
    private static func uniqueURL(for source: URL, preset: ExportPreset) -> URL {
        let folder = source.deletingLastPathComponent()
        let base = "\(source.deletingPathExtension().lastPathComponent) - \(sanitized(preset.name))"
        let ext = preset.effectiveContainer.fileExtension
        var candidate = folder.appendingPathComponent("\(base).\(ext)")
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(index).\(ext)")
            index += 1
        }
        return candidate
    }

    private static func sanitized(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }
}
