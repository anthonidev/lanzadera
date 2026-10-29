import Foundation
import LanzaderaCore
import LanzaderaSystem
import Observation

/// Estado del panel lateral: búsqueda, selección, indicadores y apertura. Sin vistas, para probarlo.
@Observable
public final class PanelViewModel {
    public let store: ProjectStore
    @ObservationIgnored private let launcher: ProjectLauncher

    public var query = "" {
        didSet { if query != oldValue { selection = 0 } }
    }
    public var selection = 0
    /// Proyectos abiertos ahora en Ghostty.
    public private(set) var openNames: Set<String> = []
    /// Carpetas que faltan, por proyecto.
    public private(set) var missingFolders: [String: [String]] = [:]
    /// Ícono encontrado de cada proyecto (favicon o el de `icon:`).
    public private(set) var icons: [String: ProjectIcon] = [:]
    @ObservationIgnored private var iconTask: Task<Void, Never>?
    /// Mensaje dentro del panel (por ejemplo, la carpeta que falta al intentar abrir).
    public var notice: String?
    /// ⌥ apretado: Enter o clic abren ventanas nuevas.
    public var isOptionHeld = false
    /// Cambia en cada apertura: la vista enfoca la búsqueda y anima la entrada de las filas.
    public private(set) var presentationID = 0

    /// Posición del cursor al abrir: el hover no cambia la selección hasta que el mouse se mueva
    /// (si el panel aparece bajo el cursor, la selección debe seguir en el primero).
    @ObservationIgnored private var hoverAnchor: CGPoint?
    @ObservationIgnored private var itemsCache: ItemsCache?

    private struct ItemsCache {
        var query: String
        var revision: Int
        var items: [ProjectEntry]
    }

    @ObservationIgnored public var onClose: () -> Void = {}
    @ObservationIgnored public var onOpenConfig: () -> Void = {}
    @ObservationIgnored public var onOpenSettings: () -> Void = {}
    @ObservationIgnored public var onImport: () -> Void = {}
    /// Algo salió mal con el panel ya cerrado (permiso, error de Ghostty).
    @ObservationIgnored public var onLaunchProblem: (LaunchResult, Project) -> Void = { _, _ in }

    public init(store: ProjectStore, launcher: ProjectLauncher) {
        self.store = store
        self.launcher = launcher
    }

    /// Lo que se ve en la lista según la búsqueda. Se calcula una vez por cambio de búsqueda o de archivo,
    /// no en cada acceso (la vista lo lee varias veces por dibujo).
    public var items: [ProjectEntry] {
        let revision = store.revision
        if let cache = itemsCache, cache.query == query, cache.revision == revision { return cache.items }
        let items = ProjectFilter.filter(store.entries, query: query, name: \.name)
        itemsCache = ItemsCache(query: query, revision: revision, items: items)
        return items
    }

    public var selectedEntry: ProjectEntry? {
        let items = items
        return items.indices.contains(selection) ? items[selection] : nil
    }

    /// Llamado cada vez que se muestra el panel.
    public func prepareForPresentation(mouseLocation: CGPoint? = nil) {
        query = ""
        selection = 0
        notice = nil
        isOptionHeld = false
        hoverAnchor = mouseLocation
        presentationID += 1
        refreshFolders()
        refreshIcons()
    }

    /// Busca y carga los íconos en segundo plano. Barato si nada cambió: solo mira fechas de archivos.
    public func refreshIcons() {
        iconTask?.cancel()
        let projects = store.projects
        let previous = icons
        iconTask = Task { [weak self] in
            let loaded = await ProjectIconLoader.load(for: projects, reusing: previous)
            guard !Task.isCancelled else { return }
            self?.icons = loaded
        }
    }

    /// El mouse pasa sobre una fila. Solo selecciona si el cursor se movió desde que se abrió el panel.
    public func hover(_ index: Int, mouseLocation: CGPoint) {
        if let anchor = hoverAnchor {
            guard anchor != mouseLocation else { return }
            hoverAnchor = nil
        }
        guard items.indices.contains(index) else { return }
        selection = index
    }

    /// ⌘1…⌘9: abre directo el proyecto en esa posición de la lista.
    public func open(position: Int, forceNew: Bool) {
        let items = items
        guard items.indices.contains(position - 1) else { return }
        selection = position - 1
        open(items[position - 1], forceNew: forceNew)
    }

    /// Consulta a Ghostty qué está abierto. Se llama justo después de mostrar el panel para no demorarlo.
    public func refreshOpenStates() {
        openNames = launcher.openProjects(among: store.projects)
    }

    public func refreshFolders() {
        var missing: [String: [String]] = [:]
        for project in store.projects {
            let folders = launcher.missingFolders(of: project)
            if !folders.isEmpty { missing[project.name] = folders }
        }
        missingFolders = missing
    }

    public func moveSelection(by delta: Int) {
        let count = items.count
        guard count > 0 else { return }
        selection = min(max(selection + delta, 0), count - 1)
    }

    public func openSelected(forceNew: Bool) {
        guard let entry = selectedEntry else { return }
        open(entry, forceNew: forceNew)
    }

    public func open(_ entry: ProjectEntry, forceNew: Bool) {
        guard let project = entry.project else {
            notice = "«\(entry.name)» tiene errores en el archivo: corrígelos con ⚙️ Configurar."
            return
        }
        let missing = launcher.missingFolders(of: project)
        guard missing.isEmpty else {
            notice = Self.missingMessage(missing)
            missingFolders[project.name] = missing
            return
        }
        // Primero se cierra el panel: Ghostty debe quedar al frente.
        onClose()
        let result = launcher.launch(project, forceNew: forceNew)
        switch result {
        case .opened, .focused:
            openNames.insert(project.name)
        case .missingFolders, .permissionDenied, .failed:
            onLaunchProblem(result, project)
        }
    }

    public static func missingMessage(_ folders: [String]) -> String {
        let home = ProjectResolver.currentUserHome
        let list = folders.map { $0.hasPrefix(home + "/") ? "~" + $0.dropFirst(home.count) : $0 }
        return folders.count == 1
            ? "No existe la carpeta \(list[0])"
            : "No existen las carpetas: " + list.joined(separator: ", ")
    }
}
