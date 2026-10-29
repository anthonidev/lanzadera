/// Traduce los errores de sintaxis de libyaml (en inglés y técnicos) a qué revisar en el archivo.
/// Los que no se conocen se devuelven tal cual.
enum YAMLErrorTranslator {
    static let indentation = "La sangría no cuadra: alinea esta línea con las de su mismo nivel (con espacios)"
    static let tab = "Hay un tabulador: YAML solo admite espacios para sangrar"

    /// Por prefijo del problema que informa libyaml (sin el contexto entre paréntesis).
    static let translations: [(prefix: String, message: String)] = [
        ("mapping values are not allowed", "Hay un «:» de más o falta sangría. Si el texto lleva «: », ponlo entre comillas"),
        ("found unexpected end of stream", "El archivo termina antes de tiempo: ¿unas comillas sin cerrar?"),
        ("did not find expected ',' or ']'", "Falta cerrar el «[» (o pon el texto entre comillas)"),
        ("did not find expected ',' or '}'", "Falta cerrar la «{» (o pon el texto entre comillas)"),
        ("found unknown escape character", "Dentro de comillas dobles «\\» va doble («\\\\»); o usa comillas simples"),
        ("did not find expected key", indentation),
        ("did not find expected '-' indicator", indentation),
        ("block sequence entries are not allowed", "No se puede empezar una lista («- ») aquí: revisa la sangría"),
        ("could not find expected ':'", "Falta «:» después de la clave"),
        ("found undefined alias", "Un valor que empieza con «*» se lee como alias: ponlo entre comillas"),
        ("found a tab character", tab),
    ]

    /// - Parameter line: el texto de la línea del error, para reconocer tabuladores.
    static func translate(_ problem: String, line: String?) -> String {
        if line?.contains("\t") == true, problem.hasPrefix("found character that cannot start any token") || problem.contains("tab") {
            return tab
        }
        if problem.hasPrefix("found character that cannot start any token") {
            return "Carácter no válido al inicio de un valor: ponlo entre comillas"
        }
        return translations.first { problem.hasPrefix($0.prefix) }?.message ?? problem
    }
}
