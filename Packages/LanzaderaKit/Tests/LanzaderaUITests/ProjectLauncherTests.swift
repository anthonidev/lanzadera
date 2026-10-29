import LanzaderaCore
import LanzaderaSystem
import Testing
@testable import LanzaderaUI

final class FakeGhostty: GhosttyControlling {
    var isRunning = true
    var isAuthorized = true
    var openWindows: [GhosttyWindow] = []
    var opened: [String] = []
    var activated: [ProjectMatch] = []
    var error: ScriptError?
    var nextIDs = ["nueva-1"]
    var snapshotCount = 0
    var activateError: ScriptError?

    func windows() throws(ScriptError) -> [GhosttyWindow] {
        if let error { throw error }
        snapshotCount += 1
        return openWindows
    }

    func open(_ project: Project) throws(ScriptError) -> [String] {
        if let error { throw error }
        opened.append(project.name)
        return nextIDs
    }

    func activate(_ match: ProjectMatch) throws(ScriptError) {
        if let error = activateError ?? error { throw error }
        activated.append(match)
    }
}

final class FakeRegistry: WindowRegistering {
    var entries: [String: [String]] = [:]

    func windowIDs(for project: String) -> [String] { entries[project] ?? [] }
    func setWindowIDs(_ ids: [String], for project: String) { entries[project] = ids }
    func windowIDs(excluding project: String) -> Set<String> {
        Set(entries.filter { $0.key != project }.values.joined())
    }
}

struct FakeFolders: FolderChecking {
    var missing: Set<String> = []
    func exists(_ path: String) -> Bool { !missing.contains(path) }
}

@MainActor
struct ProjectLauncherTests {
    let project = Project(name: "Nexus", windows: [ProjectWindow(tabs: [
        ProjectTab(title: "BACKEND", panes: [Pane(directory: "/n/b"), Pane(directory: "/n/b")]),
        ProjectTab(title: "GLOBAL", panes: [Pane(directory: "/n")]),
    ])])

    @Test func `abre desde cero y registra las ventanas`() {
        let ghostty = FakeGhostty()
        let registry = FakeRegistry()
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        #expect(launcher.launch(project) == .opened)
        #expect(ghostty.opened == ["Nexus"])
        #expect(registry.entries["Nexus"] == ["nueva-1"])
    }

    @Test func `carpeta inexistente no llama a Ghostty`() {
        let ghostty = FakeGhostty()
        let launcher = ProjectLauncher(ghostty: ghostty, registry: FakeRegistry(), folders: FakeFolders(missing: ["/n"]))
        #expect(launcher.launch(project) == .missingFolders(["/n"]))
        #expect(ghostty.opened.isEmpty)
    }

    @Test func `si ya está abierto lo activa en vez de abrir otro`() {
        let ghostty = FakeGhostty()
        ghostty.openWindows = [GhosttyWindow(id: "w1", tabs: [GhosttyTab(id: "t1", name: "BACKEND")])]
        let registry = FakeRegistry()
        registry.entries["Nexus"] = ["w1"]
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        #expect(launcher.launch(project) == .focused)
        #expect(ghostty.opened.isEmpty)
        #expect(ghostty.activated.first?.mainTabID == "t1")
    }

    @Test func `con id muerto lo reconoce por huella y actualiza el registro`() {
        let ghostty = FakeGhostty()
        ghostty.openWindows = [GhosttyWindow(id: "restaurada", tabs: [
            GhosttyTab(id: "a", name: "BACKEND"), GhosttyTab(id: "b", name: "GLOBAL"),
        ])]
        let registry = FakeRegistry()
        registry.entries["Nexus"] = ["muerta"]
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        #expect(launcher.launch(project) == .focused)
        #expect(registry.entries["Nexus"] == ["restaurada"])
    }

    @Test func `forzar abre aunque ya esté abierto`() {
        let ghostty = FakeGhostty()
        ghostty.openWindows = [GhosttyWindow(id: "w1", tabs: [])]
        let registry = FakeRegistry()
        registry.entries["Nexus"] = ["w1"]
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        #expect(launcher.launch(project, forceNew: true) == .opened)
        #expect(ghostty.activated.isEmpty)
        #expect(registry.entries["Nexus"] == ["nueva-1"])
    }

    @Test func `Ghostty cerrado abre sin consultar`() {
        let ghostty = FakeGhostty()
        ghostty.isRunning = false
        ghostty.openWindows = [GhosttyWindow(id: "w1", tabs: [])]
        let registry = FakeRegistry()
        registry.entries["Nexus"] = ["w1"]
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        #expect(launcher.launch(project) == .opened)
        #expect(launcher.openProjects(among: [project]).isEmpty)
    }

    @Test func `abrir justo después de mostrar el panel reutiliza la foto`() {
        let ghostty = FakeGhostty()
        let launcher = ProjectLauncher(ghostty: ghostty, registry: FakeRegistry(), folders: FakeFolders())
        _ = launcher.openProjects(among: [project])
        #expect(launcher.launch(project) == .opened)
        #expect(ghostty.snapshotCount == 1)
        // Tras abrir, la foto se descarta: la siguiente apertura vuelve a consultar.
        _ = launcher.launch(project)
        #expect(ghostty.snapshotCount == 2)
    }

    @Test func `foto vencida se vuelve a pedir`() {
        let ghostty = FakeGhostty()
        let launcher = ProjectLauncher(ghostty: ghostty, registry: FakeRegistry(), folders: FakeFolders(), snapshotLifetime: .zero)
        _ = launcher.openProjects(among: [project])
        _ = launcher.launch(project)
        #expect(ghostty.snapshotCount == 2)
    }

    @Test func `si la ventana recordada ya no existe al activarla, abre desde cero`() {
        let ghostty = FakeGhostty()
        ghostty.openWindows = [GhosttyWindow(id: "w1", tabs: [])]
        ghostty.activateError = ScriptError(code: -1728, message: "no existe")
        let registry = FakeRegistry()
        registry.entries["Nexus"] = ["w1"]
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        #expect(launcher.launch(project) == .opened)
        #expect(registry.entries["Nexus"] == ["nueva-1"])
    }

    @Test func `sin permiso el indicador no consulta a Ghostty`() {
        let ghostty = FakeGhostty()
        ghostty.isAuthorized = false
        ghostty.error = ScriptError(code: -1, message: "no debería consultarse")
        let launcher = ProjectLauncher(ghostty: ghostty, registry: FakeRegistry(), folders: FakeFolders())
        #expect(launcher.openProjects(among: [project]).isEmpty)
    }

    @Test func `permiso denegado y error del script se informan sin registrar nada`() {
        let ghostty = FakeGhostty()
        let registry = FakeRegistry()
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        ghostty.error = ScriptError(code: -1743, message: "no")
        #expect(launcher.launch(project) == .permissionDenied)
        ghostty.error = ScriptError(code: -2700, message: "falló")
        #expect(launcher.launch(project) == .failed("falló"))
        #expect(registry.entries.isEmpty)
    }
}
