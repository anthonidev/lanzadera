import Foundation

/// Lo que se le dice al usuario cuando un proyecto no se pudo abrir, y qué puede hacer.
public struct LaunchProblem: Equatable {
    public enum Action: Equatable {
        case editConfig
        case openAutomationSettings
        case downloadGhostty

        public var title: String {
            switch self {
            case .editConfig: "Abrir en Zed"
            case .openAutomationSettings: "Abrir Ajustes"
            case .downloadGhostty: "Abrir ghostty.org"
            }
        }
    }

    public static let ghosttyWebsite = URL(string: "https://ghostty.org")!

    public let title: String
    public let message: String
    public let action: Action?

    /// `nil` si no hubo problema.
    public init?(_ result: LaunchResult, projectName: String) {
        switch result {
        case .opened, .focused:
            return nil
        case .missingFolders(let folders):
            title = "No se abrió «\(projectName)»"
            message = PanelViewModel.missingMessage(folders) + ". Corrige la ruta en proyectos.yaml."
            action = .editConfig
        case .permissionDenied:
            title = "Lanzadera no tiene permiso para controlar Ghostty"
            message = "Actívalo en Ajustes → Privacidad y seguridad → Automatización → Lanzadera → Ghostty."
            action = .openAutomationSettings
        case .ghosttyMissing:
            title = "Ghostty no está instalado"
            message = "Lanzadera abre los proyectos en Ghostty. Descárgalo de ghostty.org e instálalo en Aplicaciones."
            action = .downloadGhostty
        case .failed(let error):
            title = "No se pudo abrir «\(projectName)» en Ghostty"
            message = error
            action = nil
        }
    }
}
