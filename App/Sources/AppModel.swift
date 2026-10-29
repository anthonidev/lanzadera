import AppKit
import KeyboardShortcuts
import LanzaderaConfig
import LanzaderaCore
import LanzaderaSystem
import LanzaderaUI
import Observation
import os

/// Raíz de composición: crea todas las piezas y las conecta.
@Observable
final class AppModel {
    let store: ProjectStore
    let panelController: PanelController
    private(set) var launchAtLogin = LaunchAtLogin.isEnabled

    @ObservationIgnored private let launcher: ProjectLauncher
    @ObservationIgnored private let onboarding = HostedWindowController(title: "Bienvenida")
    @ObservationIgnored private let settingsWindow = HostedWindowController(title: "Preferencias de Lanzadera")
    @ObservationIgnored private let importWindow = HostedWindowController(title: "Importar desde Warp")
    @ObservationIgnored private let logger = Logger(subsystem: "dev.tonis.lanzadera", category: "app")

    init() {
        store = ProjectStore()
        let registry = WindowRegistry(file: Self.supportDirectory.appending(path: "ventanas.json"))
        launcher = ProjectLauncher(ghostty: GhosttyController(), registry: registry, folders: FolderChecker())
        let panelModel = PanelViewModel(store: store, launcher: launcher)
        panelController = PanelController(model: panelModel)

        // Al abrir un proyecto el panel desaparece de inmediato: Ghostty pasa al frente sin esperar la animación.
        panelModel.onClose = { [weak self] in self?.panelController.hide(animated: false) }
        panelModel.onOpenConfig = { [weak self] in self?.openConfigFile() }
        panelModel.onOpenSettings = { [weak self] in self?.showSettings() }
        panelModel.onImport = { [weak self] in self?.showImport() }
        panelModel.onLaunchProblem = { [weak self] result, project in self?.report(result, for: project) }
    }

    /// Debug y Release guardan el registro de ventanas por separado.
    static var supportDirectory: URL {
        #if DEBUG
        let folder = "Lanzadera-Debug"
        #else
        let folder = "Lanzadera"
        #endif
        return URL.applicationSupportDirectory.appending(path: folder, directoryHint: .isDirectory)
    }

    func start() {
        store.start()
        panelController.model.refreshIcons()
        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
            self?.panelController.toggle()
        }
        if !Preferences.hasCompletedOnboarding {
            showOnboarding()
        }
        #if DEBUG
        // `open Lanzadera.app --args --panel` (o --settings, --onboarding, --import): abre esa
        // ventana al arrancar, para revisarla sin teclado.
        let arguments = CommandLine.arguments
        if arguments.contains("--panel") { panelController.show() }
        if arguments.contains("--settings") { showSettings() }
        if arguments.contains("--onboarding") { showOnboarding() }
        if arguments.contains("--import") { showImport() }
        #endif
    }

    // MARK: - Acciones

    func togglePanel() {
        panelController.toggle()
    }

    /// Abrir desde el menú de la barra.
    func launch(_ project: Project) {
        Task {
            let result = await launcher.launch(project)
            report(result, for: project)
        }
    }

    func openConfigFile() {
        panelController.hide()
        Editor.open(store.file)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
        } catch {
            logger.error("Inicio al encender: \(error.localizedDescription, privacy: .public)")
        }
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    // MARK: - Ventanas

    func showOnboarding() {
        onboarding.show(OnboardingView(
            store: store,
            hasWarpConfigurations: ImportModel.hasWarpConfigurations,
            onImport: { [weak self] in self?.showImport() },
            onDone: { [weak self] in
                Preferences.hasCompletedOnboarding = true
                self?.onboarding.close()
            }
        ))
    }

    func showSettings() {
        panelController.hide()
        settingsWindow.show(SettingsView(store: store, onImport: { [weak self] in self?.showImport() }))
    }

    func showImport() {
        panelController.hide()
        let model = ImportModel()
        model.load(existing: store.names)
        model.onFinish = { [weak self] count in
            self?.importWindow.close()
            self?.store.reload()
            self?.confirmImport(count)
        }
        importWindow.show(ImportReviewView(model: model) { [weak self] in self?.importWindow.close() })
    }

    // MARK: - Avisos

    private func confirmImport(_ count: Int) {
        let alert = NSAlert()
        alert.messageText = count == 1 ? "Se importó 1 proyecto" : "Se importaron \(count) proyectos"
        alert.informativeText = "Revísalos en proyectos.yaml: puedes cambiar emojis, títulos o la pestaña principal."
        alert.addButton(withTitle: "Abrir en Zed")
        alert.addButton(withTitle: "Listo")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            Editor.open(store.file)
        }
    }

    private func report(_ result: LaunchResult, for project: Project) {
        guard let problem = LaunchProblem(result, projectName: project.name) else { return }
        let alert = NSAlert()
        alert.messageText = problem.title
        alert.informativeText = problem.message
        if let action = problem.action { alert.addButton(withTitle: action.title) }
        alert.addButton(withTitle: "Cerrar")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn, let action = problem.action else { return }
        switch action {
        case .editConfig: Editor.open(store.file)
        case .openAutomationSettings: AutomationPermission.openSettings()
        case .downloadGhostty: NSWorkspace.shared.open(LaunchProblem.ghosttyWebsite)
        }
    }
}
