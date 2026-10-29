import Foundation
import LanzaderaConfig
import LanzaderaCore
import Testing
@testable import LanzaderaUI

@MainActor
struct ImportModelTests {
    /// Carpeta temporal con una configuración de Warp y un `proyectos.yaml` que ya tiene «Nexus».
    func makeModel() throws -> (ImportModel, URL) {
        let folder = URL.temporaryDirectory.appending(path: "lanzadera-import-\(UUID().uuidString)", directoryHint: .isDirectory)
        let warp = folder.appending(path: "warp", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: warp, withIntermediateDirectories: true)
        let warpConfig = { (name: String) in
            """
            name: \(name)
            windows:
              - tabs:
                  - title: NUEVA
                    color: red
                    layout:
                      cwd: /tmp/\(name.lowercased())/app
            """
        }
        try warpConfig("Nexus").write(to: warp.appending(path: "nexus.yaml"), atomically: true, encoding: .utf8)
        try warpConfig("Smart").write(to: warp.appending(path: "smart.yaml"), atomically: true, encoding: .utf8)
        let file = folder.appending(path: "proyectos.yaml")
        try "# mío\nprojects:\n  - name: Nexus\n    root: ~/viejo\n    tabs:\n      - title: VIEJA\n"
            .write(to: file, atomically: true, encoding: .utf8)
        let model = ImportModel(file: file, warpDirectory: warp, homeDirectory: "/Users/yo")
        model.load(existing: ["Nexus"])
        return (model, file)
    }

    @Test func `el que ya existe viene sin marcar y el nuevo marcado`() throws {
        let (model, _) = try makeModel()
        #expect(model.selectedProjects == ["Smart"])
        #expect(model.replacementCount == 0)
    }

    @Test func `marcar uno existente lo reemplaza, agrega el nuevo y guarda la copia`() throws {
        let (model, file) = try makeModel()
        model.selectedProjects.insert("Nexus")
        #expect(model.replacementCount == 1)
        var imported = 0
        model.onFinish = { imported = $0 }
        model.importSelected()
        #expect(imported == 2)
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.hasPrefix("# mío"))
        #expect(!text.contains("VIEJA"))
        let entries = try ConfigLoader.load(text, resolver: ProjectResolver(homeDirectory: "/Users/yo"))
        #expect(entries.map(\.name) == ["Nexus", "Smart"])
        #expect(entries[0].project?.windows[0].tabs[0].title == "🔴 NUEVA")
        let backup = try String(contentsOf: file.appendingPathExtension("bak"), encoding: .utf8)
        #expect(backup.contains("VIEJA"))
    }
}
