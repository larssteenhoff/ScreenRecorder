// Draws the Screen Recorder app icon and writes Resources/AppIcon.icns.
// Run from the project folder: swift Resources/make_icon.swift
import AppKit

/// Draws the icon at `size` pixels, on the macOS icon grid: an 824/1024 rounded square, centered.
func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let unit = size / 1024

    let body = NSRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185 * unit, yRadius: 185 * unit)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -10 * unit)
    shadow.shadowBlurRadius = 24 * unit
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.black.setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(starting: NSColor(calibratedRed: 0.24, green: 0.25, blue: 0.29, alpha: 1),
               ending: NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.11, alpha: 1))!
        .draw(in: bodyPath, angle: -90)

    let center = NSPoint(x: 512 * unit, y: 512 * unit)
    let ringRadius = 270 * unit
    let ring = NSBezierPath()
    ring.appendArc(withCenter: center, radius: ringRadius, startAngle: 0, endAngle: 360)
    ring.lineWidth = 46 * unit
    NSColor(calibratedWhite: 0.96, alpha: 1).setStroke()
    ring.stroke()

    let dotRadius = 180 * unit
    let dotRect = NSRect(x: center.x - dotRadius, y: center.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
    NSGradient(starting: NSColor(calibratedRed: 1.0, green: 0.36, blue: 0.33, alpha: 1),
               ending: NSColor(calibratedRed: 0.86, green: 0.11, blue: 0.13, alpha: 1))!
        .draw(in: NSBezierPath(ovalIn: dotRect), angle: -90)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let resources = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let png = drawIcon(size: CGFloat(points * scale)).representation(using: .png, properties: [:])!
        try png.write(to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote \(resources.path)/AppIcon.icns" : "iconutil failed")
