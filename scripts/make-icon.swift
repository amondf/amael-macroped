// Renders the app icon (1024×1024 PNG) in the Purge design-system icon style: a continuous
// squircle with a vivid vertical gradient and a frosted-white glyph (here, the macropad itself).
// Fallback for Xcode versions without Icon Composer support; the real icon is Resources/AmaelMacroped.icon.
// Usage: swift scripts/make-icon.swift <out.png> [blue|amber|graphite]
import AppKit

let args = Array(CommandLine.arguments.dropFirst())
let out = args.first ?? "AppIcon.png"
let variant = args.count > 1 ? args[1] : "blue"

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

let palette: (top: NSColor, bottom: NSColor, glyphBottom: NSColor, shadow: NSColor) = {
    switch variant {
    case "graphite": return (hex(0x4A4845), hex(0x1E1D1C), hex(0xDAD7D2), hex(0x000000, 0.45))
    case "amber": return (hex(0xFFB340), hex(0xF27405), hex(0xFFE7CC), hex(0x8A3A00, 0.35))
    default: return (hex(0x4DA8FF), hex(0x0088FF), hex(0xCFE6FF), hex(0x00407A, 0.35))
    }
}()

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icon grid: 824pt body centred on a 1024 canvas, with a soft drop shadow.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let drop = NSShadow()
drop.shadowColor = NSColor.black.withAlphaComponent(0.28)
drop.shadowOffset = NSSize(width: 0, height: -12)
drop.shadowBlurRadius = 28
drop.set()
palette.bottom.setFill()
squircle.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: palette.top, ending: palette.bottom)!.draw(in: squircle, angle: -90)

// Soft top sheen.
NSGraphicsContext.saveGraphicsState()
squircle.addClip()
NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
    .draw(in: NSRect(x: 100, y: 560, width: 824, height: 364), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// Glyph: the macropad plate with three key cut-outs and a knob well, plus the knob.
let plate = NSRect(x: 192, y: 362, width: 640, height: 300)
let glyph = NSBezierPath(roundedRect: plate, xRadius: 72, yRadius: 72)
for i in 0..<3 {
    glyph.append(NSBezierPath(roundedRect: NSRect(x: 240 + CGFloat(i) * 122, y: 462, width: 100, height: 100),
                              xRadius: 26, yRadius: 26))
}
let well = NSRect(x: 627, y: 427, width: 170, height: 170)
glyph.append(NSBezierPath(ovalIn: well))
glyph.windingRule = .evenOdd

let knob = NSBezierPath(ovalIn: well.insetBy(dx: 27, dy: 27))
knob.append(NSBezierPath(roundedRect: NSRect(x: well.midX - 6, y: well.maxY - 27 - 44, width: 12, height: 34),
                         xRadius: 6, yRadius: 6))
knob.windingRule = .evenOdd

for shape in [glyph, knob] {
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow()
    s.shadowColor = palette.shadow
    s.shadowOffset = NSSize(width: 0, height: -10)
    s.shadowBlurRadius = 24
    s.set()
    NSColor.white.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: .white, ending: palette.glyphBottom)!.draw(in: shape, angle: -90)
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
