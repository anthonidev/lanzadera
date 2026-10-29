import Foundation

/// Dónde vive `proyectos.yaml`: fijo en `~/.config/lanzadera/` para poder guardarlo en un repo.
public enum ConfigLocation {
    public static let directory = URL.homeDirectory.appending(path: ".config/lanzadera", directoryHint: .isDirectory)
    public static let file = directory.appending(path: "proyectos.yaml")

    /// Crea el archivo con el ejemplo comentado si todavía no existe.
    @discardableResult
    public static func createIfMissing(at file: URL = file) throws -> Bool {
        let path = file.path(percentEncoded: false)
        // `fileExists` sigue el enlace simbólico: uno roto cuenta como inexistente, pero no se pisa.
        let isLink = (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil
        guard !FileManager.default.fileExists(atPath: path), !isLink else { return false }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ConfigWriter.template.write(to: file, atomically: true, encoding: .utf8)
        return true
    }

    /// Escribe el archivo guardando antes una copia `.bak`. Si es un enlace simbólico, escribe en el destino.
    public static func write(_ text: String, to file: URL = file) throws {
        let target = file.resolvingSymlinksInPath()
        let backup = target.appendingPathExtension("bak")
        let manager = FileManager.default
        if manager.fileExists(atPath: target.path(percentEncoded: false)) {
            try? manager.removeItem(at: backup)
            try manager.copyItem(at: target, to: backup)
        }
        try text.write(to: target, atomically: true, encoding: .utf8)
    }
}
