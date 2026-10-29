import KeyboardShortcuts
import LanzaderaConfig
import LanzaderaSystem
import SwiftUI

/// Preferencias: atajo, costado del panel, archivo de proyectos, inicio al encender y permiso para controlar Ghostty.
public struct SettingsView: View {
    let store: ProjectStore
    let onImport: () -> Void

    @State private var edge = Preferences.panelEdge
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var permission = AutomationPermission.status
    @State private var errorMessage: String?

    public init(store: ProjectStore, onImport: @escaping () -> Void) {
        self.store = store
        self.onImport = onImport
    }

    public var body: some View {
        Form {
            Section {
                header
            }
            Section {
                LabeledContent {
                    KeyboardShortcuts.Recorder(for: .togglePanel)
                } label: {
                    Label("Atajo", systemImage: "keyboard")
                }
                Picker(selection: $edge) {
                    ForEach(PanelEdge.allCases, id: \.self) { Text($0.label).tag($0) }
                } label: {
                    Label("Aparece a la", systemImage: "sidebar.right")
                }
                .pickerStyle(.segmented)
                .onChange(of: edge) { Preferences.panelEdge = edge }
            } header: {
                Text("Panel")
            }
            Section {
                LabeledContent {
                    statusOfFile
                } label: {
                    Label(displayPath, systemImage: "doc.text")
                        .textSelection(.enabled)
                }
                HStack {
                    Button("Abrir en Zed") { Editor.open(store.file) }
                    Button("Mostrar en Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.file]) }
                    Spacer()
                    Button("Importar desde Warp…", action: onImport)
                }
            } header: {
                Text("Proyectos")
            }
            Section {
                Toggle(isOn: $launchAtLogin) {
                    Label("Iniciar al encender la Mac", systemImage: "power")
                }
                .onChange(of: launchAtLogin) { setLaunchAtLogin(launchAtLogin) }
                LabeledContent {
                    HStack(spacing: 10) {
                        PermissionStatusView(status: permission)
                        if permission == .denied {
                            Button("Abrir Ajustes") { AutomationPermission.openSettings() }
                        } else if permission != .granted {
                            Button("Pedir permiso") {
                                Task { permission = await GhosttyPermissionFlow.request() }
                            }
                        }
                    }
                } label: {
                    Label("Controlar Ghostty", systemImage: "terminal")
                }
            } header: {
                Text("Sistema")
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permission = AutomationPermission.status
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Lanzadera").font(.title3.bold())
                Text("Versión \(Self.version)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Cuántos proyectos hay o el error del archivo.
    @ViewBuilder
    private var statusOfFile: some View {
        if let error = store.fileError {
            Label("Línea \(error.line.map(String.init) ?? "?")", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help(error.description)
        } else {
            Text(store.entries.count == 1 ? "1 proyecto" : "\(store.entries.count) proyectos")
                .foregroundStyle(.secondary)
        }
    }

    private var displayPath: String {
        store.file.path(percentEncoded: false).replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
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
