import KeyboardShortcuts
import LanzaderaSystem
import SwiftUI

/// Primer uso: permiso para controlar Ghostty → importar Warp → ⌥Espacio.
public struct OnboardingView: View {
    @State private var permission = AutomationPermission.status
    @State private var isRequesting = false
    let hasWarpConfigurations: Bool
    let onImport: () -> Void
    let onDone: () -> Void

    public init(hasWarpConfigurations: Bool, onImport: @escaping () -> Void, onDone: @escaping () -> Void) {
        self.hasWarpConfigurations = hasWarpConfigurations
        self.onImport = onImport
        self.onDone = onDone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Text("🚀").font(.system(size: 44))
                VStack(alignment: .leading) {
                    Text("Bienvenido a Lanzadera").font(.title.bold())
                    Text("Un clic y tu proyecto está listo en Ghostty.").foregroundStyle(.secondary)
                }
            }

            step(1, title: "Permitir que Lanzadera controle Ghostty") {
                Text("macOS te preguntará una vez. Sin este permiso Lanzadera no puede abrir ventanas.")
                HStack {
                    PermissionStatusView(status: permission)
                    Spacer()
                    if permission == .denied {
                        Button("Abrir Ajustes") { AutomationPermission.openSettings() }
                    } else if permission != .granted {
                        Button(isRequesting ? "Esperando…" : "Dar permiso") {
                            isRequesting = true
                            Task {
                                permission = await GhosttyPermissionFlow.request()
                                isRequesting = false
                            }
                        }
                        .disabled(isRequesting)
                    }
                }
            }

            step(2, title: "Traer tus proyectos") {
                if hasWarpConfigurations {
                    Text("Encontré configuraciones de Warp. Puedes revisarlas antes de importarlas.")
                    Button("Importar desde Warp…", action: onImport)
                } else {
                    Text("Escribe tus proyectos en ~/.config/lanzadera/proyectos.yaml (tiene un ejemplo comentado).")
                    Button("Abrir el archivo en Zed") { Editor.open(LanzaderaConfigFile.url) }
                }
            }

            step(3, title: "Listo") {
                HStack(spacing: 4) {
                    Text("Usa")
                    Text(KeyboardShortcuts.getShortcut(for: .togglePanel)?.description ?? "⌥Space").bold()
                    Text("o el ícono 🚀 de la barra de menú y elige un proyecto.")
                }
            }

            HStack {
                Spacer()
                Button("Empezar", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permission = AutomationPermission.status
        }
    }

    private func step(_ number: Int, title: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 26, height: 26)
                .background(.tint.opacity(0.2), in: .circle)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                content()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
