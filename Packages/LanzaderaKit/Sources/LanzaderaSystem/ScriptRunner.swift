import Foundation
import LanzaderaCore
import os

/// Un AppleScript que falló, con el código de error de Apple Events.
public struct ScriptError: Error, Sendable, Hashable, CustomStringConvertible {
    public var code: Int
    public var message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    /// El usuario no dio (o quitó) el permiso para controlar Ghostty.
    public var isPermissionDenied: Bool { code == -1743 || code == -1744 }

    public var description: String { "\(message) (\(code))" }
}

/// Ejecuta un AppleScript y devuelve su resultado.
public protocol ScriptRunning {
    func run(_ source: String) throws(ScriptError) -> ScriptValue
}

/// La única pieza que usa `NSAppleScript`. No es seguro entre hilos: vive en el main actor.
///
/// Guarda los scripts ya compilados: el primero cuesta ~45 ms (carga el componente de AppleScript)
/// y los siguientes ~2–4 ms; con la caché, repetir una consulta o un proyecto no compila nada.
public final class AppleScriptRunner: ScriptRunning {
    private var compiled: [String: NSAppleScript] = [:]
    private static let cacheLimit = 32
    private let logger = Logger(subsystem: "dev.tonis.lanzadera", category: "applescript")

    public init() {}

    /// Compila por adelantado (por ejemplo, la consulta de estado al arrancar la app).
    public func prepare(_ source: String) {
        _ = try? script(for: source)
    }

    public func run(_ source: String) throws(ScriptError) -> ScriptValue {
        let start = ContinuousClock.now
        let script = try script(for: source)
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        let elapsed = ContinuousClock.now - start
        logger.debug("AppleScript en \(elapsed.formatted(.units(allowed: [.milliseconds])), privacy: .public)")
        if let errorInfo {
            let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? -1
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Error desconocido"
            logger.error("AppleScript falló (\(code)): \(message, privacy: .public)")
            throw ScriptError(code: code, message: message)
        }
        return Self.value(from: result)
    }

    private func script(for source: String) throws(ScriptError) -> NSAppleScript {
        if let cached = compiled[source] { return cached }
        guard let script = NSAppleScript(source: source) else {
            throw ScriptError(code: -1, message: "No se pudo preparar el AppleScript")
        }
        var errorInfo: NSDictionary?
        guard script.compileAndReturnError(&errorInfo) else {
            let message = errorInfo?[NSAppleScript.errorMessage] as? String ?? "No se pudo compilar el AppleScript"
            throw ScriptError(code: errorInfo?[NSAppleScript.errorNumber] as? Int ?? -1, message: message)
        }
        if compiled.count >= Self.cacheLimit { compiled.removeAll() }
        compiled[source] = script
        return script
    }

    /// `missing value` ('msng'); Swift no importa la constante `cMissingValue`.
    private static let missingValue: DescType = 0x6D73_6E67

    static func value(from descriptor: NSAppleEventDescriptor) -> ScriptValue {
        switch descriptor.descriptorType {
        case typeAEList:
            guard descriptor.numberOfItems > 0 else { return .list([]) }
            return .list((1...descriptor.numberOfItems).compactMap { descriptor.atIndex($0) }.map(value))
        case typeTrue, typeFalse, typeBoolean:
            return .boolean(descriptor.booleanValue)
        case typeSInt16, typeSInt32, typeSInt64, typeUInt32:
            return .integer(Int(descriptor.int32Value))
        case typeType where descriptor.typeCodeValue == missingValue, typeNull:
            return .none
        default:
            return descriptor.stringValue.map(ScriptValue.text) ?? .none
        }
    }
}
