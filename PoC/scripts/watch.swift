import Foundation
// Vigila la carpeta del archivo (resolviendo el enlace) e imprime el contenido en cada cambio.
let path = CommandLine.arguments[1]
let resolved = URL(filePath: path).resolvingSymlinksInPath()
let dir = resolved.deletingLastPathComponent()
let fd = open(dir.path, O_EVTONLY)
let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
src.setEventHandler {
    let text = (try? String(contentsOf: URL(filePath: path), encoding: .utf8)) ?? "<sin leer>"
    print("evento \(src.data.rawValue): \(text.trimmingCharacters(in: .whitespacesAndNewlines))")
    fflush(stdout)
}
src.resume()
DispatchQueue.main.asyncAfter(deadline: .now() + 3) { exit(0) }
dispatchMain()
