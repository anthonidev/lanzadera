import LanzaderaCore
import LanzaderaSystem
import SwiftUI

/// Contenido del panel lateral: búsqueda, lista de proyectos y pie con Configurar.
public struct PanelView: View {
    @Bindable var model: PanelViewModel
    @FocusState private var isSearchFocused: Bool
    /// Las filas entran escalonadas en cada apertura.
    @State private var rowsVisible = false
    @Namespace private var selectionNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: PanelViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            banners
            list
            footer
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .onChange(of: model.presentationID, initial: true) {
            isSearchFocused = true
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { rowsVisible = false }
            Task { rowsVisible = true }
        }
    }

    // MARK: - Búsqueda

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)
            TextField("Buscar proyecto", text: $model.query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isSearchFocused)
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Borrar búsqueda")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.5), in: .capsule)
        .animation(.snappy(duration: 0.15), value: model.query.isEmpty)
    }

    // MARK: - Avisos

    private var banners: some View {
        VStack(spacing: 8) {
            if let error = model.store.fileError {
                Banner(systemImage: "exclamationmark.triangle.fill", tint: .orange, text: error.description) {
                    Button("Abrir en Zed") { model.onOpenConfig() }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let notice = model.notice {
                Banner(systemImage: "folder.badge.questionmark", tint: .red, text: notice) {
                    Button("Cerrar") { model.notice = nil }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.2), value: model.notice)
        .animation(.snappy(duration: 0.2), value: model.store.fileError)
    }

    // MARK: - Lista

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    // Por posición: un nombre repetido (error del archivo) no debe romper la lista.
                    ForEach(Array(model.items.enumerated()), id: \.offset) { index, entry in
                        row(entry, index: index)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.never)
            .scrollContentBackground(.hidden)
            .overlay {
                if model.items.isEmpty { emptyState.transition(.opacity) }
            }
            .animation(.snappy(duration: 0.18), value: model.selection)
            .animation(.snappy(duration: 0.2), value: model.query)
            .onChange(of: model.selection) {
                withAnimation(.snappy(duration: 0.15)) { proxy.scrollTo(model.selection) }
            }
        }
    }

    private func row(_ entry: ProjectEntry, index: Int) -> some View {
        let isSelected = index == model.selection
        return ProjectRow(
            entry: entry,
            icon: model.icons[entry.name],
            position: index < 9 ? index + 1 : nil,
            isSelected: isSelected,
            isOpen: model.openNames.contains(entry.name),
            missingFolders: model.missingFolders[entry.name] ?? [],
            showsNewWindowHint: model.isOptionHeld && isSelected
        )
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.tint.opacity(0.22))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.tint.opacity(0.35)))
                    .matchedGeometryEffect(id: "selection", in: selectionNamespace)
            }
        }
        .id(index)
        .contentShape(.rect(cornerRadius: 14))
        .onContinuousHover { phase in
            if case .active = phase { model.hover(index, mouseLocation: NSEvent.mouseLocation) }
        }
        .onTapGesture {
            model.selection = index
            model.open(entry, forceNew: NSEvent.modifierFlags.contains(.option))
        }
        // Entrada escalonada: cada fila un poco después de la anterior (solo las primeras, el resto junto).
        .opacity(rowsVisible ? 1 : 0)
        .offset(x: rowsVisible || reduceMotion ? 0 : 14)
        .animation(.smooth(duration: 0.28).delay(Double(min(index, 8)) * 0.025), value: rowsVisible)
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.store.entries.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.tint)
                    .symbolEffect(.bounce, value: model.presentationID)
                Text("Todavía no hay proyectos")
                    .font(.headline)
                Text("Impórtalos desde Warp o escríbelos en el archivo de configuración.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Importar desde Warp…") { model.onImport() }
                    .buttonStyle(.glassProminent)
                Button("Editar el archivo") { model.onOpenConfig() }
                    .buttonStyle(.link)
            }
            .padding()
        } else {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("Nada con «\(model.query)»")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Pie

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                model.onOpenConfig()
            } label: {
                Label("Configurar", systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Abrir proyectos.yaml en Zed")
            Spacer()
            HStack(spacing: 8) {
                KeyHint(keys: "↩", label: model.isOptionHeld ? "nueva ventana" : "abrir")
                if !model.isOptionHeld {
                    KeyHint(keys: "⌥↩", label: "nueva")
                }
            }
            .animation(.snappy(duration: 0.15), value: model.isOptionHeld)
            Button {
                model.onClose()
                model.onOpenSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
            .help("Preferencias de Lanzadera (⌘,)")
            .accessibilityLabel("Preferencias")
        }
        .font(.callout)
        .padding(.horizontal, 6)
    }
}

