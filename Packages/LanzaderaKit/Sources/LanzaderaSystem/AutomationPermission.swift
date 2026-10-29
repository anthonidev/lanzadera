import AppKit
import CoreServices

/// Permiso de Automatización para controlar Ghostty ("Lanzadera quiere controlar Ghostty").
public enum AutomationPermission {
    public enum Status: Sendable, Equatable {
        case granted
        case denied
        /// Nunca se preguntó: el primer AppleScript mostrará la alerta.
        case notDetermined
        /// Ghostty no está abierto: macOS no puede responder.
        case unknown
    }

    /// Estado actual sin mostrar ninguna alerta.
    public static var status: Status {
        check(target: GhosttyController.bundleID, ask: false)
    }

    /// Muestra la alerta del sistema si hace falta (con Ghostty abierto). Bloquea hasta que se responde,
    /// por eso corre fuera del main actor.
    @concurrent
    public static func request() async -> Status {
        check(target: GhosttyController.bundleID, ask: true)
    }

    public static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        if let url, NSWorkspace.shared.open(url) { return }
        if let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(fallback)
        }
    }

    nonisolated private static func check(target bundleID: String, ask: Bool) -> Status {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let desc = target.aeDesc else { return .unknown }
        let result = AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, ask)
        switch Int(result) {
        case Int(noErr): return .granted
        case Int(errAEEventNotPermitted): return .denied
        case Int(errAEEventWouldRequireUserConsent): return .notDetermined
        default: return .unknown
        }
    }
}
