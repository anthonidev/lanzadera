import Foundation

/// Búsqueda escribiendo: sin distinguir mayúsculas ni tildes ("clínic" encuentra Clinicsay).
public enum ProjectFilter {
    /// Conserva el orden del archivo, pero pone primero los que empiezan con lo escrito.
    public static func filter<T>(_ items: [T], query: String, name: (T) -> String) -> [T] {
        let needle = normalized(query)
        guard !needle.isEmpty else { return items }
        let matches = items.filter { normalized(name($0)).contains(needle) }
        let prefixed = matches.filter { normalized(name($0)).hasPrefix(needle) }
        let others = matches.filter { !normalized(name($0)).hasPrefix(needle) }
        return prefixed + others
    }

    public static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
    }
}
