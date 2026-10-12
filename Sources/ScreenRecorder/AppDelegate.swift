import AppKit

/// Owns the app's models. Opening the app again while it runs (Finder, Dock, `open`) shows the Export Presets window,
/// so the app is reachable even when a menu bar manager hides its icon.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let presets = PresetStore()
    private(set) lazy var recorder = Recorder(presets: presets)
    private(set) lazy var presetsWindow = PresetsWindowController(presets: presets)

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        presetsWindow.show()
        return false
    }
}
