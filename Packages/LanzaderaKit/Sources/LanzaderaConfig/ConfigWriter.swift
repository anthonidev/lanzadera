import Foundation
import LanzaderaCore

/// Escribe proyectos en el formato de `proyectos.yaml`. Se genera el texto a mano (y no con el
/// emisor de Yams) para agregar al final del archivo sin perder los comentarios de lo que ya está.
public enum ConfigWriter {
    /// Archivo que se crea la primera vez, con un ejemplo comentado.
    public static let template = """
        # Lanzadera: mis proyectos. Se recarga solo al guardar.
        #
        # Cada proyecto abre una o varias ventanas de Ghostty con sus pestañas y paneles.
        #
        # projects:
        #   - name: Nexus
        #     emoji: 🔴                 # o color: red | green | blue | magenta | yellow | cyan
        #     root: ~/nexus             # carpeta base: las rutas relativas parten de aquí
        #     icon: nexus-frontend/public/logo.png   # opcional: sin esto se busca el favicon; `none` usa el emoji
        #     tabs:
        #       - title: 🔴 BACKEND
        #         cwd: nexus-backend
        #         panes: 3              # 3 paneles en la misma carpeta
        #         split: right          # right (de lado a lado, por defecto) | down (hacia abajo)
        #         focus: true           # pestaña principal (si no hay, la primera)
        #       - title: 🔴 FRONTEND
        #         cwd: nexus-frontend
        #         panes:                # o una carpeta distinta por panel
        #           - cwd: nexus-frontend
        #           - cwd: ../otra-carpeta
        #       - title: 🔴 GLOBAL       # sin cwd: usa root; sin panes: 1
        #
        # Varias ventanas: en lugar de `tabs:`, usa `windows:` con una lista de `- tabs:`.

        projects:

        """

    /// Agrega proyectos al final del texto actual del archivo.
    public static func appending(_ projects: [ProjectSpec], to text: String) -> String {
        guard !projects.isEmpty else { return text }
        var result = text
        if !result.hasSuffix("\n") { result += "\n" }
        if !hasProjectsKey(result) {
            result += "projects:\n"
        } else if result.range(of: #"(?m)^projects:\s*\[\s*\]\s*$"#, options: .regularExpression) != nil {
            result = result.replacingOccurrences(of: #"(?m)^projects:\s*\[\s*\]\s*$"#, with: "projects:", options: .regularExpression)
        }
        for project in projects {
            result += "\n" + yaml(for: project)
        }
        return result
    }

    /// Reemplaza el bloque del proyecto con ese nombre (sin distinguir mayúsculas) y deja intacto el resto,
    /// comentarios incluidos. Si no existe, lo agrega al final.
    /// - Throws: el error de sintaxis del archivo actual: sin poder leerlo no se sabe dónde está el bloque.
    public static func replacing(
        _ name: String, with project: ProjectSpec, in text: String
    ) throws(ConfigSyntaxError) -> String {
        let specs = try ConfigLoader.specs(from: text)
        guard let index = specs.firstIndex(where: { $0.name?.lowercased() == name.lowercased() }),
              let firstLine = specs[index].line
        else { return appending([project], to: text) }

        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let start = firstLine - 1
        var end = specs.indices.contains(index + 1) ? (specs[index + 1].line ?? lines.count + 1) - 1 : lines.count
        // Las líneas en blanco y los comentarios del final pertenecen al proyecto siguiente.
        while end > start + 1 {
            let line = lines[end - 1].trimmingCharacters(in: .whitespaces)
            guard line.isEmpty || line.hasPrefix("#") else { break }
            end -= 1
        }
        let replacement = yaml(for: project).split(separator: "\n").map(String.init)
        lines.replaceSubrange(start..<end, with: replacement)
        return lines.joined(separator: "\n")
    }

    /// Un proyecto como elemento de la lista `projects`.
    public static func yaml(for project: ProjectSpec) -> String {
        var lines: [String] = []
        lines.append("  - name: \(scalar(project.name ?? ""))")
        if let emoji = project.emoji { lines.append("    emoji: \(scalar(emoji))") }
        if let color = project.color { lines.append("    color: \(scalar(color))") }
        if let root = project.root { lines.append("    root: \(scalar(root))") }
        if let icon = project.icon { lines.append("    icon: \(scalar(icon))") }

        if project.windows.count == 1 {
            lines.append("    tabs:")
            lines += tabLines(project.windows[0].tabs, indent: "      ")
        } else {
            lines.append("    windows:")
            for window in project.windows {
                lines.append("      - tabs:")
                lines += tabLines(window.tabs, indent: "          ")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func tabLines(_ tabs: [TabSpec], indent: String) -> [String] {
        tabs.flatMap { tab -> [String] in
            var lines = ["\(indent)- title: \(scalar(tab.title ?? ""))"]
            let inner = indent + "  "
            if let cwd = tab.cwd { lines.append("\(inner)cwd: \(scalar(cwd))") }
            switch tab.panes {
            case .count(1): break
            case .count(let count): lines.append("\(inner)panes: \(count)")
            case .list(let panes):
                lines.append("\(inner)panes:")
                lines += panes.map { "\(inner)  - cwd: \(scalar($0.cwd ?? "."))" }
            }
            if let split = tab.split { lines.append("\(inner)split: \(split)") }
            if tab.focus { lines.append("\(inner)focus: true") }
            return lines
        }
    }

    /// Texto YAML: sin comillas si se puede leer tal cual, con comillas dobles si no.
    static func scalar(_ text: String) -> String {
        let reserved: Set<String> = ["", "~", "null", "true", "false", "yes", "no", "on", "off", "y", "n"]
        let indicators = Set("-?:,[]{}#&*!|>'\"%@`")
        let needsQuotes = reserved.contains(text.lowercased())
            || text.first.map(indicators.contains) == true
            || text.contains(": ") || text.contains(" #") || text.hasSuffix(":")
            || text.first?.isWhitespace == true || text.last?.isWhitespace == true
            || Double(text) != nil
            || text.contains(where: \.isNewline)
        guard needsQuotes else { return text }
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private static func hasProjectsKey(_ text: String) -> Bool {
        text.range(of: #"(?m)^projects:"#, options: .regularExpression) != nil
    }
}
