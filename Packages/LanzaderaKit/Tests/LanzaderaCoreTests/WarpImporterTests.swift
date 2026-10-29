import Testing
@testable import LanzaderaCore

struct WarpImporterTests {
    let home = "/Users/yo"

    func importer(missing: Set<String> = []) -> WarpImporter {
        WarpImporter(homeDirectory: home) { !missing.contains($0) }
    }

    func split(_ cwd: String, _ count: Int, direction: String = "horizontal") -> WarpLayout {
        .split(direction: direction, panes: Array(repeating: .pane(cwd: cwd, isFocused: false, commands: []), count: count))
    }

    var nexusWindow: WarpWindow {
        WarpWindow(activeTabIndex: 2, tabs: [
            WarpTab(title: "BACKEND", color: "red", layout: split("/Users/yo/nexus/nexus-backend", 3)),
            WarpTab(title: "FRONTEND", color: "red", layout: split("/Users/yo/nexus/nexus-frontend", 2)),
            WarpTab(title: "GLOBAL", color: "red", layout: .pane(cwd: "/Users/yo/nexus", isFocused: true, commands: [])),
        ])
    }

    @Test func `convierte colores, títulos, divisiones y carpeta común`() throws {
        let config = WarpLaunchConfig(name: "Nexus", windows: [nexusWindow])
        let candidate = try #require(importer().candidates(from: [config]).first)
        #expect(candidate.emoji == "🔴")
        let spec = importer().spec(for: candidate, including: [0])
        #expect(spec.root == "~/nexus")
        let tabs = spec.windows[0].tabs
        #expect(tabs.map(\.title) == ["🔴 BACKEND", "🔴 FRONTEND", "🔴 GLOBAL"])
        #expect(tabs.map(\.cwd) == ["nexus-backend", "nexus-frontend", nil])
        #expect(tabs.map(\.panes) == [.count(3), .count(2), .count(1)])
        #expect(tabs.map(\.focus) == [false, false, true])
        #expect(tabs.allSatisfy { $0.split == nil })
    }

    @Test func `ventana con carpeta inexistente y fuera del proyecto se propone descartar`() throws {
        let fotos = WarpWindow(tabs: [WarpTab(layout: split("/Users/yo/Desktop/data/fotos", 2))])
        let config = WarpLaunchConfig(name: "Nexus", activeWindowIndex: 1, windows: [fotos, nexusWindow])
        let candidate = try #require(importer(missing: ["/Users/yo/Desktop/data/fotos"]).candidates(from: [config]).first)
        #expect(candidate.mainWindowIndex == 1)
        #expect(candidate.windows[0].suggestedExclusion)
        #expect(candidate.windows[0].warnings.contains("La carpeta ~/Desktop/data/fotos no existe"))
        #expect(candidate.windows[0].warnings.contains { $0.contains("fuera de la carpeta del proyecto (~/nexus)") })
        // Sin título: usa el nombre de la carpeta.
        #expect(candidate.windows[0].tabs[0].title == "fotos")
        #expect(!candidate.windows[1].suggestedExclusion)
    }

    @Test func `ventana que repite la de otro proyecto aunque tenga menos paneles`() throws {
        let smartMain = WarpWindow(tabs: [
            WarpTab(title: "API", color: "red", layout: split("/Users/yo/dev/smart/api", 3)),
            WarpTab(title: "APP", color: "green", layout: split("/Users/yo/dev/smart/app", 3)),
        ])
        var copy = smartMain
        copy.tabs[1].layout = split("/Users/yo/dev/smart/app", 2)
        let chasky = WarpWindow(tabs: [WarpTab(title: "APP Chasky", color: "magenta", layout: split("/Users/yo/dev/chaskyapp", 2))])
        let candidates = importer().candidates(from: [
            WarpLaunchConfig(name: "Chaskybet", windows: [chasky, copy]),
            WarpLaunchConfig(name: "Smart", windows: [smartMain]),
        ])
        let chaskybet = try #require(candidates.first)
        #expect(chaskybet.windows[1].warnings == ["Repite la ventana del proyecto «Smart»"])
        #expect(chaskybet.windows[1].suggestedExclusion)
        let spec = importer().spec(for: chaskybet, including: [0])
        #expect(spec.root == "~/dev/chaskyapp")
        #expect(spec.windows[0].tabs[0].cwd == nil)
        #expect(spec.emoji == "🟣")
    }

    @Test func `carpetas distintas en una pestaña quedan como lista y anidadas se aplanan con aviso`() throws {
        let layout = WarpLayout.split(direction: "vertical", panes: [
            .pane(cwd: "/Users/yo/p/a", isFocused: false, commands: []),
            .split(direction: "horizontal", panes: [
                .pane(cwd: "/Users/yo/p/b", isFocused: false, commands: ["npm run dev"]),
                .pane(cwd: "/Users/yo/p/b", isFocused: false, commands: []),
            ]),
        ])
        let config = WarpLaunchConfig(name: "P", windows: [WarpWindow(tabs: [WarpTab(title: "T", layout: layout)])])
        let candidate = try #require(importer().candidates(from: [config]).first)
        #expect(candidate.windows[0].warnings.contains { $0.contains("anidadas") })
        #expect(candidate.windows[0].warnings.contains { $0.contains("comandos") })
        let tab = importer().spec(for: candidate, including: [0]).windows[0].tabs[0]
        #expect(tab.split == "down")
        #expect(tab.panes == .list([PaneSpec(cwd: "a"), PaneSpec(cwd: "b"), PaneSpec(cwd: "b")]))
    }

    @Test func `carpeta común no puede ser la carpeta personal`() {
        let importer = importer()
        #expect(importer.commonDirectory(of: ["/Users/yo/a", "/Users/yo/b"]) == nil)
        #expect(importer.commonDirectory(of: ["/Users/yo/dev/a", "/Users/yo/dev/b"]) == "/Users/yo/dev")
        #expect(importer.commonDirectory(of: ["/opt/x"]) == "/opt/x")
    }
}
