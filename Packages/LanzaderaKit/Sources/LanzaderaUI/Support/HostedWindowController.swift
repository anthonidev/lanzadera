import AppKit
import LanzaderaConfig
import SwiftUI

/// Ventana con contenido SwiftUI, creada a mano porque la app no tiene ventana principal
/// y las escenas de SwiftUI no se abren de forma fiable desde un panel o un atajo global.
public final class HostedWindowController {
    private let title: String
    private var window: NSWindow?

    public init(title: String) {
        self.title = title
    }

    /// Reemplaza el contenido en cada llamada, para que muestre el estado actual.
    public func show(_ content: some View) {
        if let window {
            window.contentViewController = NSHostingController(rootView: content)
        } else {
            let window = NSWindow(contentViewController: NSHostingController(rootView: content))
            window.title = title
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    public func close() {
        window?.close()
    }
}

/// Ruta del archivo para las vistas (evita importar `LanzaderaConfig` en cada una).
enum LanzaderaConfigFile {
    static var url: URL { ConfigLocation.file }
}
