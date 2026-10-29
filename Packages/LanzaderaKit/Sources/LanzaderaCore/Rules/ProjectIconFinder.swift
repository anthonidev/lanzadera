/// Busca el ícono de un proyecto entre los archivos que suelen tener los proyectos web
/// (Next.js, Vite, SvelteKit…), del de más calidad al de menos.
///
/// Mira las carpetas del proyecto y, si no encuentra nada, sus subcarpetas directas
/// (por ejemplo `~/dev/chaskyapp/frontend`). No recorre más hondo: son unas decenas de `stat`.
public struct ProjectIconFinder: Sendable {
    /// Tamaño del archivo en bytes, o `nil` si no existe.
    public let fileSize: @Sendable (String) -> Int?
    /// Nombres de las subcarpetas directas.
    public let subdirectories: @Sendable (String) -> [String]

    public init(fileSize: @escaping @Sendable (String) -> Int?, subdirectories: @escaping @Sendable (String) -> [String]) {
        self.fileSize = fileSize
        self.subdirectories = subdirectories
    }

    /// Rutas relativas a cada carpeta, en orden de preferencia: primero las grandes (180 px o vectoriales).
    public static let candidates = [
        "public/apple-touch-icon.png",
        "public/icons/apple-touch-icon.png",
        "public/brand/apple-touch-icon.png",
        "src/app/apple-icon.png",
        "app/apple-icon.png",
        "src/app/icon.png",
        "app/icon.png",
        "public/icon.png",
        "public/favicon.svg",
        "public/icons/icon.svg",
        "src/app/icon.svg",
        "app/icon.svg",
        "static/favicon.png",
        "public/favicon-32x32.png",
        "public/favicon.png",
        "public/favicon.ico",
        "src/app/favicon.ico",
        "app/favicon.ico",
        "static/favicon.ico",
        "favicon.ico",
    ]

    /// El `favicon.ico` que trae `create-next-app` (el triángulo de Vercel): no es el ícono del proyecto.
    static let nextDefaultFaviconSize = 25_931

    /// Subcarpetas que nunca tienen el ícono del proyecto.
    static let ignoredFolders: Set<String> = ["node_modules", "dist", "build", "out", "coverage", "vendor", "tmp", "logs"]

    public func icon(for project: Project) -> String? {
        switch project.icon {
        case .none:
            return nil
        case .file(let path) where fileSize(path) != nil:
            return path
        case .file, .automatic:
            break
        }
        let folders = project.directories
        if let found = firstCandidate(in: folders) { return found }
        let children = folders.flatMap { folder in
            subdirectories(folder)
                .filter { !$0.hasPrefix(".") && !Self.ignoredFolders.contains($0) }
                .sorted(by: Self.preferredFirst)
                .map { folder + "/" + $0 }
        }
        return firstCandidate(in: children)
    }

    /// Recorre por calidad y, dentro de cada calidad, por carpeta: un `apple-touch-icon` en cualquier
    /// carpeta gana a un `favicon.ico` en la primera.
    private func firstCandidate(in folders: [String]) -> String? {
        for candidate in Self.candidates {
            for folder in folders {
                let path = folder + "/" + candidate
                guard let size = fileSize(path) else { continue }
                if candidate.hasSuffix("favicon.ico"), size == Self.nextDefaultFaviconSize { continue }
                return path
            }
        }
        return nil
    }

    /// Las carpetas de interfaz (donde vive el favicon) van primero.
    static func preferredFirst(_ lhs: String, _ rhs: String) -> Bool {
        let hints = ["front", "web", "app", "client", "landing", "site", "ui"]
        let left = hints.contains { lhs.lowercased().contains($0) }
        let right = hints.contains { rhs.lowercased().contains($0) }
        return left == right ? lhs < rhs : left
    }
}
