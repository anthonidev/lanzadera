import Foundation

/// Un proyecto de Warp listo para revisar antes de importarlo.
public struct ImportCandidate: Sendable, Hashable, Identifiable {
    public var name: String
    public var emoji: String?
    public var windows: [ImportWindow]
    /// Índice de la ventana que Warp tenía activa: se toma como la ventana "real" del proyecto.
    public var mainWindowIndex: Int

    public var id: String { name }
}

public struct ImportWindow: Sendable, Hashable {
    public var tabs: [ImportTab]
    public var focusedTabIndex: Int
    public var warnings: [String]
    /// Se propone descartarla (carpeta inexistente, fuera del proyecto o repetida de otro proyecto).
    public var suggestedExclusion: Bool

    public var directories: [String] { tabs.flatMap(\.directories) }
}

public struct ImportTab: Sendable, Hashable {
    public var title: String
    public var split: SplitDirection
    /// Carpeta absoluta de cada panel.
    public var directories: [String]
}

/// Convierte las *Launch Configurations* de Warp al formato de Lanzadera, con avisos.
public struct WarpImporter: Sendable {
    public let homeDirectory: String
    public let folderExists: @Sendable (String) -> Bool

    public init(homeDirectory: String, folderExists: @escaping @Sendable (String) -> Bool) {
        self.homeDirectory = homeDirectory
        self.folderExists = folderExists
    }

    public func candidates(from configs: [WarpLaunchConfig]) -> [ImportCandidate] {
        let converted = configs.map { config in
            (config, config.windows.map(convert))
        }
        // Huella de la ventana principal de cada configuración, para detectar copias en otras.
        let mainSignatures: [(name: String, signature: WindowSignature)] = converted.compactMap { config, windows in
            guard windows.indices.contains(mainIndex(of: config)) else { return nil }
            return (config.name, WindowSignature(windows[mainIndex(of: config)].window))
        }

        return converted.map { config, windows in
            let main = min(mainIndex(of: config), max(windows.count - 1, 0))
            let mainRoot = windows.indices.contains(main) ? commonDirectory(of: windows[main].window.directories) : nil
            var result: [ImportWindow] = []
            for (index, converted) in windows.enumerated() {
                var window = converted.window
                var exclude = false
                let missing = Set(window.directories).filter { !folderExists($0) }.sorted()
                for folder in missing {
                    window.warnings.append("La carpeta \(display(folder)) no existe")
                    exclude = true
                }
                if index != main {
                    if let duplicate = mainSignatures.first(where: { $0.name != config.name && $0.signature == WindowSignature(window) }) {
                        window.warnings.append("Repite la ventana del proyecto «\(duplicate.name)»")
                        exclude = true
                    } else if let mainRoot, !window.directories.allSatisfy({ isInside($0, mainRoot) }) {
                        window.warnings.append("Está fuera de la carpeta del proyecto (\(display(mainRoot)))")
                        exclude = true
                    }
                }
                window.warnings.append(contentsOf: converted.notes)
                window.suggestedExclusion = exclude && index != main
                result.append(window)
            }
            let emoji = windows.indices.contains(main)
                ? config.windows[main].tabs.first?.color.flatMap { MarkerColor(rawValue: $0.lowercased())?.emoji }
                : nil
            return ImportCandidate(name: config.name, emoji: emoji, windows: result, mainWindowIndex: main)
        }
    }

    /// El proyecto a escribir con las ventanas elegidas: la carpeta común pasa a `root` y el resto queda relativo.
    public func spec(for candidate: ImportCandidate, including windowIndices: Set<Int>) -> ProjectSpec {
        let windows = candidate.windows.indices.filter(windowIndices.contains).map { candidate.windows[$0] }
        let root = commonDirectory(of: windows.flatMap(\.directories))
        let windowSpecs = windows.map { window in
            WindowSpec(tabs: window.tabs.enumerated().map { index, tab in
                let tabDirectory = tab.directories.first ?? root ?? homeDirectory
                let panes: PanesSpec = Set(tab.directories).count <= 1
                    ? .count(tab.directories.count)
                    : .list(tab.directories.map { PaneSpec(cwd: relative($0, to: root)) })
                return TabSpec(
                    title: tab.title,
                    cwd: tabDirectory == root ? nil : relative(tabDirectory, to: root),
                    panes: panes,
                    split: tab.split == .right ? nil : tab.split.rawValue,
                    focus: index == window.focusedTabIndex && index != 0
                )
            })
        }
        return ProjectSpec(name: candidate.name, emoji: candidate.emoji, root: root.map(display), windows: windowSpecs)
    }

