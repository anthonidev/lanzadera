/// Foto de lo que hay abierto en Ghostty: ventanas, pestañas y carpetas de sus terminales.
public struct GhosttyWindow: Sendable, Hashable {
    public var id: String
    public var tabs: [GhosttyTab]

    public init(id: String, tabs: [GhosttyTab]) {
        self.id = id
        self.tabs = tabs
    }

    public var tabNames: [String] { tabs.map(\.name) }
}

public struct GhosttyTab: Sendable, Hashable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum GhosttySnapshot {
    /// Interpreta lo que devuelve `GhosttyScript.snapshot`: tres listas paralelas
    /// `{{idVentana…}, {{idPestaña…}…}, {{nombre…}…}}`. Lo que no tenga la forma esperada se ignora.
    public static func parse(_ value: ScriptValue) -> [GhosttyWindow] {
        guard let parts = value.list, parts.count == 3 else { return [] }
        let windowIDs = parts[0].texts
        let tabIDs = perWindow(parts[1], windows: windowIDs.count)
        let names = perWindow(parts[2], windows: windowIDs.count)
        return windowIDs.enumerated().map { index, id in
            let ids = tabIDs.indices.contains(index) ? tabIDs[index] : []
            let titles = names.indices.contains(index) ? names[index] : []
            return GhosttyWindow(id: id, tabs: zip(ids, titles).map { GhosttyTab(id: $0, name: $1) })
        }
    }

    /// Una lista por ventana. Con una sola ventana AppleScript puede devolver la lista "aplanada".
    private static func perWindow(_ value: ScriptValue, windows: Int) -> [[String]] {
        let items = value.list ?? []
        if windows == 1, items.allSatisfy({ $0.text != nil }) { return [items.compactMap(\.text)] }
        return items.map(\.texts)
    }
}
