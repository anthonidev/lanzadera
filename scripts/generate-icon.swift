// Genera el ícono de la app: una ventana de terminal con pestañas y paneles que despega.
//
// Desde la raíz del proyecto:
//
//     swift scripts/generate-icon.swift App/Resources/Assets.xcassets/AppIcon.appiconset
import AppKit

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
let canvas: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func drawIcon() {
    // Forma estándar de los íconos de macOS: 824 pt centrados, esquinas de 185 pt.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    color(0x1B2240).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [color(0x3A4A8C), color(0x1B2240), color(0x0E1226)])!.draw(in: body, angle: -90)

    // Estela de despegue: tres franjas diagonales que salen de abajo a la izquierda.
    let trail = [(0xFF9F0A, 0.95), (0xFF6B3D, 0.75), (0xFFD60A, 0.55)]
    for (index, (hex, alpha)) in trail.enumerated() {
        let offset = CGFloat(index) * 70
        let streak = NSBezierPath()
        streak.move(to: NSPoint(x: 60 + offset, y: 120 - offset * 0.2))
        streak.line(to: NSPoint(x: 330 + offset, y: 390 - offset * 0.2))
        streak.lineWidth = 34
        streak.lineCapStyle = .round
        color(UInt32(hex), alpha: alpha).setStroke()
        streak.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()

    // Ventana de terminal inclinada, como despegando.
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: 560, yBy: 560)
    transform.rotate(byDegrees: 12)
    transform.translateX(by: -560, yBy: -560)
    transform.concat()

    let window = NSRect(x: 290, y: 330, width: 540, height: 430)
    let windowShape = NSBezierPath(roundedRect: window, xRadius: 46, yRadius: 46)
    let windowShadow = NSShadow()
    windowShadow.shadowColor = .black.withAlphaComponent(0.45)
    windowShadow.shadowBlurRadius = 30
    windowShadow.shadowOffset = NSSize(width: 0, height: -14)
    NSGraphicsContext.saveGraphicsState()
    windowShadow.set()
    color(0x0B0D14).setFill()
    windowShape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Barra con tres pestañas de colores, como los emojis de los títulos.
    let tabColors: [UInt32] = [0xFF453A, 0x30D158, 0xBF5AF2]
    for (index, hex) in tabColors.enumerated() {
        let tab = NSRect(x: window.minX + 40 + CGFloat(index) * 160, y: window.maxY - 78, width: 140, height: 40)
        color(hex).setFill()
        NSBezierPath(roundedRect: tab, xRadius: 20, yRadius: 20).fill()
    }

    // Tres paneles separados por líneas verticales.
    let content = NSRect(x: window.minX + 30, y: window.minY + 30, width: window.width - 60, height: window.height - 140)
    color(0xF2F2F7, alpha: 0.18).setStroke()
    for index in 1...2 {
        let x = content.minX + content.width * CGFloat(index) / 3
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: x, y: content.minY))
        divider.line(to: NSPoint(x: x, y: content.maxY))
        divider.lineWidth = 8
        divider.stroke()
    }

    // Prompt ">_" en cada panel.
    for index in 0..<3 {
        let x = content.minX + content.width * CGFloat(index) / 3 + 30
        let y = content.maxY - 70
        let chevron = NSBezierPath()
        chevron.move(to: NSPoint(x: x, y: y + 34))
        chevron.line(to: NSPoint(x: x + 30, y: y + 12))
        chevron.line(to: NSPoint(x: x, y: y - 10))
        chevron.lineWidth = 14
        chevron.lineCapStyle = .round
        chevron.lineJoinStyle = .round
        color(0x64D2FF).setStroke()
        chevron.stroke()
        color(0xF2F2F7).setFill()
        NSBezierPath(roundedRect: NSRect(x: x + 44, y: y - 10, width: 44, height: 14), xRadius: 7, yRadius: 7).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: canvas, height: canvas)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Tamaños que pide macOS: 16, 32, 128, 256 y 512 pt, en @1x y @2x.
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try! render(pixels: points * scale).write(to: outputDirectory.appending(path: filename))
        images.append([
            "filename": filename,
            "idiom": "mac",
            "scale": "\(scale)x",
            "size": "\(points)x\(points)",
        ])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: outputDirectory.appending(path: "Contents.json"))
print("Ícono generado en \(outputDirectory.path)")
