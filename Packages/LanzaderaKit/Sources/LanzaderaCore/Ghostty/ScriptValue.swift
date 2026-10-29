/// Resultado de un AppleScript, ya traducido a tipos de Swift.
///
/// Lo arma `LanzaderaSystem` desde el `NSAppleEventDescriptor`; aquí se interpreta sin AppKit.
public enum ScriptValue: Sendable, Hashable {
    case text(String)
    case integer(Int)
    case boolean(Bool)
    case list([ScriptValue])
    /// `missing value` o un tipo que no interesa.
    case none

    public var text: String? {
        if case .text(let value) = self { value } else { nil }
    }

    public var list: [ScriptValue]? {
        if case .list(let value) = self { value } else { nil }
    }

    /// Lista de textos (por ejemplo, los `id` de ventanas que devuelve la apertura).
    public var texts: [String] {
        switch self {
        case .text(let value): [value]
        case .list(let values): values.compactMap(\.text)
        default: []
        }
    }
}
