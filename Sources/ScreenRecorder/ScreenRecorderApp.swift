import SwiftUI

@main
struct ScreenRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            RecorderMenu(recorder: appDelegate.recorder, presets: appDelegate.presets) {
                appDelegate.presetsWindow.show()
            }
        } label: {
            MenuBarIcon(recorder: appDelegate.recorder)
        }
    }
}

/// The menu bar icon: a filled record symbol while recording.
private struct MenuBarIcon: View {
    @ObservedObject var recorder: Recorder

    var body: some View {
        Image(systemName: recorder.isRecording ? "record.circle.fill" : "record.circle")
    }
}
