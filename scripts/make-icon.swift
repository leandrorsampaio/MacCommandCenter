#!/usr/bin/env swift
// Renders Resources/AppIcon.icns from an SF Symbol. Run only when the icon changes:
//   swift scripts/make-icon.swift
import AppKit

let symbolName = "cup.and.saucer.fill"
let accent = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.35, alpha: 1)
let iconsetURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("build/AppIcon.iconset")

try? FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func render(size: Int) -> Data? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let side = CGFloat(size)
    let inset = side * 0.055
    let rect = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: side * 0.225, yRadius: side * 0.225)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.28, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.11, alpha: 1),
    ])?.draw(in: path, angle: -90)

    let configuration = NSImage.SymbolConfiguration(pointSize: side * 0.44, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [accent]))

    if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) {
        let target = NSRect(
            x: (side - symbol.size.width) / 2,
            y: (side - symbol.size.height) / 2,
            width: symbol.size.width,
            height: symbol.size.height
        )
        symbol.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
    }

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

let variants: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"), (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"), (256, "icon_256x256"),
    (512, "icon_256x256@2x"), (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]

for (size, name) in variants {
    guard let data = render(size: size) else {
        print("Could not render \(name)")
        continue
    }
    try? data.write(to: iconsetURL.appendingPathComponent("\(name).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", "Resources/AppIcon.icns"]
try? iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