/// Una fila de la lista: marca, nombre, resumen e indicadores.
struct ProjectRow: View {
    let entry: ProjectEntry
    let icon: ProjectIcon?
    let position: Int?
    let isSelected: Bool
    let isOpen: Bool
    let missingFolders: [String]
    let showsNewWindowHint: Bool

    var body: some View {
        HStack(spacing: 12) {
            ProjectTile(name: entry.name, marker: entry.project?.marker, icon: icon, isInvalid: entry.project == nil)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    if isOpen {
                        OpenDot()
                    }
                    Text(subtitle)
                        .lineLimit(2)
                }
                .font(.caption)
                .foregroundStyle(subtitleStyle)
            }
            Spacer(minLength: 4)
            trailing
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .opacity(entry.project == nil ? 0.6 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var trailing: some View {
        if showsNewWindowHint {
            Label("Nueva", systemImage: "plus.rectangle.on.rectangle")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tint)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
        } else if let position {
            Keycap("⌘\(position)")
                .opacity(isSelected ? 1 : 0.45)
        }
    }

    private var subtitle: String {
        if let issue = entry.issues.first { return issue.description }
        guard let project = entry.project else { return "" }
        if !missingFolders.isEmpty { return PanelViewModel.missingMessage(missingFolders) }
        let summary = ProjectSummary.text(for: project)
        return isOpen ? "Abierto · \(summary)" : summary
    }

    private var subtitleStyle: AnyShapeStyle {
        entry.project == nil || !missingFolders.isEmpty ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary)
    }

    private var accessibilityText: String {
        var parts = [entry.name, subtitle]
        if let position { parts.append("comando \(position)") }
        return parts.joined(separator: ", ")
    }
}

/// Cuadro de la izquierda de cada fila, por orden de preferencia: el ícono del proyecto (favicon),
/// su emoji o color y, si no tiene nada, su inicial.
struct ProjectTile: View {
    let name: String
    let marker: ProjectMarker?
    let icon: ProjectIcon?
    let isInvalid: Bool

    static let side: CGFloat = 36
    static let radius: CGFloat = 10

    var body: some View {
        ZStack {
            if let icon, icon.isOpaque {
                // Con fondo propio (apple-touch-icon): ocupa todo el cuadro.
                Image(decorative: icon.image, scale: 1)
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: Self.radius)
                    .fill(tint.opacity(0.16))
                content
            }
        }
        .frame(width: Self.side, height: Self.side)
        .clipShape(.rect(cornerRadius: Self.radius))
        .overlay(RoundedRectangle(cornerRadius: Self.radius).strokeBorder(.white.opacity(0.08)))
        .animation(.smooth(duration: 0.25), value: icon?.path)
    }

    @ViewBuilder
    private var content: some View {
        if isInvalid {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        } else if let icon {
            Image(decorative: icon.image, scale: 1)
                .resizable()
                .interpolation(.high)
                .padding(6)
                .transition(.opacity)
        } else {
            switch marker {
            case .emoji(let emoji):
                Text(emoji).font(.title3)
            case .color(let color):
                Circle().fill(color.color.gradient).frame(width: 14, height: 14)
            case nil:
                Text(name.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var tint: Color {
        switch marker {
        case .color(let color): color.color
        case .emoji(let emoji): Self.emojiTints[emoji] ?? .secondary
        case nil: isInvalid ? .orange : .secondary
        }
    }

    /// Los círculos de color (los que usa el importador de Warp) tiñen el fondo con su color.
    private static let emojiTints: [String: Color] = Dictionary(
        uniqueKeysWithValues: MarkerColor.allCases.map { ($0.emoji, $0.color) } + [("🟠", .orange), ("🟤", .brown)]
    )
}

/// Punto verde que "respira" una vez al aparecer: el proyecto ya está abierto en Ghostty.
struct OpenDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(.green)
            .frame(width: 7, height: 7)
            .background(Circle().fill(.green.opacity(0.35)).scaleEffect(pulse ? 2.2 : 1).opacity(pulse ? 0 : 1))
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) { pulse = true }
            }
            .accessibilityHidden(true)
    }
}

/// Tecla dibujada como en el teclado.
struct Keycap: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium).monospaced())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 5))
            .accessibilityHidden(true)
    }
}

/// "↩ abrir" en el pie.
struct KeyHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Keycap(keys)
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .contentTransition(.opacity)
        }
    }
}

/// Aviso a lo ancho del panel con una acción.
struct Banner<Action: View>: View {
    let systemImage: String
    let tint: Color
    let text: String
    @ViewBuilder let action: Action

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            action
                .controlSize(.small)
        }
        .padding(10)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 12))
    }
}

extension MarkerColor {
    var color: Color {
        switch self {
        case .red: .red
        case .green: .green
        case .blue: .blue
        case .magenta: .purple
        case .yellow: .yellow
        case .cyan: .cyan
        case .black: .black
        case .white: .white
        }
    }
}
