// Renders Screenie's app icon into the asset catalog.
// Usage: swift scripts/make-icon.swift   (from the repo root)
//
// Design: the menu bar glyph (a ring with a center dot) in white on a blue
// rounded square, laid out on Apple's macOS icon grid (824 pt body on a
// 1024 pt canvas, ~185 pt corner radius, soft drop shadow).

import AppKit

let outDir = URL(fileURLWithPath: "Screenie/Assets.xcassets/AppIcon.appiconset")

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    let s = CGFloat(pixels) / 1024
    cg.scaleBy(x: s, y: s)

    // Body with drop shadow.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 28,
                 color: CGColor(gray: 0, alpha: 0.3))
    cg.addPath(bodyPath)
    cg.setFillColor(CGColor(gray: 0, alpha: 1))
    cg.fillPath()
    cg.restoreGState()

    // Vertical blue gradient, lighter at the top.
    cg.saveGState()
    cg.addPath(bodyPath)
    cg.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [CGColor(srgbRed: 0.31, green: 0.62, blue: 1.0, alpha: 1),
                 CGColor(srgbRed: 0.09, green: 0.36, blue: 0.90, alpha: 1)] as CFArray,
        locations: [0, 1])!
    cg.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924),
                          end: CGPoint(x: 512, y: 100), options: [])
    cg.restoreGState()

    // Glyph: ring plus center dot, as in the "unseen" menu bar icon.
    let center = CGPoint(x: 512, y: 512)
    cg.setStrokeColor(CGColor(gray: 1, alpha: 1))
    cg.setFillColor(CGColor(gray: 1, alpha: 1))
    cg.setLineWidth(56)
    cg.strokeEllipse(in: CGRect(x: center.x - 230, y: center.y - 230, width: 460, height: 460))
    cg.fillEllipse(in: CGRect(x: center.x - 110, y: center.y - 110, width: 220, height: 220))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// (point size, scale) pairs required by a macOS AppIcon set.
let slots: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
                           (256, 1), (256, 2), (512, 1), (512, 2)]

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
var images: [[String: String]] = []
var rendered: [Int: String] = [:]
for (size, scale) in slots {
    let pixels = size * scale
    let name = "icon_\(pixels).png"
    if rendered[pixels] == nil {
        try render(pixels: pixels).write(to: outDir.appendingPathComponent(name))
        rendered[pixels] = name
    }
    images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x",
                   "filename": name])
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outDir.appendingPathComponent("Contents.json"))

let catalog = URL(fileURLWithPath: "Screenie/Assets.xcassets/Contents.json")
try #"{"info":{"author":"xcode","version":1}}"#.data(using: .utf8)!.write(to: catalog)
print("Wrote \(rendered.count) PNGs to \(outDir.path)")
