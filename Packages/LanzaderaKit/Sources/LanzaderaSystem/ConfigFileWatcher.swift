import Foundation
import os

/// Avisa cuando cambia `proyectos.yaml`.
///
/// Zed guarda reemplazando el archivo (escritura atómica), así que se vigila la **carpeta**; además
/// se vigila el propio archivo por si otro editor escribe encima. Si es un enlace simbólico (por
/// ejemplo a `zed-config`), se vigila también la carpeta del destino. Los avisos se agrupan (~200 ms).
public final class ConfigFileWatcher {
    private let file: URL
    private let onChange: () -> Void
    private var sources: [any DispatchSourceFileSystemObject] = []
    private var fileSource: (any DispatchSourceFileSystemObject)?
    private var pending: Task<Void, Never>?
    private let logger = Logger(subsystem: "dev.tonis.lanzadera", category: "watcher")

    public init(file: URL, onChange: @escaping () -> Void) {
        self.file = file
        self.onChange = onChange
    }

    public func start() {
        stop()
        let target = file.resolvingSymlinksInPath()
        var folders = [file.deletingLastPathComponent()]
        if target.deletingLastPathComponent() != folders[0] {
            folders.append(target.deletingLastPathComponent())
        }
        sources = folders.compactMap { watch($0, events: [.write, .rename, .delete, .link]) }
        armFileSource()
        logger.info("Vigilando \(folders.map { $0.path(percentEncoded: false) }, privacy: .public)")
    }

    public func stop() {
        sources.forEach { $0.cancel() }
        sources = []
        fileSource?.cancel()
        fileSource = nil
        pending?.cancel()
    }

    /// El archivo cambia de inodo en cada guardado atómico: se vuelve a abrir tras cada aviso.
    private func armFileSource() {
        fileSource?.cancel()
        fileSource = watch(file.resolvingSymlinksInPath(), events: [.write, .extend, .rename, .delete])
    }

    private func watch(_ url: URL, events: DispatchSource.FileSystemEvent) -> (any DispatchSourceFileSystemObject)? {
        let descriptor = open(url.path(percentEncoded: false), O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: events, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.scheduleChange() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        return source
    }

    private func scheduleChange() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self else { return }
            self.armFileSource()
            self.onChange()
        }
    }
}
