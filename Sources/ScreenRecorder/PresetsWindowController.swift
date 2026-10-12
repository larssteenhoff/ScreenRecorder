import AppKit
import SwiftUI

/// Owns the Export Presets window and brings it to the front, also from a menu bar app with no Dock icon.
@MainActor
final class PresetsWindowController {
    private let presets: PresetStore
    private var window: NSWindow?

    init(presets: PresetStore) {
        self.presets = presets
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: PresetsWindow(presets: presets)))
            window.title = "Export Presets"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
