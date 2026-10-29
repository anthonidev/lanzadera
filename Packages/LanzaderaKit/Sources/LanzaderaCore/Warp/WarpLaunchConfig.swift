/// Una *Launch Configuration* de Warp (`~/.warp/launch_configurations/*.yaml`).
public struct WarpLaunchConfig: Sendable, Hashable {
    public var name: String
    public var activeWindowIndex: Int
    public var windows: [WarpWindow]

    public init(name: String, activeWindowIndex: Int = 0, windows: [WarpWindow]) {
        self.name = name
        self.activeWindowIndex = activeWindowIndex
        self.windows = windows
    }
}

public struct WarpWindow: Sendable, Hashable {
    public var activeTabIndex: Int
    public var tabs: [WarpTab]

    public init(activeTabIndex: Int = 0, tabs: [WarpTab]) {
        self.activeTabIndex = activeTabIndex
        self.tabs = tabs
    }
}

public struct WarpTab: Sendable, Hashable {
    public var title: String?
    public var color: String?
    public var layout: WarpLayout

    public init(title: String? = nil, color: String? = nil, layout: WarpLayout) {
        self.title = title
        self.color = color
        self.layout = layout
    }
}

/// El esquema de Warp es recursivo: una hoja (un panel) o una división con más layouts.
public indirect enum WarpLayout: Sendable, Hashable {
    case pane(cwd: String?, isFocused: Bool, commands: [String])
    /// `horizontal` (lado a lado) o `vertical` (hacia abajo).
    case split(direction: String, panes: [WarpLayout])
}
