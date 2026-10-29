/// Un proyecto tal como está escrito en `proyectos.yaml`, antes de validarlo.
///
/// `LanzaderaConfig` lo arma desde el YAML; `ProjectResolver` lo convierte en `Project`.
/// Las líneas permiten decir dónde está cada error.
public struct ProjectSpec: Sendable, Hashable {
    public var name: String?
    public var emoji: String?
    public var color: String?
    public var root: String?
    /// `none`, una ruta (absoluta, con `~` o relativa a `root`) o nada (automático).
    public var icon: String?
    public var windows: [WindowSpec]
    public var line: Int?
    /// Problemas de forma ya detectados al leer el YAML (por ejemplo, un tipo incorrecto).
    public var issues: [ConfigIssue]

    public init(
        name: String? = nil, emoji: String? = nil, color: String? = nil, root: String? = nil, icon: String? = nil,
        windows: [WindowSpec] = [], line: Int? = nil, issues: [ConfigIssue] = []
    ) {
        self.name = name
        self.emoji = emoji
        self.color = color
        self.root = root
        self.icon = icon
        self.windows = windows
        self.line = line
        self.issues = issues
    }
}

public struct WindowSpec: Sendable, Hashable {
    public var tabs: [TabSpec]
    public var line: Int?

    public init(tabs: [TabSpec], line: Int? = nil) {
        self.tabs = tabs
        self.line = line
    }
}

public struct TabSpec: Sendable, Hashable {
    public var title: String?
    public var cwd: String?
    public var panes: PanesSpec
    public var split: String?
    public var focus: Bool
    public var line: Int?

    public init(
        title: String? = nil, cwd: String? = nil, panes: PanesSpec = .count(1), split: String? = nil,
        focus: Bool = false, line: Int? = nil
    ) {
        self.title = title
        self.cwd = cwd
        self.panes = panes
        self.split = split
        self.focus = focus
        self.line = line
    }
}

/// `panes: 3` o una lista de paneles con su propia carpeta.
public enum PanesSpec: Sendable, Hashable {
    case count(Int)
    case list([PaneSpec])
}

public struct PaneSpec: Sendable, Hashable {
    public var cwd: String?
    public var line: Int?

    public init(cwd: String? = nil, line: Int? = nil) {
        self.cwd = cwd
        self.line = line
    }
}

/// Un problema de contenido del archivo, con su línea si se conoce.
public struct ConfigIssue: Sendable, Hashable, CustomStringConvertible {
    public var message: String
    public var line: Int?

    public init(_ message: String, line: Int? = nil) {
        self.message = message
        self.line = line
    }

    public var description: String {
        guard let line else { return message }
        return "Línea \(line): \(message)"
    }
}

/// Un proyecto del archivo: listo para usar o con errores que impiden abrirlo.
public enum ProjectEntry: Sendable, Hashable, Identifiable {
    case valid(Project)
    case invalid(name: String, issues: [ConfigIssue])

    public var id: String { name }

    public var name: String {
        switch self {
        case .valid(let project): project.name
        case .invalid(let name, _): name
        }
    }

    public var project: Project? {
        if case .valid(let project) = self { project } else { nil }
    }

    public var issues: [ConfigIssue] {
        if case .invalid(_, let issues) = self { issues } else { [] }
    }
}
