import Foundation
import LanzaderaCore
import OSAKit
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
public protocol ScriptRunning: Sendable {
    func run(_ source: String) async throws(ScriptError) -> ScriptValue
}

/// Ejecuta AppleScript **fuera del hilo principal**.
///
/// `NSAppleScript` solo se puede usar en el hilo principal y lo bloqueaba mientras Ghostty armaba
/// las ventanas (~0,5 s). OSAKit, con su propia instancia del lenguaje usada siempre desde la misma
/// cola serie, no tiene esa limitación. La cola también ordena los scripts: nunca corren dos a la vez.
///
/// Guarda los scripts compilados: el primero cuesta ~40 ms (carga el componente de AppleScript) y los
/// siguientes ~2–4 ms; con la caché, repetir una consulta o un proyecto no compila nada.
nonisolated public final class OSAScriptRunner: ScriptRunning, @unchecked Sendable {
    // Todo lo mutable vive confinado a `queue`: por eso `@unchecked Sendable`.
    private let queue = DispatchQueue(label: "dev.tonis.lanzadera.applescript", qos: .userInitiated)
    private var instance: OSALanguageInstance?
    private var compiled: [String: OSAScript] = [:]
    private static let cacheLimit = 32
    private let logger = Logger(subsystem: "dev.tonis.lanzadera", category: "applescript")

    public init() {}

    /// Compila por adelantado (por ejemplo, la consulta de estado al arrancar la app).
    public func prepare(_ source: String) {
        queue.async { _ = try? self.script(for: source) }
    }

    public func run(_ source: String) async throws(ScriptError) -> ScriptValue {
        let result: Result<ScriptValue, ScriptError> = await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: Result { () throws(ScriptError) in try self.execute(source) })
            }
        }
        return try result.get()
    }

    // MARK: - En la cola

    private func execute(_ source: String) throws(ScriptError) -> ScriptValue {
        let start = ContinuousClock.now
        let script = try script(for: source)
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        let elapsed = ContinuousClock.now - start
        logger.debug("AppleScript en \(elapsed.formatted(.units(allowed: [.milliseconds])), privacy: .public)")
        if let error = Self.error(from: errorInfo) {
            logger.error("AppleScript falló (\(error.code)): \(error.message, privacy: .public)")
            throw error
        }
        return result.map(Self.value) ?? .none
    }

    private func script(for source: String) throws(ScriptError) -> OSAScript {
        if let cached = compiled[source] { return cached }
        let script = OSAScript(source: source, from: nil, languageInstance: languageInstance(), using: [])
        var errorInfo: NSDictionary?
        guard script.compileAndReturnError(&errorInfo) else {
            throw Self.error(from: errorInfo) ?? ScriptError(code: -1, message: "No se pudo compilar el AppleScript")
        }
        if compiled.count >= Self.cacheLimit { compiled.removeAll() }
        compiled[source] = script
        return script
    }

    private func languageInstance() -> OSALanguageInstance? {
        if instance == nil, let language = OSALanguage(forName: "AppleScript") {
            instance = OSALanguageInstance(language: language)
        }
        return instance
    }

    // MARK: - Conversión

    private static func error(from info: NSDictionary?) -> ScriptError? {
        guard let info else { return nil }
        let code = info[OSAScriptErrorNumberKey] as? Int ?? info[NSAppleScript.errorNumber] as? Int ?? -1
        let message = info[OSAScriptErrorMessageKey] as? String ?? info[NSAppleScript.errorMessage] as? String ?? "Error desconocido"
        return ScriptError(code: code, message: message)
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
