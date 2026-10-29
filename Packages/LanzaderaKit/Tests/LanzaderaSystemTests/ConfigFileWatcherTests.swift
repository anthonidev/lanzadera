import Foundation
import Testing
@testable import LanzaderaSystem

/// Con archivos reales en una carpeta temporal: así guardan Zed y otros editores.
@MainActor
struct ConfigFileWatcherTests {
    let folder = URL.temporaryDirectory.appending(path: "lanzadera-watch-\(UUID().uuidString)", directoryHint: .isDirectory)

    func makeFile(in folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "proyectos.yaml")
        try "projects:\n".write(to: file, atomically: false, encoding: .utf8)
        return file
    }

    /// Espera (hasta 2 s) a que el contador pase de `count`.
    func waitForChange(_ changes: () -> Int, beyond count: Int) async -> Bool {
        for _ in 0..<40 {
            if changes() > count { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    @Test func `avisa al guardar reemplazando el archivo y al escribir encima`() async throws {
        let file = try makeFile(in: folder)
        var changes = 0
        let watcher = ConfigFileWatcher(file: file) { changes += 1 }
        watcher.start()
        defer { watcher.stop() }

        // Guardado atómico (como Zed): escribe en otro archivo y lo renombra encima.
        try "projects: []\n".write(to: file, atomically: true, encoding: .utf8)
        #expect(await waitForChange({ changes }, beyond: 0))

        // Escritura en el lugar, y una segunda para comprobar que se volvió a vigilar el archivo nuevo.
        let seen = changes
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("# más\n".utf8))
        try handle.close()
        #expect(await waitForChange({ changes }, beyond: seen))
    }

    @Test func `sigue el destino de un enlace simbólico`() async throws {
        let target = try makeFile(in: folder.appending(path: "repo", directoryHint: .isDirectory))
        let linkFolder = folder.appending(path: "config", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: linkFolder, withIntermediateDirectories: true)
        let link = linkFolder.appending(path: "proyectos.yaml")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        var changes = 0
        let watcher = ConfigFileWatcher(file: link) { changes += 1 }
        watcher.start()
        defer { watcher.stop() }
        try "projects: []\n".write(to: target, atomically: true, encoding: .utf8)
        #expect(await waitForChange({ changes }, beyond: 0))
    }

    @Test func `varios cambios seguidos se agrupan en un aviso`() async throws {
        let file = try makeFile(in: folder)
        var changes = 0
        let watcher = ConfigFileWatcher(file: file) { changes += 1 }
        watcher.start()
        defer { watcher.stop() }
        for index in 0..<5 {
            try "projects: # \(index)\n".write(to: file, atomically: true, encoding: .utf8)
        }
        #expect(await waitForChange({ changes }, beyond: 0))
        try await Task.sleep(for: .milliseconds(400))
        #expect(changes == 1)
    }
}
