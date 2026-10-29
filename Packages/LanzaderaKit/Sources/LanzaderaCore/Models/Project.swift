/// Un proyecto ya resuelto y válido: rutas absolutas, una pestaña principal por ventana.
public struct Project: Sendable, Hashable, Identifiable {
    public var name: String
    public var marker: ProjectMarker?
    public var icon: IconSetting
    public var windows: [ProjectWindow]

    public var id: String { name }

    public init(name: String, marker: ProjectMarker? = nil, icon: IconSetting = .automatic, windows: [ProjectWindow]) {
        self.name = name
        self.marker = marker
        self.icon = icon
        self.windows = windows
    }

    /// Ventana que queda al frente al abrir: la que tiene una pestaña marcada como principal, o la primera.
    public var mainWindowIndex: Int {
        windows.firstIndex { window in window.tabs.contains(where: \.isFocused) } ?? 0
    }

    /// Todas las carpetas que usa el proyecto, sin repetir y en orden de aparición.
    public var directories: [String] {
        var seen = Set<String>()
        return windows.flatMap(\.tabs).flatMap(\.panes).map(\.directory).filter { seen.insert($0).inserted }
    }
}

/// Lo que se dibuja junto al nombre en la lista.
public enum ProjectMarker: Sendable, Hashable {
    case emoji(String)
    case color(MarkerColor)
}

/// De dónde sale el ícono del proyecto en la lista.
public enum IconSetting: Sendable, Hashable {
    /// Se busca un favicon o similar en las carpetas del proyecto (`ProjectIconFinder`).
    case automatic
    /// `icon: none`: sin ícono, se usa el emoji o el color.
    case none
    /// `icon: ruta`: un archivo de imagen concreto (ruta absoluta ya resuelta).
    case file(String)
}

/// Colores admitidos en `color:`, los mismos que usa Warp en las pestañas.
public enum MarkerColor: String, Sendable, Hashable, CaseIterable {
    case red, green, blue, magenta, yellow, cyan, black, white

    /// Emoji equivalente, para títulos de pestaña (Ghostty no colorea pestañas).
    public var emoji: String {
        switch self {
        case .red: "🔴"
        case .green: "🟢"
        case .blue: "🔵"
        case .magenta: "🟣"
        case .yellow: "🟡"
        case .cyan: "🩵"
        case .black: "⚫"
        case .white: "⚪"
        }
    }
}

public struct ProjectWindow: Sendable, Hashable {
    public var tabs: [ProjectTab]

    public init(tabs: [ProjectTab]) {
        self.tabs = tabs
    }

    /// Pestaña que queda seleccionada en esta ventana.
    public var focusedTabIndex: Int {
        tabs.firstIndex(where: \.isFocused) ?? 0
    }
}

public struct ProjectTab: Sendable, Hashable {
    public var title: String
    public var split: SplitDirection
    /// Nunca vacío: una pestaña tiene al menos un panel.
    public var panes: [Pane]
    public var isFocused: Bool

    public init(title: String, split: SplitDirection = .right, panes: [Pane], isFocused: Bool = false) {
        self.title = title
        self.split = split
        self.panes = panes
        self.isFocused = isFocused
    }
}

public struct Pane: Sendable, Hashable {
    /// Ruta absoluta, con `~` ya expandido.
    public var directory: String

    public init(directory: String) {
        self.directory = directory
    }
}

/// Hacia dónde se agregan los paneles de una pestaña.
public enum SplitDirection: String, Sendable, Hashable, CaseIterable {
    /// De lado a lado.
    case right
    /// Hacia abajo.
    case down
}
