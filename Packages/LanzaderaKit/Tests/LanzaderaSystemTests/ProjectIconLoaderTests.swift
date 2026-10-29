import AppKit
import LanzaderaCore
import Testing
@testable import LanzaderaSystem

@MainActor
struct ProjectIconLoaderTests {
    let folder = URL.temporaryDirectory.appending(path: "lanzadera-icons-\(UUID().uuidString)", directoryHint: .isDirectory)

    /// Escribe un PNG de 64 px: con fondo lleno o solo un círculo sobre transparente.
    func writePNG(_ name: String, opaque: Bool) throws -> URL {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.systemBlue.setFill()
        if opaque {
            NSRect(x: 0, y: 0, width: 64, height: 64).fill()
        } else {
            NSBezierPath(ovalIn: NSRect(x: 16, y: 16, width: 32, height: 32)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let url = folder.appending(path: name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    func project(icon: URL) -> Project {
        Project(name: "P", icon: .file(icon.path(percentEncoded: false)), windows: [ProjectWindow(tabs: [
            ProjectTab(title: "A", panes: [Pane(directory: folder.path(percentEncoded: false))]),
        ])])
    }

    @Test func `reconoce si el ícono tiene fondo propio`() throws {
        let opaque = try #require(ProjectIconLoader.render(try writePNG("lleno.png", opaque: true).path(percentEncoded: false)))
        #expect(opaque.isOpaque)
        #expect(opaque.image.width == ProjectIconLoader.pixels)
        let transparent = try #require(ProjectIconLoader.render(try writePNG("circulo.png", opaque: false).path(percentEncoded: false)))
        #expect(!transparent.isOpaque)
    }

    @Test func `reutiliza el ícono si el archivo no cambió y lo recarga si cambió`() async throws {
        let url = try writePNG("public/apple-touch-icon.png", opaque: true)
        let project = project(icon: url)
        let first = await ProjectIconLoader.load(for: [project], reusing: [:])
        let icon = try #require(first["P"])
        let second = await ProjectIconLoader.load(for: [project], reusing: first)
        #expect(second["P"]?.image === icon.image)

        let later: [FileAttributeKey: Any] = [.modificationDate: Date.now.addingTimeInterval(60)]
        try FileManager.default.setAttributes(later, ofItemAtPath: url.path(percentEncoded: false))
        let third = await ProjectIconLoader.load(for: [project], reusing: second)
        #expect(third["P"]?.image !== icon.image)
    }

    @Test func `un archivo que no es imagen no rompe nada`() throws {
        let url = folder.appending(path: "favicon.ico")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "no soy una imagen".write(to: url, atomically: true, encoding: .utf8)
        #expect(ProjectIconLoader.render(url.path(percentEncoded: false)) == nil)
    }
}
