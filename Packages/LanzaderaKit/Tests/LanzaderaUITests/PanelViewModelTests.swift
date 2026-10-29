import Foundation
import LanzaderaCore
import Testing
@testable import LanzaderaUI

@MainActor
struct PanelViewModelTests {
    let yaml = """
        projects:
          - name: Nexus
            root: /n
            tabs:
              - title: A
          - name: Smart
            root: /s
            tabs:
              - title: A
          - name: Roto
            tabs:
              - title: A
        """

    func makeModel(missing: Set<String> = []) -> (PanelViewModel, FakeGhostty) {
        let store = ProjectStore(file: URL(filePath: "/no/existe.yaml"), homeDirectory: "/Users/yo")
        store.apply(yaml)
        let ghostty = FakeGhostty()
        let launcher = ProjectLauncher(ghostty: ghostty, registry: FakeRegistry(), folders: FakeFolders(missing: missing))
        return (PanelViewModel(store: store, launcher: launcher), ghostty)
    }

    @Test func `filtrar vuelve la selección al primero y no se sale de la lista`() {
        let (model, _) = makeModel()
        model.moveSelection(by: 5)
        #expect(model.selection == 2)
        model.query = "sma"
        #expect(model.selection == 0)
        #expect(model.items.map(\.name) == ["Smart"])
        model.moveSelection(by: 1)
        #expect(model.selection == 0)
        model.moveSelection(by: -1)
        #expect(model.selection == 0)
    }

    @Test func `Enter con lista vacía no hace nada`() {
        let (model, ghostty) = makeModel()
        model.query = "zzz"
        model.openSelected(forceNew: false)
        #expect(ghostty.opened.isEmpty)
    }

    @Test func `un proyecto con errores no se abre y avisa`() {
        let (model, ghostty) = makeModel()
        var closed = false
        model.onClose = { closed = true }
        model.query = "roto"
        model.openSelected(forceNew: false)
        #expect(ghostty.opened.isEmpty)
        #expect(!closed)
        #expect(model.notice?.contains("errores") == true)
    }

    @Test func `Enter abre el elegido y cierra el panel`() {
        let (model, ghostty) = makeModel()
        var closed = false
        model.onClose = { closed = true }
        model.moveSelection(by: 1)
        model.openSelected(forceNew: false)
        #expect(ghostty.opened == ["Smart"])
        #expect(closed)
        #expect(model.openNames.contains("Smart"))
    }

    @Test func `carpeta que falta se avisa en el panel sin cerrarlo`() {
        let (model, ghostty) = makeModel(missing: ["/n"])
        var closed = false
        model.onClose = { closed = true }
        model.prepareForPresentation()
        #expect(model.missingFolders["Nexus"] == ["/n"])
        model.openSelected(forceNew: false)
        #expect(ghostty.opened.isEmpty)
        #expect(!closed)
        #expect(model.notice == "No existe la carpeta /n")
    }

    @Test func `YAML roto conserva la última versión válida`() {
        let (model, _) = makeModel()
        model.store.apply("projects:\n  - name: [roto\n")
        #expect(model.store.fileError != nil)
        #expect(model.store.entries.count == 3)
        model.store.apply(yaml)
        #expect(model.store.fileError == nil)
    }
}

@MainActor
struct PanelInteractionTests {
    func makeModel() -> (PanelViewModel, FakeGhostty) {
        let store = ProjectStore(file: URL(filePath: "/no/existe.yaml"), homeDirectory: "/Users/yo")
        store.apply("""
            projects:
              - name: A
                root: /a
                tabs:
                  - title: A
              - name: B
                root: /b
                tabs:
                  - title: B
            """)
        let ghostty = FakeGhostty()
        let launcher = ProjectLauncher(ghostty: ghostty, registry: FakeRegistry(), folders: FakeFolders())
        return (PanelViewModel(store: store, launcher: launcher), ghostty)
    }

    @Test func `el hover no mueve la selección si el panel aparece bajo el cursor`() {
        let (model, _) = makeModel()
        model.prepareForPresentation(mouseLocation: CGPoint(x: 10, y: 10))
        model.hover(1, mouseLocation: CGPoint(x: 10, y: 10))
        #expect(model.selection == 0)
        model.hover(1, mouseLocation: CGPoint(x: 10, y: 30))
        #expect(model.selection == 1)
    }

    @Test func `⌘ y un número abre esa posición y fuera de rango no hace nada`() {
        let (model, ghostty) = makeModel()
        model.open(position: 2, forceNew: false)
        #expect(ghostty.opened == ["B"])
        model.open(position: 9, forceNew: false)
        #expect(ghostty.opened == ["B"])
    }

    @Test func `la lista filtrada se recalcula al cambiar el archivo`() {
        let (model, _) = makeModel()
        #expect(model.items.count == 2)
        model.store.apply("projects:\n  - name: C\n    root: /c\n    tabs:\n      - title: C\n")
        #expect(model.items.map(\.name) == ["C"])
    }
}
