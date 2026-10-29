import AppKit
import LanzaderaCore
import LanzaderaSystem
import SwiftUI

@main
struct LanzaderaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            if let model = appDelegate.model {
                MenuBarContent(model: model)
            }
        } label: {
            Image(systemName: "airplane.departure")
                .accessibilityLabel("Lanzadera")
        }
    }
}

/// Arranca la app una vez que AppKit está listo.
@Observable
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel()
        self.model = model
        model.start()
    }
}

/// Menú de la barra superior. Los proyectos también se pueden abrir desde aquí.
struct MenuBarContent: View {
    let model: AppModel

    var body: some View {
        Button("Abrir el panel") { model.togglePanel() }
        Divider()
        if let error = model.store.fileError {
            Text("⚠️ \(error.description)")
        }
        ForEach(Array(model.store.entries.enumerated()), id: \.offset) { _, entry in
            Button {
                if let project = entry.project { model.launch(project) }
            } label: {
                if let icon = model.panelController.model.icons[entry.name] {
                    // En los menús la imagen se muestra a su tamaño: 16 pt.
                    Label {
                        Text(entry.name)
                    } icon: {
                        Image(nsImage: NSImage(cgImage: icon.image, size: NSSize(width: 16, height: 16)))
                    }
                } else {
                    Text(title(for: entry))
                }
            }
            .disabled(entry.project == nil)
        }
        if model.store.entries.isEmpty {
            Text("Sin proyectos todavía")
        }
        Divider()
        Button("Configurar…") { model.openConfigFile() }
        Button("Importar desde Warp…") { model.showImport() }
        Toggle("Iniciar al encender la Mac", isOn: Binding(
            get: { model.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        ))
        Divider()
        Button("Preferencias…") { model.showSettings() }
            .keyboardShortcut(",")
        Button("Bienvenida…") { model.showOnboarding() }
        Divider()
        Button("Salir de Lanzadera") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func title(for entry: ProjectEntry) -> String {
        switch entry.project?.marker {
        case .emoji(let emoji): "\(emoji) \(entry.name)"
        case .color(let color): "\(color.emoji) \(entry.name)"
        case nil: entry.project == nil ? "⚠️ \(entry.name) (con errores)" : entry.name
        }
    }
}
