import Foundation
import LanzaderaCore
import Testing
@testable import LanzaderaConfig

/// Las 4 configuraciones reales de Warp, copiadas como fixtures.
struct WarpConfigReaderTests {
    var directory: URL {
        get throws {
            try #require(Bundle.module.url(forResource: "Fixtures/warp", withExtension: nil))
        }
    }

    @Test func `lee las cuatro configuraciones`() throws {
        let (configs, errors) = WarpConfigReader.read(directory: try directory)
        #expect(errors.isEmpty)
        #expect(configs.map(\.name) == ["Chaskybet", "Clinicsay", "Nexus", "Smart"])
        let nexus = configs[2]
        #expect(nexus.activeWindowIndex == 1)
        #expect(nexus.windows.count == 2)
        #expect(nexus.windows[1].activeTabIndex == 2)
        #expect(nexus.windows[1].tabs.map(\.title) == ["BACKEND", "FRONTEND", "GLOBAL"])
        guard case .split(let direction, let panes) = nexus.windows[1].tabs[0].layout else {
            Issue.record("BACKEND debería ser una división")
            return
        }
        #expect(direction == "horizontal")
        #expect(panes.count == 3)
    }

    @Test func `importación completa con los avisos esperados`() throws {
        let (configs, _) = WarpConfigReader.read(directory: try directory)
        let importer = WarpImporter(homeDirectory: "/Users/tonis") { $0 != "/Users/tonis/Desktop/data/fotos" }
        let candidates = Dictionary(uniqueKeysWithValues: importer.candidates(from: configs).map { ($0.name, $0) })

        let nexus = try #require(candidates["Nexus"])
        #expect(nexus.windows[0].suggestedExclusion)
        #expect(nexus.windows[0].warnings.contains("La carpeta ~/Desktop/data/fotos no existe"))
        #expect(!nexus.windows[1].suggestedExclusion)

        let smart = try #require(candidates["Smart"])
        #expect(smart.windows[1].warnings == ["Repite la ventana del proyecto «Nexus»"])

        let chaskybet = try #require(candidates["Chaskybet"])
        #expect(chaskybet.windows[1].warnings == ["Repite la ventana del proyecto «Smart»"])

        let clinicsay = try #require(candidates["Clinicsay"])
        #expect(clinicsay.windows.allSatisfy { $0.warnings.isEmpty })

        // Lo que se escribiría con las ventanas propuestas se lee sin errores.
        let specs = importer.candidates(from: configs).map { candidate in
            importer.spec(for: candidate, including: Set(candidate.windows.indices.filter { !candidate.windows[$0].suggestedExclusion }))
        }
        let text = ConfigWriter.appending(specs, to: ConfigWriter.template)
        let entries = try ConfigLoader.load(text, resolver: ProjectResolver(homeDirectory: "/Users/tonis"))
        #expect(entries.allSatisfy { $0.project != nil })
        #expect(entries.map { $0.project?.windows.count } == [1, 1, 1, 1])
        let nexusProject = try #require(entries.first { $0.name == "Nexus" }?.project)
        #expect(ProjectSummary.text(for: nexusProject) == "3 pestañas · 6 paneles")
        #expect(nexusProject.windows[0].focusedTabIndex == 2)
    }
}
