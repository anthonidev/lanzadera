/// Genera los AppleScript que controlan Ghostty 1.4. Es el único lugar que escribe AppleScript,
/// así un cambio en el diccionario de Ghostty se arregla aquí y las pruebas guardan el texto esperado.
public enum GhosttyScript {
    /// `id` de las ventanas y `id` y nombre de sus pestañas, pedidos **en bloque**: tres Apple Events en total
    /// (~14 ms cada uno) en vez de uno por propiedad. Con 3 ventanas: ~41 ms frente a ~390 ms del bucle.
    /// Sin ventanas, pedir sus pestañas falla (-1728): se devuelve vacío. Sin `count windows`: un evento menos.
    /// Con tiempo límite: si Ghostty no responde, el panel no se queda congelado (el valor por defecto son 2 minutos).
    public static let snapshot = """
        with timeout of 3 seconds
            tell application "Ghostty"
                try
                    return {id of every window, id of every tab of every window, name of every tab of every window}
                on error number -1728
                    return {}
                end try
            end tell
        end timeout
        """

    /// Abre todas las ventanas del proyecto y devuelve la lista de sus `id`, en el orden del proyecto.
    public static func open(_ project: Project) -> String {
        var lines = ["tell application \"Ghostty\""]
        lines.append(contentsOf: configurationLines(for: project.directories))
        let configName = Dictionary(uniqueKeysWithValues: project.directories.enumerated().map { ($1, "cfg\($0 + 1)") })

        for (windowIndex, window) in project.windows.enumerated() {
            let w = "w\(windowIndex + 1)"
            lines.append("-- Ventana \(windowIndex + 1)")
            for (tabIndex, tab) in window.tabs.enumerated() {
                let t = "t\(windowIndex + 1)_\(tabIndex + 1)"
                let firstConfig = configName[tab.panes[0].directory] ?? "cfg1"
                if tabIndex == 0 {
                    lines.append("set \(w) to new window with configuration \(firstConfig)")
                    if windowIndex == 0 {
                        // Ghostty pasa al frente apenas existe la ventana: se ve armarse en vez de esperar ~0,5 s.
                        lines.append("activate")
                    }
                    lines.append("set \(t) to selected tab of \(w)")
                } else {
                    lines.append("set \(t) to new tab in \(w) with configuration \(firstConfig)")
                }
                lines.append("set name override of \(t) to \(quote(tab.title))")
                lines.append("set \(t)_p1 to focused terminal of \(t)")
                for paneIndex in tab.panes.indices.dropFirst() {
                    let config = configName[tab.panes[paneIndex].directory] ?? "cfg1"
                    let split = "split \(t)_p\(paneIndex) direction \(tab.split.rawValue) with configuration \(config)"
                    lines.append("set \(t)_p\(paneIndex + 1) to \(split)")
                }
                if tab.panes.count > 2 {
                    lines.append("perform action \"equalize_splits\" on \(t)_p1")
                }
            }
            let focused = "t\(windowIndex + 1)_\(window.focusedTabIndex + 1)"
            lines.append("select tab \(focused)")
        }

        // La ventana principal se enfoca al final para que quede al frente.
        let main = project.mainWindowIndex
        let mainTab = "t\(main + 1)_\(project.windows[main].focusedTabIndex + 1)"
        lines.append("focus \(mainTab)_p1")
        lines.append("activate")
        let ids = project.windows.indices.map { "id of w\($0 + 1)" }.joined(separator: ", ")
        lines.append("return {\(ids)}")
        lines.append("end tell")
        return indent(lines)
    }

    /// Trae al frente ventanas ya abiertas. La principal va al final y, si se conoce, se selecciona su pestaña.
    public static func activate(windowIDs: [String], mainWindowID: String, mainTabID: String?) -> String {
        var lines = ["tell application \"Ghostty\""]
        for id in windowIDs where id != mainWindowID {
            lines.append("activate window (window id \(quote(id)))")
        }
        lines.append("set w to window id \(quote(mainWindowID))")
        if let mainTabID {
            lines.append("select tab (tab id \(quote(mainTabID)) of w)")
        }
        lines.append("activate window w")
        lines.append("activate")
        lines.append("end tell")
        return indent(lines)
    }

    /// Consulta inofensiva para que macOS pida el permiso de Automatización.
    public static let permissionProbe = "tell application \"Ghostty\" to count windows"

    /// Literal de texto de AppleScript. Rutas y títulos pasan siempre por aquí.
    public static func quote(_ text: String) -> String {
        var escaped = ""
        for character in text {
            switch character {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            default: escaped.append(character)
            }
        }
        return "\"\(escaped)\""
    }

    private static func configurationLines(for directories: [String]) -> [String] {
        directories.enumerated().flatMap { index, directory in
            [
                "set cfg\(index + 1) to new surface configuration",
                "set initial working directory of cfg\(index + 1) to \(quote(directory))",
            ]
        }
    }

    /// Sangra todo lo que está entre `tell` y `end tell`.
    private static func indent(_ lines: [String]) -> String {
        lines.enumerated().map { index, line in
            index == 0 || index == lines.count - 1 ? line : "    " + line
        }.joined(separator: "\n")
    }
}
