import Testing
@testable import LanzaderaCore

struct ProjectSummaryTests {
    @Test func `cuenta pestañas y paneles`() {
        let project = Project(name: "Nexus", windows: [ProjectWindow(tabs: [
            ProjectTab(title: "A", panes: Array(repeating: Pane(directory: "/a"), count: 3)),
            ProjectTab(title: "B", panes: Array(repeating: Pane(directory: "/b"), count: 2)),
            ProjectTab(title: "C", panes: [Pane(directory: "/c")]),
        ])])
        #expect(ProjectSummary.text(for: project) == "3 pestañas · 6 paneles")
    }

    @Test func `singular y ventanas cuando hay más de una`() {
        let one = ProjectWindow(tabs: [ProjectTab(title: "A", panes: [Pane(directory: "/a")])])
        #expect(ProjectSummary.text(for: Project(name: "X", windows: [one])) == "1 pestaña · 1 panel")
        #expect(ProjectSummary.text(for: Project(name: "X", windows: [one, one])) == "2 ventanas · 2 pestañas · 2 paneles")
    }
}

struct ProjectFilterTests {
    let names = ["Chaskybet", "Clinicsay", "Nexus", "Smart"]

    func filter(_ query: String) -> [String] {
        ProjectFilter.filter(names, query: query) { $0 }
    }

    @Test func `filtra sin mayúsculas ni tildes`() {
        #expect(filter("nex") == ["Nexus"])
        #expect(filter("CLINI") == ["Clinicsay"])
        #expect(filter("clínic") == ["Clinicsay"])
    }

    @Test func `vacío devuelve todo en orden`() {
        #expect(filter("  ") == names)
    }

    @Test func `los que empiezan con lo escrito van primero`() {
        #expect(filter("s") == ["Smart", "Chaskybet", "Clinicsay", "Nexus"])
    }
}
