import AppKit
import LanzaderaCore

/// Ícono de un proyecto listo para dibujar.
public struct ProjectIcon: Sendable {
    public let image: CGImage
    /// Tiene fondo propio (como un `apple-touch-icon`): ocupa todo el cuadro. Si es transparente, va con margen.
    public let isOpaque: Bool
    public let path: String
    /// Fecha del archivo al cargarlo: si no cambió, no se vuelve a decodificar.
    let modified: Date?
}

/// Busca y carga los íconos de los proyectos fuera del hilo principal.
///
/// `NSImage` lee `.ico` (elige la mejor resolución), `.png` y `.svg`. Se reduce a 128 px para no guardar
/// imágenes grandes en memoria. Si el archivo y su fecha no cambiaron, se reutiliza lo ya cargado.
nonisolated public enum ProjectIconLoader {
    static let pixels = 128

    @concurrent
    public static func load(for projects: [Project], reusing previous: [String: ProjectIcon]) async -> [String: ProjectIcon] {
        let finder = ProjectIconFinder(fileSize: fileSize, subdirectories: subdirectories)
        var icons: [String: ProjectIcon] = [:]
        for project in projects {
            guard let path = finder.icon(for: project) else { continue }
            if let cached = previous[project.name], cached.path == path, cached.modified == modificationDate(path) {
                icons[project.name] = cached
            } else if let icon = render(path) {
                icons[project.name] = icon
            }
        }
        return icons
    }

    static func render(_ path: String) -> ProjectIcon? {
        guard let image = NSImage(contentsOf: URL(filePath: path)), image.size.width > 0, image.size.height > 0,
              let bitmap = NSBitmapImageRep(
                  bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
                  hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
              ),
              let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else { return nil }

        // Encaja sin deformar (los SVG pueden no ser cuadrados).
        let side = CGFloat(pixels)
        let scale = min(side / image.size.width, side / image.size.height)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let rect = NSRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        image.draw(in: rect, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = bitmap.cgImage else { return nil }
        let opaque = [(1, 1), (pixels - 2, 1), (1, pixels - 2), (pixels - 2, pixels - 2)].allSatisfy { x, y in
            (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.9
        }
        return ProjectIcon(image: cgImage, isOpaque: opaque, path: path, modified: modificationDate(path))
    }

    private static func fileSize(_ path: String) -> Int? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
    }

    private static func subdirectories(_ path: String) -> [String] {
        let url = URL(filePath: path, directoryHint: .isDirectory)
        let items = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )) ?? []
        return items.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }.map(\.lastPathComponent)
    }

    private static func modificationDate(_ path: String) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
    }
}
