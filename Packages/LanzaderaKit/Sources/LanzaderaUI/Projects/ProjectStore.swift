import Foundation
import LanzaderaConfig
import LanzaderaCore
import LanzaderaSystem
import Observation
import os

/// Los proyectos de `proyectos.yaml`, siempre al día: se recarga solo al guardar el archivo.
///
/// Si el YAML queda ilegible se conserva la última versión válida y se expone el error con su línea.
@Observable
public final class ProjectStore {
    public private(set) var entries: [ProjectEntry] = []
    /// Error del archivo completo (YAML ilegible o archivo inaccesible). Los proyectos mostrados son los anteriores.
    public private(set) var fileError: ConfigSyntaxError?
    /// Sube con cada lectura válida: permite a otros cachear lo que calculan a partir de `entries`.
    public private(set) var revision = 0

    public let file: URL
    @ObservationIgnored private let resolver: ProjectResolver
    @ObservationIgnored private var watcher: ConfigFileWatcher?
    @ObservationIgnored private let logger = Logger(subsystem: "dev.tonis.lanzadera", category: "config")

    public init(file: URL = ConfigLocation.file, homeDirectory: String = ProjectResolver.currentUserHome) {
        self.file = file
        resolver = ProjectResolver(homeDirectory: homeDirectory)
    }

    public var projects: [Project] { entries.compactMap(\.project) }

    public var names: Set<String> { Set(entries.map(\.name)) }

    /// Crea el archivo si falta, lo lee y empieza a vigilarlo.
    public func start() {
        do {
            try ConfigLocation.createIfMissing(at: file)
        } catch {
            logger.error("No se pudo crear \(self.file.path(percentEncoded: false), privacy: .public): \(error)")
        }
        reload()
        let watcher = ConfigFileWatcher(file: file) { [weak self] in self?.reload() }
        watcher.start()
        self.watcher = watcher
    }

    public func reload() {
        let text: String
        do {
            text = try String(contentsOf: file, encoding: .utf8)
        } catch {
            fileError = ConfigSyntaxError("No se pudo leer \(file.path(percentEncoded: false))")
            return
        }
        apply(text)
    }

    /// Interpreta un texto como si fuera el archivo (también lo usan las pruebas).
    public func apply(_ text: String) {
        do {
            entries = try ConfigLoader.load(text, resolver: resolver)
            revision += 1
            fileError = nil
            logger.info("Configuración cargada: \(self.entries.count) proyectos")
        } catch {
            fileError = error
            logger.notice("Error en la configuración: \(error.description, privacy: .public)")
        }
    }
}

extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        count > suffix.count && hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}
