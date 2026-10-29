import Foundation
import LanzaderaConfig
import LanzaderaCore
import LanzaderaSystem
import Observation
import os

/// Revisión de la importación desde Warp: qué proyectos y ventanas se escriben en `proyectos.yaml`.
@Observable
public final class ImportModel {
    public private(set) var candidates: [ImportCandidate] = []
    public private(set) var readErrors: [String] = []
    public var selectedProjects: Set<String> = []
    /// Ventanas elegidas de cada proyecto (índices).
    public var includedWindows: [String: Set<Int>] = [:]
    /// Proyectos que ya están en el archivo: vienen sin marcar y, si se marcan, se **reemplazan**.
    public private(set) var existingNames: Set<String> = []
    public var errorMessage: String?

    @ObservationIgnored private let importer: WarpImporter
    @ObservationIgnored private let file: URL
    @ObservationIgnored private let warpDirectory: URL
    @ObservationIgnored public var onFinish: (_ imported: Int) -> Void = { _ in }
    @ObservationIgnored private let logger = Logger(subsystem: "dev.tonis.lanzadera", category: "import")

    public init(
        file: URL = ConfigLocation.file,
        warpDirectory: URL = WarpConfigReader.defaultDirectory,
        homeDirectory: String = ProjectResolver.currentUserHome
    ) {
        self.file = file
        self.warpDirectory = warpDirectory
        importer = WarpImporter(homeDirectory: homeDirectory) { FolderChecker().exists($0) }
    }

    /// Lee las configuraciones de Warp y propone qué importar.
    public func load(existing: Set<String>) {
        let (configs, errors) = WarpConfigReader.read(directory: warpDirectory)
        candidates = importer.candidates(from: configs)
        readErrors = errors.map(\.description)
        existingNames = Set(existing.map { $0.lowercased() })
        selectedProjects = Set(candidates.map(\.name).filter { !isExisting($0) })
        includedWindows = Dictionary(uniqueKeysWithValues: candidates.map { candidate in
            (candidate.name, Set(candidate.windows.indices.filter { !candidate.windows[$0].suggestedExclusion }))
        })
    }

    public static var hasWarpConfigurations: Bool {
        let path = WarpConfigReader.defaultDirectory.path(percentEncoded: false)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        return files.contains { $0.hasSuffix(".yaml") || $0.hasSuffix(".yml") }
    }

    public func isExisting(_ name: String) -> Bool {
        existingNames.contains(name.lowercased())
    }

    public func isIncluded(_ window: Int, of candidate: ImportCandidate) -> Bool {
        includedWindows[candidate.name, default: []].contains(window)
    }

    public func setIncluded(_ included: Bool, window: Int, of candidate: ImportCandidate) {
        if included {
            includedWindows[candidate.name, default: []].insert(window)
        } else {
            includedWindows[candidate.name, default: []].remove(window)
        }
    }

    /// Proyectos que se escribirán (elegidos y con al menos una ventana), nuevos o para reemplazar.
    public var specsToImport: [ProjectSpec] {
        candidates.compactMap { candidate in
            let windows = includedWindows[candidate.name, default: []]
            guard selectedProjects.contains(candidate.name), !windows.isEmpty else { return nil }
            return importer.spec(for: candidate, including: windows)
        }
    }

    /// Cuántos de los elegidos reemplazan a uno que ya existe.
    public var replacementCount: Int {
        specsToImport.count { isExisting($0.name ?? "") }
    }

    /// Vista previa de lo que se agregará al archivo.
    public func preview(of candidate: ImportCandidate) -> String {
        ConfigWriter.yaml(for: importer.spec(for: candidate, including: includedWindows[candidate.name, default: []]))
    }

    public func importSelected() {
        let specs = specsToImport
        guard !specs.isEmpty else { return }
        do {
            try ConfigLocation.createIfMissing(at: file)
            var text = try String(contentsOf: file, encoding: .utf8)
            for spec in specs where isExisting(spec.name ?? "") {
                text = try ConfigWriter.replacing(spec.name ?? "", with: spec, in: text)
            }
            text = ConfigWriter.appending(specs.filter { !isExisting($0.name ?? "") }, to: text)
            try ConfigLocation.write(text, to: file)
            logger.info("Importados \(specs.count) proyectos desde Warp")
            onFinish(specs.count)
        } catch let error as ConfigSyntaxError {
            errorMessage = "Primero corrige proyectos.yaml: \(error.description)"
        } catch {
            errorMessage = "No se pudo escribir \(file.path(percentEncoded: false)): \(error.localizedDescription)"
        }
    }
}
