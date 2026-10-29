import LanzaderaCore
import LanzaderaSystem
import Testing
@testable import LanzaderaUI

final class FakeGhostty: GhosttyControlling {
    var isRunning = true
    var isAuthorized = true
    var isInstalled = true
    var openWindows: [GhosttyWindow] = []
    var opened: [String] = []
    var activated: [ProjectMatch] = []
    var error: ScriptError?
    var nextIDs = ["nueva-1"]
    var snapshotCount = 0
    var activateError: ScriptError?

    func windows() async throws(ScriptError) -> [GhosttyWindow] {
        if let error { throw error }
        snapshotCount += 1
        return openWindows
    }

    func open(_ project: Project) async throws(ScriptError) -> [String] {
        if let error { throw error }
        opened.append(project.name)
        return nextIDs
    }

    func activate(_ match: ProjectMatch) async throws(ScriptError) {
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

    @Test func `abre desde cero y registra las ventanas`() async {
        let ghostty = FakeGhostty()
        let registry = FakeRegistry()
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        #expect(await launcher.launch(project) == .opened)
        #expect(ghostty.opened == ["Nexus"])
        #expect(registry.entries["Nexus"] == ["nueva-1"])
    }

    @Test func `carpeta inexistente no llama a Ghostty`() async {
        let ghostty = FakeGhostty()
        let launcher = ProjectLauncher(ghostty: ghostty, registry: FakeRegistry(), folders: FakeFolders(missing: ["/n"]))
        #expect(await launcher.launch(project) == .missingFolders(["/n"]))
        #expect(ghostty.opened.isEmpty)
    }

    @Test func `si ya está abierto lo activa en vez de abrir otro`() async {
        let ghostty = FakeGhostty()
        ghostty.openWindows = [GhosttyWindow(id: "w1", tabs: [GhosttyTab(id: "t1", name: "BACKEND")])]
        let registry = FakeRegistry()
        registry.entries["Nexus"] = ["w1"]
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        #expect(await launcher.launch(project) == .focused)
        #expect(ghostty.opened.isEmpty)
        #expect(ghostty.activated.first?.mainTabID == "t1")
    }

    @Test func `con id muerto lo reconoce por huella y actualiza el registro`() async {
        let ghostty = FakeGhostty()
        ghostty.openWindows = [GhosttyWindow(id: "restaurada", tabs: [
            GhosttyTab(id: "a", name: "BACKEND"), GhosttyTab(id: "b", name: "GLOBAL"),
        ])]
        let registry = FakeRegistry()
        registry.entries["Nexus"] = ["muerta"]
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        #expect(await launcher.launch(project) == .focused)
        #expect(registry.entries["Nexus"] == ["restaurada"])
    }

    @Test func `forzar abre aunque ya esté abierto`() async {
        let ghostty = FakeGhostty()
        ghostty.openWindows = [GhosttyWindow(id: "w1", tabs: [])]
        let registry = FakeRegistry()
        registry.entries["Nexus"] = ["w1"]
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        #expect(await launcher.launch(project, forceNew: true) == .opened)
        #expect(ghostty.activated.isEmpty)
        #expect(registry.entries["Nexus"] == ["nueva-1"])
    }

    @Test func `Ghostty cerrado abre sin consultar`() async {
        let ghostty = FakeGhostty()
        ghostty.isRunning = false
        ghostty.openWindows = [GhosttyWindow(id: "w1", tabs: [])]
        let registry = FakeRegistry()
        registry.entries["Nexus"] = ["w1"]
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        #expect(await launcher.launch(project) == .opened)
        #expect(await launcher.openProjects(among: [project]).isEmpty)
    }

    @Test func `abrir justo después de mostrar el panel reutiliza la foto`() async {
        let ghostty = FakeGhostty()
        let launcher = ProjectLauncher(ghostty: ghostty, registry: FakeRegistry(), folders: FakeFolders())
        _ = await launcher.openProjects(among: [project])
        #expect(await launcher.launch(project) == .opened)
        #expect(ghostty.snapshotCount == 1)
        // Tras abrir, la foto se descarta: la siguiente apertura vuelve a consultar.
        _ = await launcher.launch(project)
        #expect(ghostty.snapshotCount == 2)
    }

    @Test func `foto vencida se vuelve a pedir`() async {
        let ghostty = FakeGhostty()
        let launcher = ProjectLauncher(ghostty: ghostty, registry: FakeRegistry(), folders: FakeFolders(), snapshotLifetime: .zero)
        _ = await launcher.openProjects(among: [project])
        _ = await launcher.launch(project)
        #expect(ghostty.snapshotCount == 2)
    }

    @Test func `si la ventana recordada ya no existe al activarla, abre desde cero`() async {
        let ghostty = FakeGhostty()
        ghostty.openWindows = [GhosttyWindow(id: "w1", tabs: [])]
        ghostty.activateError = ScriptError(code: -1728, message: "no existe")
        let registry = FakeRegistry()
        registry.entries["Nexus"] = ["w1"]
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        #expect(await launcher.launch(project) == .opened)
        #expect(registry.entries["Nexus"] == ["nueva-1"])
    }

    @Test func `sin permiso el indicador no consulta a Ghostty`() async {
        let ghostty = FakeGhostty()
        ghostty.isAuthorized = false
        ghostty.error = ScriptError(code: -1, message: "no debería consultarse")
        let launcher = ProjectLauncher(ghostty: ghostty, registry: FakeRegistry(), folders: FakeFolders())
        #expect(await launcher.openProjects(among: [project]).isEmpty)
    }

    @Test func `sin Ghostty instalado avisa sin intentar abrir`() async {
        let ghostty = FakeGhostty()
        ghostty.isInstalled = false
        let launcher = ProjectLauncher(ghostty: ghostty, registry: FakeRegistry(), folders: FakeFolders())
        #expect(await launcher.launch(project) == .ghosttyMissing)
        #expect(ghostty.opened.isEmpty)
    }

    @Test func `permiso denegado y error del script se informan sin registrar nada`() async {
        let ghostty = FakeGhostty()
        let registry = FakeRegistry()
        let launcher = ProjectLauncher(ghostty: ghostty, registry: registry, folders: FakeFolders())
        ghostty.error = ScriptError(code: -1743, message: "no")
        #expect(await launcher.launch(project) == .permissionDenied)
        ghostty.error = ScriptError(code: -2700, message: "falló")
        #expect(await launcher.launch(project) == .failed("falló"))
        #expect(registry.entries.isEmpty)
    }
}

struct LaunchProblemTests {
    @Test func `abrir bien no es un problema y cada fallo ofrece su acción`() {
        #expect(LaunchProblem(.opened, projectName: "X") == nil)
        #expect(LaunchProblem(.focused, projectName: "X") == nil)
        #expect(LaunchProblem(.permissionDenied, projectName: "X")?.action == .openAutomationSettings)
        #expect(LaunchProblem(.ghosttyMissing, projectName: "X")?.action == .downloadGhostty)
        #expect(LaunchProblem(.missingFolders(["/a"]), projectName: "X")?.action == .editConfig)
        let failed = LaunchProblem(.failed("boom"), projectName: "Nexus")
        #expect(failed?.title == "No se pudo abrir «Nexus» en Ghostty")
        #expect(failed?.message == "boom")
        #expect(failed?.action == nil)
    }
}
