/// Resumen corto bajo el nombre del proyecto: "3 pestañas · 6 paneles".
public enum ProjectSummary {
    public static func text(for project: Project) -> String {
        let tabs = project.windows.flatMap(\.tabs)
        let panes = tabs.reduce(0) { $0 + $1.panes.count }
        var parts: [String] = []
        if project.windows.count > 1 {
            parts.append(count(project.windows.count, "ventana", "ventanas"))
        }
        parts.append(count(tabs.count, "pestaña", "pestañas"))
        parts.append(count(panes, "panel", "paneles"))
        return parts.joined(separator: " · ")
    }

    private static func count(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }
}
