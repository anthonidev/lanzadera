import AppKit
import KeyboardShortcuts
import os
import ServiceManagement

extension KeyboardShortcuts.Name {
    /// Abrir o cerrar el panel. ⌥Espacio por defecto.
    public static let togglePanel = Self("togglePanel", initial: .init(.space, modifiers: [.option]))
}

/// ¿Existe esta carpeta?
public protocol FolderChecking {
    func exists(_ path: String) -> Bool
}

nonisolated public struct FolderChecker: FolderChecking, Sendable {
    public init() {}

    nonisolated public func exists(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

/// Iniciar Lanzadera al encender la Mac.
public enum LaunchAtLogin {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

/// Abre archivos en Zed sin depender del comando `zed` en el `PATH`.
public enum Editor {
    public static let zedBundleID = "dev.zed.Zed"
    nonisolated private static let logger = Logger(subsystem: "dev.tonis.lanzadera", category: "editor")

    /// Abre en Zed; si no está instalado, con la app por defecto para el archivo.
    public static func open(_ file: URL) {
        guard let zed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: zedBundleID) else {
            NSWorkspace.shared.open(file)
            return
        }
        NSWorkspace.shared.open([file], withApplicationAt: zed, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                logger.error("No se pudo abrir en Zed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

/// Costado de la pantalla donde aparece el panel.
public enum PanelEdge: String, CaseIterable, Sendable {
    case right, left

    public var label: String {
        switch self {
        case .right: "Derecha"
        case .left: "Izquierda"
        }
    }
}

/// Preferencias simples en UserDefaults.
public enum Preferences {
    private static let defaults = UserDefaults.standard

    public static var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    public static var panelEdge: PanelEdge {
        get { defaults.string(forKey: "panelEdge").flatMap(PanelEdge.init) ?? .right }
        set { defaults.set(newValue.rawValue, forKey: "panelEdge") }
    }
}
