import AppKit
import LanzaderaCore

/// Todo lo que Lanzadera le pide a Ghostty.
public protocol GhosttyControlling {
    /// Sin lanzar Ghostty: mira si está corriendo.
    var isRunning: Bool { get }
    /// Ya hay permiso para controlarlo: consultar no mostrará la alerta de macOS.
    var isAuthorized: Bool { get }
    /// Ventanas abiertas. Vacío si Ghostty no está corriendo (no lo abre para consultar).
    func windows() throws(ScriptError) -> [GhosttyWindow]
    /// Abre el proyecto y devuelve los `id` de sus ventanas, en orden.
    func open(_ project: Project) throws(ScriptError) -> [String]
    /// Trae al frente un proyecto ya abierto.
    func activate(_ match: ProjectMatch) throws(ScriptError)
}

public final class GhosttyController: GhosttyControlling {
    nonisolated public static let bundleID = "com.mitchellh.ghostty"
    private let runner: any ScriptRunning
    /// Una vez concedido no se vuelve a preguntar a macOS en cada apertura del panel;
    /// se olvida si un script falla por permiso.
    private var knownAuthorized = false

    public init(runner: any ScriptRunning = AppleScriptRunner()) {
        self.runner = runner
        (runner as? AppleScriptRunner)?.prepare(GhosttyScript.snapshot)
    }

    public var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    public var isAuthorized: Bool {
        if !knownAuthorized { knownAuthorized = AutomationPermission.status == .granted }
        return knownAuthorized
    }

    public static var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    public func windows() throws(ScriptError) -> [GhosttyWindow] {
        guard isRunning else { return [] }
        return GhosttySnapshot.parse(try run(GhosttyScript.snapshot))
    }

    public func open(_ project: Project) throws(ScriptError) -> [String] {
        try run(GhosttyScript.open(project)).texts
    }

    public func activate(_ match: ProjectMatch) throws(ScriptError) {
        _ = try run(GhosttyScript.activate(windowIDs: match.windowIDs, mainWindowID: match.mainWindowID, mainTabID: match.mainTabID))
    }

    private func run(_ source: String) throws(ScriptError) -> ScriptValue {
        do {
            let value = try runner.run(source)
            knownAuthorized = true
            return value
        } catch {
            if error.isPermissionDenied { knownAuthorized = false }
            throw error
        }
    }
}
