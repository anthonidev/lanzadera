import Testing
@testable import LanzaderaCore

struct GhosttyScriptTests {
    let nexus = Project(name: "Nexus", windows: [ProjectWindow(tabs: [
        ProjectTab(title: "🔴 BACKEND", panes: Array(repeating: Pane(directory: "/Users/yo/nexus/nexus-backend"), count: 3),
                   isFocused: true),
        ProjectTab(title: "🔴 FRONTEND", panes: Array(repeating: Pane(directory: "/Users/yo/nexus/nexus-frontend"), count: 2)),
        ProjectTab(title: "🔴 GLOBAL", panes: [Pane(directory: "/Users/yo/nexus")]),
    ])])

    @Test func `script de Nexus`() {
        let expected = """
            tell application "Ghostty"
                set cfg1 to new surface configuration
                set initial working directory of cfg1 to "/Users/yo/nexus/nexus-backend"
                set cfg2 to new surface configuration
                set initial working directory of cfg2 to "/Users/yo/nexus/nexus-frontend"
                set cfg3 to new surface configuration
                set initial working directory of cfg3 to "/Users/yo/nexus"
                -- Ventana 1
                set w1 to new window with configuration cfg1
                activate
                set t1_1 to selected tab of w1
                set name override of t1_1 to "🔴 BACKEND"
                set t1_1_p1 to focused terminal of t1_1
                set t1_1_p2 to split t1_1_p1 direction right with configuration cfg1
                set t1_1_p3 to split t1_1_p2 direction right with configuration cfg1
                perform action "equalize_splits" on t1_1_p1
                set t1_2 to new tab in w1 with configuration cfg2
                set name override of t1_2 to "🔴 FRONTEND"
                set t1_2_p1 to focused terminal of t1_2
                set t1_2_p2 to split t1_2_p1 direction right with configuration cfg2
                set t1_3 to new tab in w1 with configuration cfg3
                set name override of t1_3 to "🔴 GLOBAL"
                set t1_3_p1 to focused terminal of t1_3
                select tab t1_1
                focus t1_1_p1
                activate
                return {id of w1}
            end tell
            """
        #expect(GhosttyScript.open(nexus) == expected)
    }

    @Test func `varias ventanas, paneles hacia abajo y carpeta por panel`() {
        let project = Project(name: "X", windows: [
            ProjectWindow(tabs: [ProjectTab(title: "A", panes: [Pane(directory: "/a")])]),
            ProjectWindow(tabs: [
                ProjectTab(title: "B", panes: [Pane(directory: "/b")]),
                ProjectTab(title: "C", split: .down, panes: [Pane(directory: "/a"), Pane(directory: "/c")], isFocused: true),
            ]),
        ])
        let script = GhosttyScript.open(project)
        #expect(script.contains("set w2 to new window with configuration cfg2"))
        #expect(script.contains("set t2_2_p2 to split t2_2_p1 direction down with configuration cfg3"))
        #expect(script.contains("select tab t1_1"))
        #expect(script.contains("select tab t2_2"))
        // La ventana con la pestaña principal se enfoca al final.
        #expect(script.contains("focus t2_2_p1"))
        #expect(script.contains("return {id of w1, id of w2}"))
        #expect(!script.contains("equalize_splits"))
    }

    @Test func `escapa comillas, barras invertidas y saltos de línea, y respeta emojis`() {
        #expect(GhosttyScript.quote(#"di "hola" \ chau"#) == #""di \"hola\" \\ chau""#)
        #expect(GhosttyScript.quote("a\nb") == #""a\nb""#)
        #expect(GhosttyScript.quote("🟣 APP") == "\"🟣 APP\"")
    }

    @Test func `rutas con comillas quedan escapadas en el script`() {
        let project = Project(name: "Q", windows: [ProjectWindow(tabs: [
            ProjectTab(title: #"Tab "1""#, panes: [Pane(directory: #"/tmp/con "comillas""#)]),
        ])])
        let script = GhosttyScript.open(project)
        #expect(script.contains(#"set initial working directory of cfg1 to "/tmp/con \"comillas\"""#))
        #expect(script.contains(#"set name override of t1_1 to "Tab \"1\"""#))
    }

    @Test func `activar selecciona la pestaña principal y deja la ventana principal al final`() {
        let script = GhosttyScript.activate(windowIDs: ["w-a", "w-b"], mainWindowID: "w-b", mainTabID: "tab-1")
        #expect(script == """
            tell application "Ghostty"
                activate window (window id "w-a")
                set w to window id "w-b"
                select tab (tab id "tab-1" of w)
                activate window w
                activate
            end tell
            """)
    }

    @Test func `lee la foto en bloque con varias ventanas`() {
        let value = ScriptValue.list([
            .list([.text("win-1"), .text("win-2")]),
            .list([.list([.text("tab-1"), .text("tab-2")]), .list([.text("tab-3")])]),
            .list([.list([.text("🔴 BACKEND"), .text("🔴 GLOBAL")]), .list([.text("zsh")])]),
        ])
        #expect(GhosttySnapshot.parse(value) == [
            GhosttyWindow(id: "win-1", tabs: [GhosttyTab(id: "tab-1", name: "🔴 BACKEND"), GhosttyTab(id: "tab-2", name: "🔴 GLOBAL")]),
            GhosttyWindow(id: "win-2", tabs: [GhosttyTab(id: "tab-3", name: "zsh")]),
        ])
    }

    @Test func `con una sola ventana acepta las listas aplanadas`() {
        let flat = ScriptValue.list([
            .list([.text("win-1")]),
            .list([.text("tab-1"), .text("tab-2")]),
            .list([.text("A"), .text("B")]),
        ])
        #expect(GhosttySnapshot.parse(flat) == [
            GhosttyWindow(id: "win-1", tabs: [GhosttyTab(id: "tab-1", name: "A"), GhosttyTab(id: "tab-2", name: "B")]),
        ])
    }

    @Test func `sin ventanas o con forma inesperada devuelve vacío`() {
        #expect(GhosttySnapshot.parse(.list([])).isEmpty)
        #expect(GhosttySnapshot.parse(.text("basura")).isEmpty)
    }
}
