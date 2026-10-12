import AVFoundation

/// Size and codec of an export. Each case maps to one AVAssetExportSession preset.
enum ExportQuality: String, Codable, CaseIterable, Identifiable {
    // Native resolution first: these keep the recorded size.
    case nativeCopy
    case hevcHighest
    case h264Highest
    case proRes422
    case proRes4444
    case hevc_2160p
    case h264_2160p
    case hevc_1080p
    case h264_1080p
    case h264_720p

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nativeCopy: return "Native resolution – Original copy (no re-encode)"
        case .hevcHighest: return "Native resolution – HEVC"
        case .h264Highest: return "Native resolution – H.264"
        case .proRes422: return "Native resolution – ProRes 422"
        case .proRes4444: return "Native resolution – ProRes 4444"
        case .hevc_2160p: return "4K – HEVC"
        case .h264_2160p: return "4K – H.264"
        case .hevc_1080p: return "1080p – HEVC"
        case .h264_1080p: return "1080p – H.264"
        case .h264_720p: return "720p – H.264"
        }
    }

    var exportSessionPreset: String {
        switch self {
        case .nativeCopy: return AVAssetExportPresetPassthrough
        case .h264_720p: return AVAssetExportPreset1280x720
        case .h264_1080p: return AVAssetExportPreset1920x1080
        case .h264_2160p: return AVAssetExportPreset3840x2160
        case .h264Highest: return AVAssetExportPresetHighestQuality
        case .hevc_1080p: return AVAssetExportPresetHEVC1920x1080
        case .hevc_2160p: return AVAssetExportPresetHEVC3840x2160
        case .hevcHighest: return AVAssetExportPresetHEVCHighestQuality
        case .proRes422: return AVAssetExportPresetAppleProRes422LPCM
        case .proRes4444: return AVAssetExportPresetAppleProRes4444LPCM
        }
    }

    /// ProRes exports only go into a QuickTime (.mov) container.
    var requiresMov: Bool {
        self == .proRes422 || self == .proRes4444
    }
}

enum ExportContainer: String, Codable, CaseIterable, Identifiable {
    case mp4
    case mov

    var id: String { rawValue }
    var title: String { self == .mp4 ? "MP4" : "QuickTime (MOV)" }
    var fileType: AVFileType { self == .mp4 ? .mp4 : .mov }
    var fileExtension: String { rawValue }
}

/// A named export setting that the user saves and reuses.
struct ExportPreset: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var quality: ExportQuality
    var container: ExportContainer
    var includeAudio: Bool

    /// The container the export really uses: ProRes forces MOV.
    var effectiveContainer: ExportContainer {
        quality.requiresMov ? .mov : container
    }

    static let defaults: [ExportPreset] = [
        ExportPreset(name: "Native Resolution", quality: .hevcHighest, container: .mp4, includeAudio: true),
        ExportPreset(name: "Native Copy (No Re-encode)", quality: .nativeCopy, container: .mp4, includeAudio: true),
        ExportPreset(name: "Web 1080p", quality: .h264_1080p, container: .mp4, includeAudio: true),
        ExportPreset(name: "Small 720p", quality: .h264_720p, container: .mp4, includeAudio: true),
        ExportPreset(name: "Silent 1080p", quality: .h264_1080p, container: .mp4, includeAudio: false),
        ExportPreset(name: "Editing ProRes 422", quality: .proRes422, container: .mov, includeAudio: true),
    ]
}
