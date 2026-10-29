import LanzaderaCore
import Testing
@testable import LanzaderaConfig

struct ConfigLoaderTests {
    let resolver = ProjectResolver(homeDirectory: "/Users/yo")

    let example = """
        # Comentario
        projects:
          - name: Nexus
            emoji: 🔴
            root: ~/nexus
            tabs:
              - title: 🔴 BACKEND
                cwd: nexus-backend
                panes: 3
                split: right
                focus: true
              - title: 🔴 FRONTEND
                cwd: nexus-frontend
                panes: 2
              - title: 🔴 GLOBAL

          - name: Clinicsay
            color: magenta
            root: ~/clinicsay
            windows:
              - tabs:
                  - title: 🟣 MIGRATION APP
                    cwd: migration-app
              - tabs:
                  - title: 🔵 FRONTEND
                    cwd: clinicsay-frontend
                    split: down
                    panes:
                      - cwd: clinicsay-frontend
                      - migration-app
        """

    @Test func `lee el archivo completo con sus dos formas`() throws {
        let entries = try ConfigLoader.load(example, resolver: resolver)
        #expect(entries.count == 2)
        let nexus = try #require(entries[0].project)
        #expect(nexus.marker == .emoji("🔴"))
        #expect(nexus.windows.count == 1)
        #expect(nexus.windows[0].tabs.map(\.panes.count) == [3, 2, 1])
        #expect(nexus.windows[0].tabs[2].panes[0].directory == "/Users/yo/nexus")
        #expect(nexus.windows[0].focusedTabIndex == 0)

        let clinicsay = try #require(entries[1].project)
        #expect(clinicsay.marker == .color(.magenta))
        #expect(clinicsay.windows.count == 2)
        let frontend = clinicsay.windows[1].tabs[0]
        #expect(frontend.split == .down)
        #expect(frontend.panes.map(\.directory) == ["/Users/yo/clinicsay/clinicsay-frontend", "/Users/yo/clinicsay/migration-app"])
    }

    @Test func `YAML roto informa la línea correcta`() {
        let broken = """
            projects:
              - name: Nexus
                tabs:
                  - title: "sin cerrar
                    cwd: x
            """
        #expect {
            try ConfigLoader.load(broken, resolver: resolver)
        } throws: { error in
            guard let error = error as? ConfigSyntaxError else { return false }
            return error.line != nil && error.description.hasPrefix("Error en la línea")
        }

        let badIndent = "projects:\n  - name: A\n   tabs: x\n"
        #expect(throws: ConfigSyntaxError.self) { try ConfigLoader.load(badIndent, resolver: resolver) }
    }

    @Test func `archivo vacío, solo comentarios o projects vacío no son errores`() throws {
        #expect(try ConfigLoader.load("", resolver: resolver).isEmpty)
        #expect(try ConfigLoader.load("# nada\n", resolver: resolver).isEmpty)
        #expect(try ConfigLoader.load("projects:\n", resolver: resolver).isEmpty)
        #expect(try ConfigLoader.load(ConfigWriter.template, resolver: resolver).isEmpty)
    }

    @Test func `projects que no es lista es un error del archivo`() {
        #expect(throws: ConfigSyntaxError.self) { try ConfigLoader.load("projects: hola", resolver: resolver) }
        #expect(throws: ConfigSyntaxError.self) { try ConfigLoader.load("- a\n- b\n", resolver: resolver) }
    }

    @Test func `clave desconocida y tipo incorrecto se marcan en su proyecto con la línea`() throws {
        let text = """
            projects:
              - name: Bueno
                root: ~/a
                tabs:
                  - title: A
              - name: Malo
                root: ~/b
                tabs:
                  - tittle: A
                    focus: quizás
            """
        let entries = try ConfigLoader.load(text, resolver: resolver)
        #expect(entries[0].project != nil)
        let issues = entries[1].issues
        #expect(issues.contains { $0.message.contains("«tittle»") && $0.line == 9 })
        #expect(issues.contains { $0.message.contains("`focus`") && $0.line == 10 })
        #expect(issues.contains { $0.message.contains("no tiene título") })
    }

    @Test func `windows y tabs a la vez es un error`() throws {
        let text = "projects:\n  - name: X\n    root: ~/x\n    tabs: []\n    windows: []\n"
        let entries = try ConfigLoader.load(text, resolver: resolver)
        #expect(entries[0].issues.contains { $0.message.contains("`windows` o `tabs`") })
    }
}

struct ConfigWriterTests {
    let resolver = ProjectResolver(homeDirectory: "/Users/yo")

    @Test func `lo escrito se vuelve a leer igual`() throws {
        let specs = [
            ProjectSpec(name: "Nexus", emoji: "🔴", root: "~/nexus", windows: [WindowSpec(tabs: [
                TabSpec(title: "🔴 BACKEND", cwd: "nexus-backend", panes: .count(3)),
                TabSpec(title: "🔴 GLOBAL", focus: true),
            ])]),
            ProjectSpec(name: "yes", root: "/tmp/a b", windows: [
                WindowSpec(tabs: [TabSpec(title: "- raro: #1", panes: .list([PaneSpec(cwd: "x"), PaneSpec(cwd: "y")]), split: "down")]),
                WindowSpec(tabs: [TabSpec(title: "123")]),
            ]),
        ]
        let text = ConfigWriter.appending(specs, to: ConfigWriter.template)
        #expect(text.hasPrefix("# Lanzadera"))
        let entries = try ConfigLoader.load(text, resolver: resolver)
        #expect(entries == resolver.resolve(specs))
        #expect(entries.allSatisfy { $0.project != nil })
    }

    @Test func `agrega al final conservando lo que ya estaba`() throws {
        let existing = "projects:\n  - name: A # mi comentario\n    root: ~/a\n    tabs:\n      - title: A\n"
        let project = ProjectSpec(name: "B", root: "~/b", windows: [WindowSpec(tabs: [TabSpec(title: "B")])])
        let text = ConfigWriter.appending([project], to: existing)
        #expect(text.contains("# mi comentario"))
        #expect(try ConfigLoader.load(text, resolver: resolver).map(\.name) == ["A", "B"])
    }

    @Test func `projects vacío en línea se convierte en lista`() throws {
        let project = ProjectSpec(name: "B", root: "~/b", windows: [WindowSpec(tabs: [TabSpec(title: "B")])])
        let text = ConfigWriter.appending([project], to: "projects: []\n")
        #expect(try ConfigLoader.load(text, resolver: resolver).map(\.name) == ["B"])
    }

    @Test func `comillas solo cuando hacen falta`() {
        #expect(ConfigWriter.scalar("🔴 BACKEND") == "🔴 BACKEND")
        #expect(ConfigWriter.scalar("~/nexus") == "~/nexus")
        #expect(ConfigWriter.scalar("yes") == "\"yes\"")
        #expect(ConfigWriter.scalar("42") == "\"42\"")
        #expect(ConfigWriter.scalar("a: b") == "\"a: b\"")
        #expect(ConfigWriter.scalar(#"di "x""#) == #"di "x""#)
        #expect(ConfigWriter.scalar(#""x""#) == #""\"x\"""#)
    }
}
