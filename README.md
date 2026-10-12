# Screen Recorder

A macOS menu bar app that records the screen with ScreenCaptureKit and exports recordings with saved presets. Requires macOS 15.

## Build

```bash
./build.sh
```

Quit Screen Recorder before you run the script: it replaces the app bundle.

The script builds in Release, assembles `build/Screen Recorder.app` and signs it with the first Developer ID or Apple Development identity in the keychain (set `SIGN_IDENTITY` to choose another). A stable signing identity keeps the Screen Recording permission valid across rebuilds.

## Use

1. Open `build/Screen Recorder.app`. The record icon appears in the menu bar; the app has no Dock icon. Open the app again while it runs to show the Export Presets window, for example when a menu bar manager hides the icon.
2. Choose **Record <display>**, or **Record Window or App…** to pick with the system picker.
3. The first recording asks for Screen Recording permission. Allow Screen Recorder in System Settings → Privacy & Security → Screen & System Audio Recording, then quit and reopen Screen Recorder.
4. Choose **Stop Recording** to stop (⌘. while the menu is open). Recordings are saved as HEVC `.mov` files in `~/Movies/Screen Recorder`.

Menu options: System Audio, Microphone, Show Cursor, Frame Rate (24, 30, 60 fps).

## Export presets

- **Export Last Recording** exports the last recording with one preset and shows the result in Finder.
- **Auto-Export After Recording** exports each new recording with the chosen preset.
- **Export Presets…** opens the editor (⌘, while the menu is open). A preset has a name, a quality (native resolution as an original copy with no re-encode, HEVC, H.264 or ProRes; or HEVC or H.264 at 4K, 1080p or 720p), a format (MP4 or MOV) and an audio switch. ProRes always exports as MOV.

Exports are written next to the recording as `<recording> - <preset>.<ext>`.

## Icon

`Resources/AppIcon.icns` is drawn by `Resources/make_icon.swift`. To change the icon, edit the script and run `swift Resources/make_icon.swift`, then `./build.sh`.

## Self-test

`open -n "build/Screen Recorder.app" --args -selfTestSeconds 3 -selfTestReport /tmp/screenrecorder.txt` records the main display for 3 seconds, exports with the first preset, writes a report and quits. Quit the normal instance first.
