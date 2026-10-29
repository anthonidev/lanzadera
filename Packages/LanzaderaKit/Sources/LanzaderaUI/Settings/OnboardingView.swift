import KeyboardShortcuts
import LanzaderaSystem
import SwiftUI

/// Primer uso: permiso para controlar Ghostty → traer los proyectos → ⌥Espacio.
/// Cada paso se marca solo al cumplirse (el permiso al volver de Ajustes, los proyectos al importar).
public struct OnboardingView: View {
    let store: ProjectStore
    let hasWarpConfigurations: Bool
    let onImport: () -> Void
    let onDone: () -> Void

    @State private var permission = AutomationPermission.status
    @State private var isRequesting = false

    public init(store: ProjectStore, hasWarpConfigurations: Bool, onImport: @escaping () -> Void, onDone: @escaping () -> Void) {
        self.store = store
        self.hasWarpConfigurations = hasWarpConfigurations
        self.onImport = onImport
        self.onDone = onDone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            VStack(alignment: .leading, spacing: 18) {
                OnboardingStep(number: 1, title: "Permitir que Lanzadera controle Ghostty", isDone: permission == .granted) {
                    permissionStep
                }
                OnboardingStep(number: 2, title: "Traer tus proyectos", isDone: !store.entries.isEmpty) {
                    projectsStep
                }
                OnboardingStep(number: 3, title: "Abrir un proyecto", isDone: false) {
                    HStack(spacing: 6) {
                        Text("Pulsa")
                        Keycap(shortcutText)
                        Text("o el ícono de la barra de menú, y elige uno.")
                    }
                }
            }
            HStack {
                Spacer()
                Button("Empezar", action: onDone)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 540)
        .animation(.snappy, value: permission)
        .animation(.snappy, value: store.entries.isEmpty)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permission = AutomationPermission.status
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text("Bienvenido a Lanzadera").font(.title.bold())
                Text("Un atajo y tu proyecto está listo en Ghostty.").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var permissionStep: some View {
        Text("macOS te preguntará una vez. Sin este permiso Lanzadera no puede abrir ventanas.")
        HStack {
            PermissionStatusView(status: permission)
            Spacer()
            if permission == .denied {
                Button("Abrir Ajustes") { AutomationPermission.openSettings() }
                    .buttonStyle(.glass)
            } else if permission != .granted {
                Button {
                    isRequesting = true
                    Task {
                        permission = await GhosttyPermissionFlow.request()
                        isRequesting = false
                    }
                } label: {
                    if isRequesting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Dar permiso")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isRequesting)
            }
        }
    }

    @ViewBuilder
    private var projectsStep: some View {
        if !store.entries.isEmpty {
            Text(store.entries.count == 1 ? "Tienes 1 proyecto." : "Tienes \(store.entries.count) proyectos.")
            Button("Editar en Zed") { Editor.open(store.file) }
                .buttonStyle(.glass)
        } else if hasWarpConfigurations {
            Text("Encontré configuraciones de Warp. Puedes revisarlas antes de importarlas.")
            Button("Importar desde Warp…", action: onImport)
                .buttonStyle(.glassProminent)
        } else {
            Text("Escríbelos en ~/.config/lanzadera/proyectos.yaml (tiene un ejemplo comentado).")
            Button("Abrir el archivo en Zed") { Editor.open(store.file) }
                .buttonStyle(.glass)
        }
    }

    private var shortcutText: String {
        KeyboardShortcuts.getShortcut(for: .togglePanel)?.description ?? "⌥Espacio"
    }
}

/// Un paso numerado que pasa a ✓ al cumplirse.
struct OnboardingStep<Content: View>: View {
    let number: Int
    let title: String
    let isDone: Bool
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(isDone ? AnyShapeStyle(.green.gradient) : AnyShapeStyle(.tint.opacity(0.18)))
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("\(number)").font(.headline)
                }
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isDone ? .secondary : .primary)
                content
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.quaternary.opacity(isDone ? 0.2 : 0.4), in: .rect(cornerRadius: 16))
    }
}
