import KeyboardShortcuts
import LanzaderaConfig
import LanzaderaSystem
import SwiftUI

/// Preferencias: atajo, costado del panel, inicio al encender y permiso para controlar Ghostty.
public struct SettingsView: View {
    @State private var edge = Preferences.panelEdge
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var permission = AutomationPermission.status
    @State private var errorMessage: String?
    let onImport: () -> Void

    public init(onImport: @escaping () -> Void) {
        self.onImport = onImport
    }

    public var body: some View {
        Form {
            Section("Panel") {
                KeyboardShortcuts.Recorder("Atajo para abrir el panel:", name: .togglePanel)
                Picker("Aparece a la", selection: $edge) {
                    ForEach(PanelEdge.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .onChange(of: edge) { Preferences.panelEdge = edge }
            }
            Section("Proyectos") {
                LabeledContent("Archivo") {
                    Text(ConfigLocation.file.path(percentEncoded: false).replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Abrir en Zed") { Editor.open(ConfigLocation.file) }
                    Button("Mostrar en Finder") { NSWorkspace.shared.activateFileViewerSelecting([ConfigLocation.file]) }
                    Button("Importar desde Warp…", action: onImport)
                }
            }
            Section("Sistema") {
                Toggle("Iniciar al encender la Mac", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { setLaunchAtLogin(launchAtLogin) }
                LabeledContent("Controlar Ghostty") {
                    PermissionStatusView(status: permission)
                }
                HStack {
                    Button("Pedir permiso") {
                        Task { permission = await GhosttyPermissionFlow.request() }
                    }
                    .disabled(permission == .granted)
                    Button("Abrir Ajustes de Automatización") { AutomationPermission.openSettings() }
                }
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permission = AutomationPermission.status
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            errorMessage = nil
        } catch {
            errorMessage = "No se pudo cambiar el inicio al encender: \(error.localizedDescription)"
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}

struct PermissionStatusView: View {
    let status: AutomationPermission.Status

    var body: some View {
        switch status {
        case .granted:
            Label("Concedido", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .denied:
            Label("Denegado", systemImage: "xmark.circle.fill").foregroundStyle(.red)
        case .notDetermined:
            Label("Sin pedir todavía", systemImage: "questionmark.circle").foregroundStyle(.orange)
        case .unknown:
            Label("Abre Ghostty para comprobarlo", systemImage: "questionmark.circle").foregroundStyle(.secondary)
        }
    }
}

/// Pedir el permiso necesita a Ghostty abierto: si no lo está, se abre (sin ventanas nuevas) y se espera.
public enum GhosttyPermissionFlow {
    public static func request() async -> AutomationPermission.Status {
        if NSRunningApplication.runningApplications(withBundleIdentifier: GhosttyController.bundleID).isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: GhosttyController.bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            try? await Task.sleep(for: .seconds(1))
        }
        return await AutomationPermission.request()
    }
}
