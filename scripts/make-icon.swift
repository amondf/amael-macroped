// Renders the app icon (1024×1024 PNG). Usage: swift scripts/make-icon.swift <out.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Background: rounded "squircle" with a warm gradient (LED glow).
let bg = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 200, yRadius: 200)
NSGradient(colors: [NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 1),
                    NSColor(calibratedRed: 0.22, green: 0.13, blue: 0.06, alpha: 1)])!.draw(in: bg, angle: -90)

// Acrylic plate.
let plate = NSBezierPath(roundedRect: NSRect(x: 150, y: 330, width: 724, height: 360), xRadius: 56, yRadius: 56)
NSGradient(colors: [NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.22, alpha: 0.95),
                    NSColor(calibratedRed: 0.95, green: 0.38, blue: 0.08, alpha: 0.95)])!.draw(in: plate, angle: -90)

// Three keycaps.
for i in 0..<3 {
    let x = 196 + CGFloat(i) * 168
    let shadow = NSBezierPath(roundedRect: NSRect(x: x, y: 400, width: 140, height: 140), xRadius: 22, yRadius: 22)
    NSColor(calibratedWhite: 0, alpha: 0.35).setFill()
    shadow.fill()
    let cap = NSBezierPath(roundedRect: NSRect(x: x, y: 420, width: 140, height: 140), xRadius: 22, yRadius: 22)
    NSGradient(colors: [NSColor(calibratedWhite: 0.28, alpha: 1), NSColor(calibratedWhite: 0.08, alpha: 1)])!.draw(in: cap, angle: -90)
}

// Knob.
let knobRect = NSRect(x: 700, y: 405, width: 150, height: 150)
NSGradient(colors: [NSColor(calibratedWhite: 0.55, alpha: 1), NSColor(calibratedWhite: 0.05, alpha: 1)])!
    .draw(in: NSBezierPath(ovalIn: knobRect), angle: -90)
NSColor(calibratedWhite: 0.85, alpha: 1).setStroke()
let ring = NSBezierPath(ovalIn: knobRect.insetBy(dx: 14, dy: 14))
ring.lineWidth = 6
ring.stroke()
let tick = NSBezierPath()
tick.move(to: NSPoint(x: knobRect.midX, y: knobRect.maxY - 22))
tick.line(to: NSPoint(x: knobRect.midX, y: knobRect.maxY - 58))
tick.lineWidth = 10
tick.lineCapStyle = .round
NSColor.white.setStroke()
tick.stroke()

// Wordmark.
let style = NSMutableParagraphStyle()
style.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 120, weight: .heavy),
    .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.66, blue: 0.3, alpha: 1),
    .paragraphStyle: style,
]
NSString(string: "AMAEL").draw(in: NSRect(x: 64, y: 140, width: 896, height: 150), withAttributes: attrs)

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
