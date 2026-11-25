import AppKit

// Deterministic native export of design/appicon.svg. Keep the SVG as the source artwork.
// This renderer intentionally supports the supplied rectangle/gradient/stroke geometry only.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let svg = try String(contentsOf: root.appendingPathComponent("design/appicon.svg"), encoding: .utf8)
guard svg.contains("M28 62 V86 H92 V62 M60 24 V70 M43 53 L60 70 L77 53"),
      svg.contains("#54b8ff"), svg.contains("#1456d9"),
      svg.contains("rx=\"25\"") else {
    throw NSError(domain: "DropShelf.Icon", code: 1,
                  userInfo: [NSLocalizedDescriptionKey: "Artwork changed; update the native exporter to match the SVG."])
}
let folder = root.appendingPathComponent("SelfDrop/Assets.xcassets/AppIcon.appiconset")
var entries: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        guard let context = CGContext(data: nil, width: pixels, height: pixels,
            bitsPerComponent: 8, bytesPerRow: pixels * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw NSError(domain: "DropShelf.Icon", code: 2)
        }
        context.translateBy(x: 0, y: CGFloat(pixels))
        context.scaleBy(x: CGFloat(pixels) / 120, y: -CGFloat(pixels) / 120)
        context.saveGState()
        let rectangle = CGPath(roundedRect: CGRect(x: 5, y: 5, width: 110, height: 110),
                               cornerWidth: 25, cornerHeight: 25, transform: nil)
        context.addPath(rectangle)
        context.clip()
        let colors = [CGColor(red: 84 / 255, green: 184 / 255, blue: 1, alpha: 1),
                      CGColor(red: 20 / 255, green: 86 / 255, blue: 217 / 255, alpha: 1)]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray, locations: [0, 1]) else {
            throw NSError(domain: "DropShelf.Icon", code: 3)
        }
        context.drawLinearGradient(gradient, start: CGPoint(x: 5, y: 5),
                                   end: CGPoint(x: 82, y: 115),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
        context.setStrokeColor(CGColor(gray: 1, alpha: 1))
        context.setLineWidth(7)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: CGPoint(x: 28, y: 62))
        context.addLine(to: CGPoint(x: 28, y: 86))
        context.addLine(to: CGPoint(x: 92, y: 86))
        context.addLine(to: CGPoint(x: 92, y: 62))
        context.move(to: CGPoint(x: 60, y: 24))
        context.addLine(to: CGPoint(x: 60, y: 70))
        context.move(to: CGPoint(x: 43, y: 53))
        context.addLine(to: CGPoint(x: 60, y: 70))
        context.addLine(to: CGPoint(x: 77, y: 53))
        context.strokePath()
        guard let image = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw NSError(domain: "DropShelf.Icon", code: 4)
        }
        let name = "icon_\(size)x\(size)@\(scale)x.png"
        try data.write(to: folder.appendingPathComponent(name))
        entries.append(["idiom": "mac", "size": "\(size)x\(size)",
                        "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: folder.appendingPathComponent("Contents.json"))
print("Exported all 10 macOS icon slots from the supplied SVG geometry with transparent corners.")
