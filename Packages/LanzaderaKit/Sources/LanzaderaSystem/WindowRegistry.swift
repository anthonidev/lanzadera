import Foundation
import os

/// Recuerda qué ventanas de Ghostty abrió cada proyecto (`id` en el orden de sus ventanas).
public protocol WindowRegistering {
    func windowIDs(for project: String) -> [String]
    func setWindowIDs(_ ids: [String], for project: String)
    /// Ventanas registradas a cualquier otro proyecto.
    func windowIDs(excluding project: String) -> Set<String>
}

/// Registro persistido en JSON en Application Support.
public final class WindowRegistry: WindowRegistering {
    private let file: URL
    private var entries: [String: [String]]
    private let logger = Logger(subsystem: "dev.tonis.lanzadera", category: "registry")

    public init(file: URL) {
        self.file = file
        entries = (try? JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: file))) ?? [:]
    }

    public func windowIDs(for project: String) -> [String] {
        entries[project] ?? []
    }

    public func setWindowIDs(_ ids: [String], for project: String) {
        guard entries[project] != ids else { return }
        entries[project] = ids.isEmpty ? nil : ids
        save()
    }

    public func windowIDs(excluding project: String) -> Set<String> {
        Set(entries.filter { $0.key != project }.values.joined())
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: file, options: .atomic)
        } catch {
            logger.error("No se pudo guardar el registro de ventanas: \(error.localizedDescription, privacy: .public)")
        }
    }
}
