import Testing
@testable import LanzaderaCore

struct ProjectIconFinderTests {
    /// Sistema de archivos falso: rutas existentes con su tamaño y subcarpetas por carpeta.
    func finder(files: [String: Int], folders: [String: [String]] = [:]) -> ProjectIconFinder {
        ProjectIconFinder(fileSize: { files[$0] }, subdirectories: { folders[$0] ?? [] })
    }

    func project(_ directories: [String], icon: IconSetting = .automatic) -> Project {
        Project(name: "P", icon: icon, windows: [ProjectWindow(tabs: directories.map {
            ProjectTab(title: $0, panes: [Pane(directory: $0)])
        })])
    }

    @Test func `prefiere el ícono de más calidad aunque esté en otra carpeta`() {
        let finder = finder(files: [
            "/p/api/favicon.ico": 900,
            "/p/front/public/apple-touch-icon.png": 5_000,
        ])
        #expect(finder.icon(for: project(["/p/api", "/p/front"])) == "/p/front/public/apple-touch-icon.png")
    }

    @Test func `ignora el favicon por defecto de Next.js`() {
        let finder = finder(files: [
            "/p/src/app/favicon.ico": ProjectIconFinder.nextDefaultFaviconSize,
            "/p/public/favicon.ico": 4_000,
        ])
        #expect(finder.icon(for: project(["/p"])) == "/p/public/favicon.ico")
        let onlyDefault = self.finder(files: ["/p/src/app/favicon.ico": ProjectIconFinder.nextDefaultFaviconSize])
        #expect(onlyDefault.icon(for: project(["/p"])) == nil)
    }

    @Test func `si no hay en las carpetas del proyecto busca un nivel más abajo, interfaz primero`() {
        let finder = finder(
            files: [
                "/p/scraper/favicon.ico": 100,
                "/p/frontend/public/favicon.svg": 300,
                "/p/node_modules/x/public/apple-touch-icon.png": 1,
            ],
            folders: ["/p": ["scraper", "node_modules", ".git", "frontend"]]
        )
        #expect(finder.icon(for: project(["/p"])) == "/p/frontend/public/favicon.svg")
    }

    @Test func `icon none no busca y una ruta que existe gana a la búsqueda`() {
        let finder = finder(files: ["/p/public/apple-touch-icon.png": 1, "/logo.png": 1])
        #expect(finder.icon(for: project(["/p"], icon: .none)) == nil)
        #expect(finder.icon(for: project(["/p"], icon: .file("/logo.png"))) == "/logo.png")
        // Ruta que no existe: vuelve a la búsqueda automática.
        #expect(finder.icon(for: project(["/p"], icon: .file("/no.png"))) == "/p/public/apple-touch-icon.png")
    }

    @Test func `icon en el archivo se resuelve relativo a root o se desactiva`() throws {
        let resolver = ProjectResolver(homeDirectory: "/Users/yo")
        let tabs = [WindowSpec(tabs: [TabSpec(title: "A")])]
        let spec = ProjectSpec(name: "A", root: "~/a", icon: "web/logo.svg", windows: tabs)
        let relative = try #require(resolver.resolve(spec, position: 1).project)
        #expect(relative.icon == .file("/Users/yo/a/web/logo.svg"))
        let none = try #require(resolver.resolve(ProjectSpec(name: "B", root: "~/b", icon: "none", windows: tabs), position: 1).project)
        #expect(none.icon == .none)
        let auto = try #require(resolver.resolve(ProjectSpec(name: "C", root: "~/c", windows: tabs), position: 1).project)
        #expect(auto.icon == .automatic)
    }
}