    // MARK: - Conversión

    private func mainIndex(of config: WarpLaunchConfig) -> Int {
        config.windows.indices.contains(config.activeWindowIndex) ? config.activeWindowIndex : 0
    }

    private func convert(_ window: WarpWindow) -> (window: ImportWindow, notes: [String]) {
        var notes = Set<String>()
        let tabs = window.tabs.map { tab in
            let (leaves, nested) = flatten(tab.layout)
            if nested { notes.insert("Tenía divisiones anidadas: los paneles quedan en una sola fila") }
            if leaves.contains(where: { !$0.commands.isEmpty }) {
                notes.insert("Los comandos de Warp todavía no se importan")
            }
            let directories = leaves.map { $0.cwd.map(expand) ?? homeDirectory }
            let baseTitle = tab.title?.trimmingCharacters(in: .whitespaces).nonEmpty
                ?? directories.first.map { URL(filePath: $0).lastPathComponent } ?? "Terminal"
            let emoji = tab.color.flatMap { MarkerColor(rawValue: $0.lowercased())?.emoji }
            return ImportTab(
                title: emoji.map { "\($0) \(baseTitle)" } ?? baseTitle,
                split: splitDirection(of: tab.layout),
                directories: directories
            )
        }
        let focused = tabs.indices.contains(window.activeTabIndex) ? window.activeTabIndex : 0
        let converted = ImportWindow(tabs: tabs, focusedTabIndex: focused, warnings: [], suggestedExclusion: false)
        return (converted, notes.sorted())
    }

    private func flatten(_ layout: WarpLayout, depth: Int = 0) -> (leaves: [(cwd: String?, commands: [String])], nested: Bool) {
        switch layout {
        case .pane(let cwd, _, let commands):
            return ([(cwd, commands)], false)
        case .split(_, let panes):
            let children = panes.map { flatten($0, depth: depth + 1) }
            let containsSplit = panes.contains { if case .split = $0 { true } else { false } }
            return (children.flatMap(\.leaves), containsSplit || children.contains(where: \.nested))
        }
    }

    private func splitDirection(of layout: WarpLayout) -> SplitDirection {
        // En Warp `horizontal` pone los paneles uno al lado del otro.
        if case .split(let direction, _) = layout, direction.lowercased() == "vertical" { return .down }
        return .right
    }

    // MARK: - Rutas

    private func expand(_ path: String) -> String {
        if path == "~" { return homeDirectory }
        if path.hasPrefix("~/") { return homeDirectory + path.dropFirst(1) }
        return path.trimmingTrailingSlash
    }

    /// `~/nexus` en vez de `/Users/tonis/nexus`.
    func display(_ path: String) -> String {
        if path == homeDirectory { return "~" }
        if path.hasPrefix(homeDirectory + "/") { return "~" + path.dropFirst(homeDirectory.count) }
        return path
    }

    private func relative(_ path: String, to root: String?) -> String {
        guard let root else { return display(path) }
        if path == root { return "." }
        if path.hasPrefix(root + "/") { return String(path.dropFirst(root.count + 1)) }
        return display(path)
    }

    private func isInside(_ path: String, _ root: String) -> Bool {
        path == root || path.hasPrefix(root + "/")
    }

    /// Carpeta común más profunda, o `nil` si sería la carpeta personal o algo más arriba (no sirve de `root`).
    func commonDirectory(of paths: [String]) -> String? {
        guard let first = paths.first else { return nil }
        var common = first.split(separator: "/", omittingEmptySubsequences: true)
        for path in paths.dropFirst() {
            let parts = path.split(separator: "/", omittingEmptySubsequences: true)
            common = Array(zip(common, parts).prefix { $0 == $1 }.map(\.0))
        }
        let result = "/" + common.joined(separator: "/")
        guard common.count > 1, result != homeDirectory, !isInside(homeDirectory, result) else { return nil }
        return result
    }
}

/// Lo que identifica una ventana al compararla con la de otro proyecto: títulos y carpetas,
/// sin la cantidad de paneles (las copias de Warp a veces tienen uno menos).
private struct WindowSignature: Hashable {
    let titles: [String]
    let directories: Set<String>

    init(_ window: ImportWindow) {
        titles = window.tabs.map(\.title)
        directories = Set(window.directories)
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
