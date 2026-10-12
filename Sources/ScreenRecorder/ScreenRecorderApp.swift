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

/// The menu bar icon: a record symbol in the menu bar color; while recording, its dot is red.
private struct MenuBarIcon: View {
    @ObservedObject var recorder: Recorder

    var body: some View {
        Image(nsImage: recorder.isRecording ? Self.recordingImage : Self.idleImage)
    }

    private static let symbolSize = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)

    private static let idleImage: NSImage = {
        let image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Screen Recorder")!
            .withSymbolConfiguration(symbolSize)!
        image.isTemplate = true
        return image
    }()

    /// Not a template image, so the menu bar keeps the red. The ring uses labelColor,
    /// which resolves when the menu bar draws, so it matches light and dark menu bars.
    private static let recordingImage: NSImage = {
        let colors = NSImage.SymbolConfiguration(paletteColors: [.systemRed, .labelColor])
        let image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Screen Recorder, recording")!
            .withSymbolConfiguration(symbolSize.applying(colors))!
        image.isTemplate = false
        return image
    }()
}
