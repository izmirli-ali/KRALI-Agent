import AppKit
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: generate-app-icon.swift <output.png>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvasSize = NSSize(width: 1024, height: 1024)

func color(_ hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return NSColor(deviceRed: r, green: g, blue: b, alpha: alpha)
}

func polygon(_ points: [NSPoint]) -> NSBezierPath {
    let path = NSBezierPath()
    guard let first = points.first else { return path }
    path.move(to: first)
    for point in points.dropFirst() {
        path.line(to: point)
    }
    path.close()
    return path
}

let image = NSImage(size: canvasSize)
image.lockFocus()

guard let context = NSGraphicsContext.current else {
    fputs("Unable to create graphics context.\n", stderr)
    exit(2)
}

context.shouldAntialias = true
context.imageInterpolation = .high

let outerRect = NSRect(x: 54, y: 54, width: 916, height: 916)
let background = NSBezierPath(
    roundedRect: outerRect,
    xRadius: 190,
    yRadius: 190
)

let bgGradient = NSGradient(colors: [
    color(0x202124),
    color(0x0C0D0F),
    color(0x020203)
])!
bgGradient.draw(in: background, angle: -90)

NSGraphicsContext.saveGraphicsState()
let rimShadow = NSShadow()
rimShadow.shadowColor = color(0xFF4141, alpha: 0.48)
rimShadow.shadowBlurRadius = 42
rimShadow.shadowOffset = .zero
rimShadow.set()
color(0xFF4141, alpha: 0.34).setStroke()
background.lineWidth = 4
background.stroke()
NSGraphicsContext.restoreGraphicsState()

let crownPoints = [
    NSPoint(x: 225, y: 390),
    NSPoint(x: 205, y: 620),
    NSPoint(x: 395, y: 485),
    NSPoint(x: 512, y: 710),
    NSPoint(x: 635, y: 485),
    NSPoint(x: 820, y: 620),
    NSPoint(x: 795, y: 390)
]
let crown = polygon(crownPoints)

NSGraphicsContext.saveGraphicsState()
let crownShadow = NSShadow()
crownShadow.shadowColor = color(0xFF1E2D, alpha: 0.75)
crownShadow.shadowBlurRadius = 52
crownShadow.shadowOffset = .zero
crownShadow.set()

let crownGradient = NSGradient(colors: [
    color(0xFF6A67),
    color(0xFF2F3D),
    color(0xE60012),
    color(0x730008)
])!
crownGradient.draw(in: crown, angle: -90)
NSGraphicsContext.restoreGraphicsState()

color(0xFFD4D6, alpha: 0.82).setStroke()
crown.lineWidth = 3.0
crown.stroke()

let leftFacet = polygon([
    NSPoint(x: 225, y: 390),
    NSPoint(x: 205, y: 620),
    NSPoint(x: 395, y: 485),
    NSPoint(x: 485, y: 390)
])
color(0xFF9A93, alpha: 0.16).setFill()
leftFacet.fill()

let centerFacet = polygon([
    NSPoint(x: 395, y: 485),
    NSPoint(x: 512, y: 710),
    NSPoint(x: 635, y: 485),
    NSPoint(x: 550, y: 390)
])
color(0xFFFFFF, alpha: 0.11).setFill()
centerFacet.fill()

let rightFacet = polygon([
    NSPoint(x: 635, y: 485),
    NSPoint(x: 820, y: 620),
    NSPoint(x: 795, y: 390),
    NSPoint(x: 550, y: 390)
])
color(0xFF4141, alpha: 0.14).setFill()
rightFacet.fill()

let baseRect = NSRect(x: 260, y: 285, width: 504, height: 78)
let base = NSBezierPath(
    roundedRect: baseRect,
    xRadius: 18,
    yRadius: 18
)

NSGraphicsContext.saveGraphicsState()
let baseShadow = NSShadow()
baseShadow.shadowColor = color(0xFF2525, alpha: 0.65)
baseShadow.shadowBlurRadius = 28
baseShadow.shadowOffset = .zero
baseShadow.set()

let baseGradient = NSGradient(colors: [
    color(0xFF6767),
    color(0xF01824),
    color(0x8A0009)
])!
baseGradient.draw(in: base, angle: 0)
NSGraphicsContext.restoreGraphicsState()

color(0xFFD7D9, alpha: 0.78).setStroke()
base.lineWidth = 2.5
base.stroke()

let gloss = NSBezierPath(
    roundedRect: NSRect(x: 275, y: 328, width: 474, height: 13),
    xRadius: 7,
    yRadius: 7
)
color(0xFFFFFF, alpha: 0.15).setFill()
gloss.fill()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Unable to encode icon PNG.\n", stderr)
    exit(3)
}

do {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try png.write(to: outputURL)
    print("Generated KRALİ icon: \(outputURL.path)")
} catch {
    fputs("Unable to write icon: \(error.localizedDescription)\n", stderr)
    exit(4)
}
