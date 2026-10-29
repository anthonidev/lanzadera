/// Dónde está abierto un proyecto en Ghostty.
public struct ProjectMatch: Sendable, Hashable {
    public var windowIDs: [String]
    public var mainWindowID: String
    /// Pestaña principal dentro de la ventana principal, si sigue existiendo con su nombre.
    public var mainTabID: String?
    /// `true` si se reconoció por los nombres de pestaña y no por un `id` registrado.
    public var foundByFingerprint: Bool
}

/// Decide si un proyecto ya está abierto: primero por los `id` registrados al abrirlo
/// y, si ya no existen (Ghostty se reinició), por la huella de sus pestañas.
public enum OpenProjectMatcher {
    /// - Parameters:
    ///   - registered: `id` de ventanas guardados al abrir el proyecto, en el orden de sus ventanas.
    ///   - claimed: ventanas registradas a otros proyectos, que no se pueden adoptar por huella.
    public static func match(
        _ project: Project, in windows: [GhosttyWindow], registered: [String], claimed: Set<String> = []
    ) -> ProjectMatch? {
        let byID = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if registered.contains(where: { byID[$0] != nil }) {
            // Si el registro tiene una ventana por cada ventana del proyecto, se conserva la correspondencia.
            let aligned = registered.count == project.windows.count
            let mainIndex = project.mainWindowIndex
            let mainID = aligned && byID[registered[mainIndex]] != nil
                ? registered[mainIndex]
                : registered.first { byID[$0] != nil }
            guard let mainID, let mainWindow = byID[mainID] else { return nil }
            let projectWindow = aligned ? project.windows[registered.firstIndex(of: mainID) ?? mainIndex] : project.windows[mainIndex]
            return ProjectMatch(
                windowIDs: registered.filter { byID[$0] != nil },
                mainWindowID: mainID,
                mainTabID: tabID(in: mainWindow, for: projectWindow),
                foundByFingerprint: false
            )
        }
        return matchByFingerprint(project, in: windows, excluding: claimed)
    }

    /// Huella de una ventana: los nombres de sus pestañas, exactos y en orden.
    public static func fingerprint(of window: ProjectWindow) -> [String] {
        window.tabs.map(\.title)
    }

    private static func matchByFingerprint(
        _ project: Project, in windows: [GhosttyWindow], excluding claimed: Set<String>
    ) -> ProjectMatch? {
        var used = claimed
        var found: [Int: GhosttyWindow] = [:]
        for (index, projectWindow) in project.windows.enumerated() {
            let expected = fingerprint(of: projectWindow)
            if let window = windows.first(where: { !used.contains($0.id) && $0.tabNames == expected }) {
                found[index] = window
                used.insert(window.id)
            }
        }
        guard !found.isEmpty else { return nil }
        let mainIndex = found[project.mainWindowIndex] != nil ? project.mainWindowIndex : (found.keys.min() ?? 0)
        guard let mainWindow = found[mainIndex] else { return nil }
        return ProjectMatch(
            windowIDs: found.keys.sorted().compactMap { found[$0]?.id },
            mainWindowID: mainWindow.id,
            mainTabID: tabID(in: mainWindow, for: project.windows[mainIndex]),
            foundByFingerprint: true
        )
    }

    private static func tabID(in window: GhosttyWindow, for projectWindow: ProjectWindow) -> String? {
        let title = projectWindow.tabs[projectWindow.focusedTabIndex].title
        return window.tabs.first { $0.name == title }?.id
    }
}
