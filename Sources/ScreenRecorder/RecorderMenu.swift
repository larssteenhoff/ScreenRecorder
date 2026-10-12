import SwiftUI

/// The menu that opens from the menu bar icon.
struct RecorderMenu: View {
    @ObservedObject var recorder: Recorder
    @ObservedObject var presets: PresetStore
    let showPresets: () -> Void

    var body: some View {
        if recorder.isRecording {
            if let startDate = recorder.startDate {
                Text("Recording since \(startDate.formatted(date: .omitted, time: .standard))")
            }
            Button("Stop Recording") { recorder.stop() }
                .keyboardShortcut(".", modifiers: .command)
        } else {
            recordSection
        }

        Divider()
        optionsSection

        Divider()
        exportSection

        if let message = recorder.statusMessage {
            Divider()
            Text(message)
        }

        Divider()
        Button("Show Recordings in Finder") { recorder.revealRecordings() }
        Button("Export Presets…", action: showPresets)
        .keyboardShortcut(",", modifiers: .command)
        Button("Quit Screen Recorder") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }

    @ViewBuilder
    private var recordSection: some View {
        if recorder.isStarting {
            Text("Starting…")
        }
        ForEach(recorder.displays) { display in
            Button("Record \(display.name)") { recorder.recordDisplay(display) }
        }
        .disabled(recorder.isStarting)
        Button("Record Window or App…") { recorder.chooseContent() }
            .disabled(recorder.isStarting)
    }

    @ViewBuilder
    private var optionsSection: some View {
        Toggle("System Audio", isOn: $recorder.captureSystemAudio)
        Toggle("Microphone", isOn: $recorder.captureMicrophone)
        Toggle("Show Cursor", isOn: $recorder.showsCursor)
        Picker("Recording Format", selection: $recorder.recordingFormat) {
            ForEach(ExportContainer.allCases) { format in
                Text(format.title).tag(format)
            }
        }
        .disabled(recorder.isRecording)
        Picker("Frame Rate", selection: $recorder.frameRate) {
            ForEach(Recorder.frameRates, id: \.self) { rate in
                Text("\(rate) fps").tag(rate)
            }
        }
        .disabled(recorder.isRecording)
    }

    @ViewBuilder
    private var exportSection: some View {
        if let progress = recorder.exportProgress {
            Text("Exporting… \(Int(progress * 100))%")
        }
        Menu("Export Last Recording") {
            ForEach(presets.presets) { preset in
                Button(preset.name) { recorder.export(with: preset) }
            }
        }
        .disabled(recorder.lastRecording == nil || recorder.exportProgress != nil)
        Picker("Auto-Export After Recording", selection: $presets.autoExportPresetID) {
            Text("Off").tag(UUID?.none)
            ForEach(presets.presets) { preset in
                Text(preset.name).tag(UUID?.some(preset.id))
            }
        }
    }
}
