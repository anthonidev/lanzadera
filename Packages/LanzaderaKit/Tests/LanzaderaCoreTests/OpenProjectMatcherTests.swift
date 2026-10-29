import Testing
@testable import LanzaderaCore

struct OpenProjectMatcherTests {
    let project = Project(name: "Nexus", windows: [ProjectWindow(tabs: [
        ProjectTab(title: "BACKEND", panes: [Pane(directory: "/b")]),
        ProjectTab(title: "FRONTEND", panes: [Pane(directory: "/f")], isFocused: true),
    ])])

    func window(_ id: String, _ names: [String]) -> GhosttyWindow {
        GhosttyWindow(id: id, tabs: names.enumerated().map { GhosttyTab(id: "\(id)-tab\($0)", name: $1) })
    }

    @Test func `id registrado vivo coincide aunque cambien los nombres`() throws {
        let windows = [window("otra", ["zsh"]), window("w1", ["renombrada", "FRONTEND"])]
        let match = try #require(OpenProjectMatcher.match(project, in: windows, registered: ["w1"]))
        #expect(match.windowIDs == ["w1"])
        #expect(match.mainTabID == "w1-tab1")
        #expect(!match.foundByFingerprint)
    }

    @Test func `id muerto y huella igual se adopta por huella`() throws {
        let windows = [window("nueva", ["BACKEND", "FRONTEND"])]
        let match = try #require(OpenProjectMatcher.match(project, in: windows, registered: ["muerta"]))
        #expect(match.windowIDs == ["nueva"])
        #expect(match.foundByFingerprint)
    }

    @Test func `sin registro ni huella no está abierto`() {
        #expect(OpenProjectMatcher.match(project, in: [window("x", ["zsh"])], registered: []) == nil)
    }

    @Test func `huellas con los mismos nombres en otro orden no coinciden`() {
        #expect(OpenProjectMatcher.match(project, in: [window("x", ["FRONTEND", "BACKEND"])], registered: []) == nil)
    }

    @Test func `reconoce la ventana aunque tenga pestañas agregadas a mano`() throws {
        let windows = [window("w", ["BACKEND", "zsh", "FRONTEND", "logs"])]
        let match = try #require(OpenProjectMatcher.match(project, in: windows, registered: []))
        #expect(match.windowIDs == ["w"])
        #expect(match.mainTabID == "w-tab2")
    }

    @Test func `prefiere la ventana idéntica a una con pestañas de más`() throws {
        let windows = [window("con-extra", ["BACKEND", "zsh", "FRONTEND"]), window("exacta", ["BACKEND", "FRONTEND"])]
        let match = try #require(OpenProjectMatcher.match(project, in: windows, registered: []))
        #expect(match.windowIDs == ["exacta"])
    }

    @Test func `si falta una pestaña del proyecto no coincide`() {
        #expect(OpenProjectMatcher.match(project, in: [window("x", ["BACKEND", "zsh"])], registered: []) == nil)
    }

    @Test func `no adopta ventanas registradas a otro proyecto`() {
        let windows = [window("ajena", ["BACKEND", "FRONTEND"])]
        #expect(OpenProjectMatcher.match(project, in: windows, registered: [], claimed: ["ajena"]) == nil)
    }

    @Test func `con varias ventanas la principal es la de la pestaña principal`() throws {
        let twoWindows = Project(name: "X", windows: [
            ProjectWindow(tabs: [ProjectTab(title: "A", panes: [Pane(directory: "/a")])]),
            ProjectWindow(tabs: [ProjectTab(title: "B", panes: [Pane(directory: "/b")], isFocused: true)]),
        ])
        let windows = [window("wa", ["A"]), window("wb", ["B"])]
        let match = try #require(OpenProjectMatcher.match(twoWindows, in: windows, registered: ["wa", "wb"]))
        #expect(match.mainWindowID == "wb")
        #expect(match.windowIDs == ["wa", "wb"])
    }
}
