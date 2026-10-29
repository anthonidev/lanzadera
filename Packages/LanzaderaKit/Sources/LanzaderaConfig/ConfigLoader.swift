import LanzaderaCore
import Yams

/// El YAML no se puede leer: no hay proyectos que salvar, se conserva la última versión válida.
public struct ConfigSyntaxError: Error, Sendable, Hashable, CustomStringConvertible {
    public var message: String
    public var line: Int?
    public var column: Int?

    public init(_ message: String, line: Int? = nil, column: Int? = nil) {
        self.message = message
        self.line = line
        self.column = column
    }

    public var description: String {
        guard let line else { return message }
        return "Error en la línea \(line): \(message)"
    }
}

/// Lee `proyectos.yaml`. Recorre los nodos de Yams (en vez de `Decodable`) para conocer la línea
/// de cada cosa y para que un proyecto mal escrito no impida leer los demás.
public enum ConfigLoader {
    public static func load(_ text: String, resolver: ProjectResolver) throws(ConfigSyntaxError) -> [ProjectEntry] {
        resolver.resolve(try specs(from: text))
    }

    public static func specs(from text: String) throws(ConfigSyntaxError) -> [ProjectSpec] {
        let root: Node?
        do {
            root = try Yams.compose(yaml: text)
        } catch let error as YamlError {
            throw syntaxError(from: error, text: text)
        } catch {
            throw ConfigSyntaxError(String(describing: error))
        }
        guard let root else { return [] }
        guard case .mapping(let mapping) = root else {
            throw ConfigSyntaxError("El archivo debe empezar con `projects:`", line: root.mark?.line)
        }
        guard let projects = mapping["projects"], !isNull(projects) else { return [] }
        guard case .sequence(let sequence) = projects else {
            throw ConfigSyntaxError("`projects` debe ser una lista (cada proyecto empieza con `- name:`)", line: projects.mark?.line)
        }
        return sequence.map(projectSpec)
    }

    // MARK: - Nodos

    private static let projectKeys: Set<String> = ["name", "emoji", "color", "root", "icon", "windows", "tabs"]
    private static let tabKeys: Set<String> = ["title", "cwd", "panes", "split", "focus"]

    private static func projectSpec(_ node: Node) -> ProjectSpec {
        var spec = ProjectSpec(line: node.mark?.line)
        guard case .mapping(let mapping) = node else {
            spec.issues.append(ConfigIssue("Cada proyecto debe tener `name:` y sus pestañas", line: spec.line))
            return spec
        }
        spec.issues += unknownKeys(in: mapping, allowed: projectKeys)
        spec.name = mapping["name"]?.string
        spec.emoji = mapping["emoji"]?.string
        spec.color = mapping["color"]?.string
        spec.root = mapping["root"]?.string
        spec.icon = mapping["icon"]?.string

        switch (mapping["windows"], mapping["tabs"]) {
        case (.some, .some):
            spec.issues.append(ConfigIssue("Usa `windows` o `tabs`, no los dos", line: spec.line))
        case (.some(let windows), nil):
            guard case .sequence(let list) = windows else {
                spec.issues.append(ConfigIssue("`windows` debe ser una lista", line: windows.mark?.line))
                break
            }
            spec.windows = list.map { windowSpec($0, issues: &spec.issues) }
        case (nil, .some(let tabs)):
            spec.windows = [WindowSpec(tabs: tabSpecs(tabs, issues: &spec.issues), line: tabs.mark?.line)]
        case (nil, nil):
            break
        }
        return spec
    }

    private static func windowSpec(_ node: Node, issues: inout [ConfigIssue]) -> WindowSpec {
        guard case .mapping(let mapping) = node, let tabs = mapping["tabs"] else {
            issues.append(ConfigIssue("Cada ventana debe tener `tabs:`", line: node.mark?.line))
            return WindowSpec(tabs: [], line: node.mark?.line)
        }
        issues += unknownKeys(in: mapping, allowed: ["tabs"])
        return WindowSpec(tabs: tabSpecs(tabs, issues: &issues), line: node.mark?.line)
    }

    private static func tabSpecs(_ node: Node, issues: inout [ConfigIssue]) -> [TabSpec] {
        guard case .sequence(let list) = node else {
            issues.append(ConfigIssue("`tabs` debe ser una lista (cada pestaña empieza con `- title:`)", line: node.mark?.line))
            return []
        }
        return list.map { tabSpec($0, issues: &issues) }
    }

    private static func tabSpec(_ node: Node, issues: inout [ConfigIssue]) -> TabSpec {
        let line = node.mark?.line
        guard case .mapping(let mapping) = node else {
            issues.append(ConfigIssue("Cada pestaña debe tener al menos `title:`", line: line))
            return TabSpec(line: line)
        }
        issues += unknownKeys(in: mapping, allowed: tabKeys)
        var spec = TabSpec(
            title: mapping["title"]?.string,
            cwd: mapping["cwd"]?.string,
            split: mapping["split"]?.string,
            line: line
        )
        if let focus = mapping["focus"] {
            if let value = focus.bool {
                spec.focus = value
            } else {
                issues.append(ConfigIssue("`focus` debe ser `true` o `false`", line: focus.mark?.line))
            }
        }
        if let panes = mapping["panes"] {
            spec.panes = panesSpec(panes, issues: &issues)
        }
        return spec
    }

    private static func panesSpec(_ node: Node, issues: inout [ConfigIssue]) -> PanesSpec {
        switch node {
        case .scalar:
            if let count = node.int { return .count(count) }
            issues.append(ConfigIssue("`panes` debe ser un número o una lista de paneles", line: node.mark?.line))
        case .sequence(let list):
            return .list(list.map { pane in
                switch pane {
                case .scalar:
                    // Atajo: `- carpeta` equivale a `- cwd: carpeta`.
                    return PaneSpec(cwd: pane.string, line: pane.mark?.line)
                case .mapping(let mapping):
                    issues += unknownKeys(in: mapping, allowed: ["cwd"])
                    return PaneSpec(cwd: mapping["cwd"]?.string, line: pane.mark?.line)
                default:
                    issues.append(ConfigIssue("Panel no válido", line: pane.mark?.line))
                    return PaneSpec(line: pane.mark?.line)
                }
            })
        default:
            issues.append(ConfigIssue("`panes` debe ser un número o una lista de paneles", line: node.mark?.line))
        }
        return .count(1)
    }

    private static func unknownKeys(in mapping: Node.Mapping, allowed: Set<String>) -> [ConfigIssue] {
        mapping.keys.compactMap { key in
            guard let name = key.string, !allowed.contains(name) else { return nil }
            let options = allowed.sorted().map { "`\($0)`" }.joined(separator: ", ")
            return ConfigIssue("Clave desconocida «\(name)». Se esperaba \(options)", line: key.mark?.line)
        }
    }

    private static func isNull(_ node: Node) -> Bool {
        node.null != nil
    }

    private static func syntaxError(from error: YamlError, text: String) -> ConfigSyntaxError {
        switch error {
        case .scanner(_, let problem, let mark, _),
             .parser(_, let problem, let mark, _),
             .composer(_, let problem, let mark, _):
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            let line = lines.indices.contains(mark.line - 1) ? String(lines[mark.line - 1]) : nil
            let message = YAMLErrorTranslator.translate(problem, line: line)
            return ConfigSyntaxError(message, line: mark.line, column: mark.column)
        default:
            return ConfigSyntaxError(error.description)
        }
    }
}
