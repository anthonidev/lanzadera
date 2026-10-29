import Testing
@testable import LanzaderaCore

struct ProjectResolverTests {
    let resolver = ProjectResolver(homeDirectory: "/Users/yo")

    func tab(_ title: String?, cwd: String? = nil, panes: PanesSpec = .count(1), focus: Bool = false) -> TabSpec {
        TabSpec(title: title, cwd: cwd, panes: panes, focus: focus)
    }

    @Test func `expande ~ y resuelve rutas relativas a root`() throws {
        let spec = ProjectSpec(name: "Nexus", root: "~/nexus", windows: [WindowSpec(tabs: [
            tab("BACKEND", cwd: "nexus-backend", panes: .count(3)),
            tab("GLOBAL"),
            tab("OTRA", cwd: "/tmp/otra/"),
        ])])
        let project = try #require(resolver.resolve(spec, position: 1).project)
        let tabs = project.windows[0].tabs
        #expect(tabs[0].panes == Array(repeating: Pane(directory: "/Users/yo/nexus/nexus-backend"), count: 3))
        #expect(tabs[1].panes == [Pane(directory: "/Users/yo/nexus")])
        #expect(tabs[2].panes == [Pane(directory: "/tmp/otra")])
    }

    @Test func `panes en lista usa una carpeta por panel relativa a root`() throws {
        let spec = ProjectSpec(name: "Clinicsay", root: "~/clinicsay", windows: [WindowSpec(tabs: [
            tab("FRONTEND", cwd: "clinicsay-frontend", panes: .list([
                PaneSpec(cwd: "clinicsay-frontend"), PaneSpec(cwd: "migration-app"), PaneSpec(),
            ])),
        ])])
        let project = try #require(resolver.resolve(spec, position: 1).project)
        #expect(project.windows[0].tabs[0].panes.map(\.directory) == [
            "/Users/yo/clinicsay/clinicsay-frontend", "/Users/yo/clinicsay/migration-app", "/Users/yo/clinicsay/clinicsay-frontend",
        ])
    }

    @Test func `dos pestañas principales en la misma ventana es un error del proyecto`() {
        let spec = ProjectSpec(name: "X", root: "~/x", windows: [WindowSpec(tabs: [tab("A", focus: true), tab("B", focus: true)], line: 4)])
        let entry = resolver.resolve(spec, position: 1)
        #expect(entry.project == nil)
        #expect(entry.issues.contains { $0.message.contains("más de una pestaña") && $0.line == 4 })
    }

    @Test func `un proyecto con error no afecta a los demás`() {
        let entries = resolver.resolve([
            ProjectSpec(name: "Bueno", root: "~/a", windows: [WindowSpec(tabs: [tab("A")])]),
            ProjectSpec(name: "Malo", windows: [WindowSpec(tabs: [tab(nil, cwd: "relativa")])]),
        ])
        #expect(entries[0].project != nil)
        #expect(entries[1].project == nil)
        #expect(entries[1].issues.count == 2) // sin título y carpeta relativa sin root
    }

    @Test func `nombres repetidos sin importar mayúsculas`() {
        let make = { (name: String) in ProjectSpec(name: name, root: "~/a", windows: [WindowSpec(tabs: [self.tab("A")])]) }
        let entries = resolver.resolve([make("Nexus"), make("nexus")])
        #expect(entries[0].project != nil)
        #expect(entries[1].issues.first?.message.contains("Ya hay otro proyecto") == true)
    }

    @Test func `sin cwd ni root falta la carpeta`() {
        let entry = resolver.resolve(ProjectSpec(name: "X", windows: [WindowSpec(tabs: [tab("A")])]), position: 1)
        #expect(entry.issues.contains { $0.message.contains("Falta la carpeta") })
    }

    @Test func `color, split y panes fuera de rango se validan`() {
        let spec = ProjectSpec(name: "X", color: "violeta", root: "~/x", windows: [WindowSpec(tabs: [
            TabSpec(title: "A", panes: .count(0), split: "diagonal"),
        ])])
        let messages = resolver.resolve(spec, position: 1).issues.map(\.message)
        #expect(messages.contains { $0.contains("Color desconocido") })
        #expect(messages.contains { $0.contains("`split`") })
        #expect(messages.contains { $0.contains("`panes`") })
    }

    @Test func `color y emoji como marca`() throws {
        let tabs = [WindowSpec(tabs: [tab("A")])]
        let colored = try #require(resolver.resolve(ProjectSpec(name: "A", color: "Red", root: "~", windows: tabs), position: 1).project)
        #expect(colored.marker == .color(.red))
        let emojiSpec = ProjectSpec(name: "B", emoji: "🔴", color: "red", root: "~", windows: tabs)
        let emoji = try #require(resolver.resolve(emojiSpec, position: 1).project)
        #expect(emoji.marker == .emoji("🔴"))
    }

    @Test func `sin nombre usa la posición para mostrarlo`() {
        let entry = resolver.resolve(ProjectSpec(root: "~", windows: [WindowSpec(tabs: [tab("A")])]), position: 3)
        #expect(entry.name == "Proyecto 3")
        #expect(entry.project == nil)
    }
}
