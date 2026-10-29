import LanzaderaCore
import LanzaderaSystem
import os

/// Qué pasó al elegir un proyecto.
public enum LaunchResult: Sendable, Equatable {
    /// Se abrió desde cero.
    case opened
    /// Ya estaba abierto: se trajeron sus ventanas al frente.
    case focused
    /// No se abrió nada porque faltan estas carpetas.
    case missingFolders([String])
    /// macOS no deja controlar Ghostty.
    case permissionDenied
    /// Ghostty no está instalado.
    case ghosttyMissing
    case failed(String)
}

/// Orquesta la apertura: comprobar carpetas → ¿ya abierto? → abrir → recordar sus ventanas.
///
/// La foto de Ghostty que se toma al mostrar el panel (para el indicador) se reutiliza al elegir
/// un proyecto unos segundos después, y si todavía está en curso se espera en vez de pedir otra.
public final class ProjectLauncher {
    private let ghostty: any GhosttyControlling
    private let registry: any WindowRegistering
    private let folders: any FolderChecking
    private let snapshotLifetime: Duration
    private var snapshot: (windows: [GhosttyWindow], takenAt: ContinuousClock.Instant)?
    private var pendingSnapshot: Task<[GhosttyWindow]?, Never>?
    private let logger = Logger(subsystem: "dev.tonis.lanzadera", category: "launcher")

    public init(
        ghostty: any GhosttyControlling,
        registry: any WindowRegistering,
        folders: any FolderChecking,
        snapshotLifetime: Duration = .seconds(5)
    ) {
        self.ghostty = ghostty
        self.registry = registry
        self.folders = folders
        self.snapshotLifetime = snapshotLifetime
    }

    /// Carpetas del proyecto que no existen. Se vuelve a comprobar en cada apertura: pueden desaparecer.
    public func missingFolders(of project: Project) -> [String] {
        project.directories.filter { !folders.exists($0) }
    }

    /// - Parameter forceNew: abre ventanas nuevas aunque el proyecto ya esté abierto (⌥).
    public func launch(_ project: Project, forceNew: Bool = false) async -> LaunchResult {
        let missing = missingFolders(of: project)
        guard missing.isEmpty else { return .missingFolders(missing) }
        guard ghostty.isInstalled else { return .ghosttyMissing }
        defer { snapshot = nil } // Después de abrir o activar, lo que había ya no vale.
        do {
            if !forceNew, let match = try await openMatch(for: project) {
                do {
                    try await ghostty.activate(match)
                    registry.setWindowIDs(match.windowIDs, for: project.name)
                    logger.info("«\(project.name, privacy: .public)» ya estaba abierto\(match.foundByFingerprint ? " (por huella)" : "")")
                    return .focused
                } catch where !error.isPermissionDenied {
                    // La foto era vieja y esa ventana ya no existe: se abre desde cero.
                    logger.notice("No se pudo activar «\(project.name, privacy: .public)»: \(error.description, privacy: .public)")
                }
            }
            let ids = try await ghostty.open(project)
            registry.setWindowIDs(ids, for: project.name)
            logger.info("«\(project.name, privacy: .public)» abierto en \(ids.count) ventanas")
            return .opened
        } catch {
            return error.isPermissionDenied ? .permissionDenied : .failed(error.message)
        }
    }

    /// Nombres de los proyectos abiertos ahora en Ghostty (para el indicador del panel).
    /// Si Ghostty no está corriendo devuelve vacío sin abrirlo, y sin permiso no pregunta:
    /// la alerta de macOS debe salir al abrir un proyecto, no al mirar la lista.
    public func openProjects(among projects: [Project]) async -> Set<String> {
        guard ghostty.isRunning, ghostty.isAuthorized else {
            snapshot = nil
            return []
        }
        let ghostty = ghostty
        let task = Task { try? await ghostty.windows() }
        pendingSnapshot = task
        let windows = await task.value
        if pendingSnapshot == task { pendingSnapshot = nil }
        guard let windows else {
            snapshot = nil
            return []
        }
        snapshot = (windows, .now)
        return Set(projects.filter { match($0, in: windows) != nil }.map(\.name))
    }

    private func openMatch(for project: Project) async throws(ScriptError) -> ProjectMatch? {
        guard ghostty.isRunning else { return nil }
        if let pendingSnapshot, let windows = await pendingSnapshot.value {
            return match(project, in: windows)
        }
        if let snapshot, ContinuousClock.now - snapshot.takenAt < snapshotLifetime {
            return match(project, in: snapshot.windows)
        }
        return match(project, in: try await ghostty.windows())
    }

    private func match(_ project: Project, in windows: [GhosttyWindow]) -> ProjectMatch? {
        OpenProjectMatcher.match(
            project,
            in: windows,
            registered: registry.windowIDs(for: project.name),
            claimed: registry.windowIDs(excluding: project.name)
        )
    }
}
