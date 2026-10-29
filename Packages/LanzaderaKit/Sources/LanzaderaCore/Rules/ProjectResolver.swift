import Foundation

/// Convierte lo escrito en el archivo (`ProjectSpec`) en proyectos listos para abrir.
///
/// Los errores de un proyecto no afectan a los demás: cada uno queda como `.invalid` con sus motivos.
public struct ProjectResolver: Sendable {
    /// Carpeta personal, para expandir `~`. Se inyecta para poder probar.
    public let homeDirectory: String

    /// Límite razonable de paneles por pestaña: más allá no se leen.
    public static let maxPanes = 12

    /// Carpeta personal del usuario actual, sin barra final.
    public static var currentUserHome: String {
        URL.homeDirectory.path(percentEncoded: false).trimmingTrailingSlash
    }

    public init(homeDirectory: String) {
        self.homeDirectory = homeDirectory
    }

    public func resolve(_ specs: [ProjectSpec]) -> [ProjectEntry] {
        var seenNames = Set<String>()
        return specs.enumerated().map { index, spec in
            var entry = resolve(spec, position: index + 1)
            let key = entry.name.lowercased()
            if !seenNames.insert(key).inserted {
                let issue = ConfigIssue("Ya hay otro proyecto llamado «\(entry.name)»", line: spec.line)
                entry = .invalid(name: entry.name, issues: [issue] + entry.issues)
            }
            return entry
        }
    }

    public func resolve(_ spec: ProjectSpec, position: Int) -> ProjectEntry {
        var issues = spec.issues
        let name = spec.name?.trimmingCharacters(in: .whitespaces) ?? ""
        if name.isEmpty {
            issues.append(ConfigIssue("El proyecto no tiene nombre (`name`)", line: spec.line))
        }

        let marker = marker(of: spec, issues: &issues)

        var root: String?
        if let rawRoot = spec.root {
            root = absolutePath(rawRoot, relativeTo: nil)
            if root == nil {
                issues.append(ConfigIssue("`root` debe ser una ruta absoluta o empezar con ~: «\(rawRoot)»", line: spec.line))
            }
        }

        let icon = icon(of: spec, root: root, issues: &issues)

        if spec.windows.isEmpty {
            issues.append(ConfigIssue("El proyecto no tiene pestañas (`tabs`)", line: spec.line))
        }
        let windows = spec.windows.map { resolve($0, root: root, issues: &issues) }

        let displayName = name.isEmpty ? "Proyecto \(position)" : name
        guard issues.isEmpty else { return .invalid(name: displayName, issues: issues) }
        return .valid(Project(name: name, marker: marker, icon: icon, windows: windows))
    }

    private func marker(of spec: ProjectSpec, issues: inout [ConfigIssue]) -> ProjectMarker? {
        if let emoji = spec.emoji?.trimmingCharacters(in: .whitespaces), !emoji.isEmpty {
            return .emoji(emoji)
        }
        guard let color = spec.color else { return nil }
        if let parsed = MarkerColor(rawValue: color.lowercased()) { return .color(parsed) }
        let options = MarkerColor.allCases.map(\.rawValue).joined(separator: ", ")
        issues.append(ConfigIssue("Color desconocido «\(color)». Opciones: \(options)", line: spec.line))
        return nil
    }

    /// Sin `icon`: automático. `none`: sin ícono. Una ruta que no existe no es un error: vuelve a lo automático.
    private func icon(of spec: ProjectSpec, root: String?, issues: inout [ConfigIssue]) -> IconSetting {
        guard let raw = spec.icon?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return .automatic }
        if ["none", "no", "false"].contains(raw.lowercased()) { return .none }
        if let path = absolutePath(raw, relativeTo: root) { return .file(path) }
        issues.append(ConfigIssue("`icon` es relativo pero el proyecto no tiene `root`: «\(raw)»", line: spec.line))
        return .automatic
    }

    private func resolve(_ spec: WindowSpec, root: String?, issues: inout [ConfigIssue]) -> ProjectWindow {
        if spec.tabs.isEmpty {
            issues.append(ConfigIssue("La ventana no tiene pestañas", line: spec.line))
        }
        if spec.tabs.count(where: \.focus) > 1 {
            issues.append(ConfigIssue("Hay más de una pestaña con `focus: true` en la misma ventana", line: spec.line))
        }
        return ProjectWindow(tabs: spec.tabs.map { resolve($0, root: root, issues: &issues) })
    }

    private func resolve(_ spec: TabSpec, root: String?, issues: inout [ConfigIssue]) -> ProjectTab {
        let title = spec.title?.trimmingCharacters(in: .whitespaces) ?? ""
        if title.isEmpty {
            issues.append(ConfigIssue("La pestaña no tiene título (`title`)", line: spec.line))
        }

        var split = SplitDirection.right
        if let rawSplit = spec.split {
            if let parsed = SplitDirection(rawValue: rawSplit.lowercased()) {
                split = parsed
            } else {
                issues.append(ConfigIssue("`split` debe ser `right` o `down`, no «\(rawSplit)»", line: spec.line))
            }
        }

        let tabDirectory = directory(spec.cwd, root: root, line: spec.line, issues: &issues)
        var panes: [Pane] = []
        switch spec.panes {
        case .count(let count):
            if (1...Self.maxPanes).contains(count) {
                panes = Array(repeating: Pane(directory: tabDirectory ?? ""), count: count)
            } else {
                issues.append(ConfigIssue("`panes` debe estar entre 1 y \(Self.maxPanes), no \(count)", line: spec.line))
            }
        case .list(let list):
            if list.isEmpty || list.count > Self.maxPanes {
                issues.append(ConfigIssue("La lista `panes` debe tener entre 1 y \(Self.maxPanes) paneles", line: spec.line))
            }
            panes = list.map { pane in
                guard let cwd = pane.cwd else { return Pane(directory: tabDirectory ?? "") }
                let path = directory(cwd, root: root, line: pane.line ?? spec.line, issues: &issues)
                return Pane(directory: path ?? "")
            }
        }
        return ProjectTab(title: title, split: split, panes: panes, isFocused: spec.focus)
    }

    /// Carpeta de una pestaña o panel: absoluta, con `~`, o relativa a `root`.
    private func directory(_ cwd: String?, root: String?, line: Int?, issues: inout [ConfigIssue]) -> String? {
        guard let cwd else {
            if root == nil {
                issues.append(ConfigIssue("Falta la carpeta: agrega `cwd` a la pestaña o `root` al proyecto", line: line))
            }
            return root
        }
        guard let path = absolutePath(cwd, relativeTo: root) else {
            issues.append(ConfigIssue("La carpeta «\(cwd)» es relativa pero el proyecto no tiene `root`", line: line))
            return nil
        }
        return path
    }

    /// Expande `~` y resuelve rutas relativas a `base`. `nil` si queda relativa.
    func absolutePath(_ raw: String, relativeTo base: String?) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let expanded: String
        if trimmed == "~" {
            expanded = homeDirectory
        } else if trimmed.hasPrefix("~/") {
            expanded = homeDirectory + trimmed.dropFirst(1)
        } else if trimmed.hasPrefix("/") {
            expanded = trimmed
        } else if let base, !trimmed.isEmpty {
            expanded = base + "/" + trimmed
        } else {
            return nil
        }
        return URL(filePath: expanded).standardized.path(percentEncoded: false).trimmingTrailingSlash
    }
}

extension String {
    /// `/a/b/` → `/a/b`, sin tocar la raíz `/`.
    var trimmingTrailingSlash: String {
        count > 1 && hasSuffix("/") ? String(dropLast()) : self
    }
}
