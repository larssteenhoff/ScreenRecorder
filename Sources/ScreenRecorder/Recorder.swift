import AppKit
import AVFoundation
import ScreenCaptureKit

/// A display that the menu offers for full-screen recording.
struct DisplayChoice: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
}

enum RecorderError: LocalizedError {
    case displayNotFound

    var errorDescription: String? {
        "The display is no longer connected. Choose another display."
    }
}

/// Records a display or a window to a .mov file in ~/Movies/Screen Recorder with ScreenCaptureKit,
/// then exports it with the auto-export preset when one is set.
@MainActor
final class Recorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isStarting = false
    @Published private(set) var startDate: Date?
    @Published private(set) var lastRecording: URL?
    @Published private(set) var exportProgress: Double?
    @Published private(set) var statusMessage: String?
    @Published private(set) var displays: [DisplayChoice] = []

    @Published var captureSystemAudio: Bool { didSet { defaults.set(captureSystemAudio, forKey: Keys.systemAudio) } }
    @Published var captureMicrophone: Bool { didSet { defaults.set(captureMicrophone, forKey: Keys.microphone) } }
    @Published var showsCursor: Bool { didSet { defaults.set(showsCursor, forKey: Keys.cursor) } }
    @Published var frameRate: Int { didSet { defaults.set(frameRate, forKey: Keys.frameRate) } }

    static let frameRates = [24, 30, 60]

    let presets: PresetStore

    private let defaults = UserDefaults.standard
    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private var pendingURL: URL?
    private var screenObserver: NSObjectProtocol?

    private enum Keys {
        static let systemAudio = "captureSystemAudio"
        static let microphone = "captureMicrophone"
        static let cursor = "showsCursor"
        static let frameRate = "frameRate"
    }

    init(presets: PresetStore) {
        self.presets = presets
        defaults.register(defaults: [Keys.systemAudio: true, Keys.microphone: false, Keys.cursor: true, Keys.frameRate: 60])
        captureSystemAudio = defaults.bool(forKey: Keys.systemAudio)
        captureMicrophone = defaults.bool(forKey: Keys.microphone)
        showsCursor = defaults.bool(forKey: Keys.cursor)
        frameRate = defaults.integer(forKey: Keys.frameRate)
        super.init()
        refreshDisplays()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshDisplays() }
        }
        runSelfTestIfRequested()
    }

    static var recordingsFolder: URL {
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0].appendingPathComponent("Screen Recorder", isDirectory: true)
    }

    // MARK: Start and stop

    func recordDisplay(_ choice: DisplayChoice) {
        guard canStart else { return }
        isStarting = true
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.displayID == choice.id }) else {
                    throw RecorderError.displayNotFound
                }
                try await start(with: SCContentFilter(display: display, excludingApplications: [], exceptingWindows: []))
            } catch {
                fail(error)
            }
        }
    }

    /// Opens the system picker; the recording starts when the user picks a window, app or display.
    func chooseContent() {
        guard canStart else { return }
        let picker = SCContentSharingPicker.shared
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleWindow, .singleApplication, .singleDisplay]
        picker.defaultConfiguration = configuration
        picker.add(self)
        picker.isActive = true
        picker.present()
    }

    func stop() {
        guard let stream else { return }
        Task {
            do {
                try await stream.stopCapture()
            } catch {
                fail(error)
            }
            // The file is complete only when recordingOutputDidFinishRecording arrives.
        }
    }

    private var canStart: Bool {
        !isRecording && !isStarting
    }

    private func start(with filter: SCContentFilter) async throws {
        statusMessage = nil
        let configuration = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        configuration.width = Self.evenPixels(filter.contentRect.width * scale)
        configuration.height = Self.evenPixels(filter.contentRect.height * scale)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        configuration.showsCursor = showsCursor
        configuration.capturesAudio = captureSystemAudio
        configuration.excludesCurrentProcessAudio = true
        configuration.captureMicrophone = await microphoneAllowed()

        let url = try Self.newRecordingURL()
        let outputConfiguration = SCRecordingOutputConfiguration()
        outputConfiguration.outputURL = url
        outputConfiguration.outputFileType = .mov
        outputConfiguration.videoCodecType = .hevc

        let output = SCRecordingOutput(configuration: outputConfiguration, delegate: self)
        let newStream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try newStream.addRecordingOutput(output)
        try await newStream.startCapture()

        stream = newStream
        recordingOutput = output
        pendingURL = url
        isStarting = false
        isRecording = true
        startDate = Date()
    }

    /// Asks for microphone access when the option is on; records without the microphone when refused.
    private func microphoneAllowed() async -> Bool {
        guard captureMicrophone else { return false }
        if await AVCaptureDevice.requestAccess(for: .audio) {
            return true
        }
        statusMessage = "Recording without microphone: allow Screen Recorder in System Settings → Privacy & Security → Microphone."
        return false
    }

    private func finishRecording() {
        guard let url = pendingURL else { return }
        pendingURL = nil
        stream = nil
        recordingOutput = nil
        isRecording = false
        isStarting = false
        startDate = nil
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        lastRecording = url
        if let preset = presets.autoExportPreset {
            export(with: preset)
        }
    }

    private func fail(_ error: Error) {
        isStarting = false
        if (error as? SCStreamError)?.code == .userDeclined {
            statusMessage = "Allow Screen Recorder in System Settings → Privacy & Security → Screen & System Audio Recording, then quit and reopen Screen Recorder."
        } else {
            statusMessage = error.localizedDescription
        }
    }

    // MARK: Export

    func export(with preset: ExportPreset) {
        guard let source = lastRecording, exportProgress == nil else { return }
        exportProgress = 0
        Task {
            do {
                let destination = try await Exporter.export(source, with: preset) { value in
                    Task { @MainActor [weak self] in
                        if self?.exportProgress != nil { self?.exportProgress = value }
                    }
                }
                statusMessage = "Exported \"\(destination.lastPathComponent)\"."
                NSWorkspace.shared.activateFileViewerSelecting([destination])
            } catch {
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
            exportProgress = nil
        }
    }

    func revealRecordings() {
        let folder = Self.recordingsFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let lastRecording {
            NSWorkspace.shared.activateFileViewerSelecting([lastRecording])
        } else {
            NSWorkspace.shared.open(folder)
        }
    }

    // MARK: Self-test

    /// Test mode for checks without the menu: `-selfTestSeconds N -selfTestReport <path>`
    /// records the main display for N seconds, exports with the first preset,
    /// writes a text report to <path> and quits.
    func runSelfTestIfRequested() {
        let seconds = defaults.double(forKey: "selfTestSeconds")
        guard seconds > 0, let reportPath = defaults.string(forKey: "selfTestReport") else { return }
        Task {
            var report: [String] = []
            let mainID = (NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            if let display = displays.first(where: { $0.id == mainID }) ?? displays.first {
                report.append("display: \(display.name)")
                recordDisplay(display)
                await waitUntil(timeout: 15) { !self.isStarting }
                report.append("recording started: \(isRecording)")
                if isRecording {
                    try? await Task.sleep(for: .seconds(seconds))
                    stop()
                    await waitUntil(timeout: 15) { !self.isRecording }
                }
                report.append("recording file: \(lastRecording?.path ?? "none")")
                if let preset = presets.presets.first, lastRecording != nil {
                    export(with: preset)
                    await waitUntil(timeout: 120) { self.exportProgress == nil }
                    report.append("export preset: \(preset.name)")
                }
            } else {
                report.append("no display found")
            }
            report.append("status: \(statusMessage ?? "none")")
            try? report.joined(separator: "\n").write(toFile: reportPath, atomically: true, encoding: .utf8)
            NSApp.terminate(nil)
        }
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: Helpers

    private func refreshDisplays() {
        displays = NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            return DisplayChoice(id: number.uint32Value, name: screen.localizedName)
        }
    }

    /// Video encoders need even dimensions.
    private static func evenPixels(_ value: CGFloat) -> Int {
        max(2, Int(value.rounded()) & ~1)
    }

    private static func newRecordingURL() throws -> URL {
        let folder = recordingsFolder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let base = "Recording \(formatter.string(from: Date()))"
        var url = folder.appendingPathComponent("\(base).mov")
        var index = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) \(index).mov")
            index += 1
        }
        return url
    }
}

// MARK: - ScreenCaptureKit callbacks

extension Recorder: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            self.fail(error)
            self.finishRecording()
        }
    }
}

extension Recorder: SCRecordingOutputDelegate {
    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        Task { @MainActor in
            self.fail(error)
            self.finishRecording()
        }
    }

    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in self.finishRecording() }
    }
}

extension Recorder: SCContentSharingPickerObserver {
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in self.closePicker() }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in
            self.closePicker()
            guard self.canStart else { return }
            self.isStarting = true
            do {
                try await self.start(with: filter)
            } catch {
                self.fail(error)
            }
        }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: Error) {
        Task { @MainActor in
            self.closePicker()
            self.fail(error)
        }
    }

    private func closePicker() {
        let picker = SCContentSharingPicker.shared
        picker.remove(self)
        picker.isActive = false
    }
}
