import LanzaderaCore
import Testing
@testable import LanzaderaSystem

/// Scripts que no hablan con ninguna app: no necesitan permisos.
struct OSAScriptRunnerTests {
    let runner = OSAScriptRunner()

    @Test func `convierte listas, textos, números y booleanos`() async throws {
        let value = try await runner.run(#"return {"a", 2, true, {"b"}, missing value}"#)
        #expect(value == .list([.text("a"), .integer(2), .boolean(true), .list([.text("b")]), .none]))
    }

    @Test func `un error en tiempo de ejecución trae su número y mensaje`() async {
        await #expect(throws: ScriptError(code: 42, message: "falló a propósito")) {
            try await runner.run(#"error "falló a propósito" number 42"#)
        }
    }

    @Test func `un script que no compila se informa sin colgar la cola`() async throws {
        await #expect(throws: ScriptError.self) { try await runner.run("esto no es applescript (") }
        #expect(try await runner.run("return 1 + 1") == .integer(2))
    }

    @Test func `el permiso denegado se reconoce por su código`() {
        #expect(ScriptError(code: -1743, message: "").isPermissionDenied)
        #expect(!ScriptError(code: -1728, message: "").isPermissionDenied)
    }
}
