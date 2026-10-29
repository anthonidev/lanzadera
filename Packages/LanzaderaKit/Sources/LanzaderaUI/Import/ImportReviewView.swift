import LanzaderaCore
import SwiftUI

/// Lista de lo que se importará desde Warp, con avisos y casillas para descartar ventanas.
public struct ImportReviewView: View {
    @Bindable var model: ImportModel
    let onCancel: () -> Void

    public init(model: ImportModel, onCancel: @escaping () -> Void) {
        self.model = model
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Importar desde Warp")
                        .font(.title2.bold())
                    Text("Se agregan a proyectos.yaml (antes se guarda una copia .bak). Después puedes ajustarlos en Zed.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if model.candidates.isEmpty {
                ContentUnavailableView(
                    "No hay configuraciones de Warp",
                    systemImage: "tray",
                    description: Text("Se buscan en ~/.warp/launch_configurations/")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(model.candidates) { candidate in
                            CandidateCard(model: model, candidate: candidate)
                        }
                        ForEach(model.readErrors, id: \.self) { error in
                            Label(error, systemImage: "xmark.octagon").foregroundStyle(.red)
                        }
                    }
                }
            }

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(importTitle) { model.importSelected() }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.specsToImport.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 620, height: 640)
    }

    private var importTitle: String {
        let count = model.specsToImport.count
        let base = count == 1 ? "Importar 1 proyecto" : "Importar \(count) proyectos"
        let replacing = model.replacementCount
        return replacing == 0 ? base : "\(base) (\(replacing) reemplaza\(replacing == 1 ? "" : "n"))"
    }
}

private struct CandidateCard: View {
    @Bindable var model: ImportModel
    let candidate: ImportCandidate
    @State private var showsPreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(isOn: projectBinding) {
                    Text("\(candidate.emoji ?? "▫️") \(candidate.name)").font(.headline)
                }
                Spacer()
                if model.isExisting(candidate.name) {
                    let replacing = model.selectedProjects.contains(candidate.name)
                    Label(
                        replacing ? "Ya está en tu archivo: se reemplazará" : "Ya está en tu archivo: márcalo para reemplazarlo",
                        systemImage: replacing ? "arrow.triangle.2.circlepath" : "checkmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(replacing ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                }
                if !model.isExisting(candidate.name) || model.selectedProjects.contains(candidate.name) {
                    Button(showsPreview ? "Ocultar YAML" : "Ver YAML") { showsPreview.toggle() }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }
            ForEach(Array(candidate.windows.enumerated()), id: \.offset) { index, window in
                windowRow(window, index: index)
            }
            if showsPreview {
                Text(model.preview(of: candidate))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 14))
        .animation(.snappy(duration: 0.2), value: showsPreview)
        .opacity(model.isExisting(candidate.name) && !model.selectedProjects.contains(candidate.name) ? 0.6 : 1)
    }

    private func windowRow(_ window: ImportWindow, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: windowBinding(index)) {
                Text("Ventana \(index + 1): " + window.tabs.map { "\($0.title) (\($0.directories.count))" }.joined(separator: " · "))
                    .font(.callout)
            }
            .disabled(!model.selectedProjects.contains(candidate.name))
            if !window.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(window.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.1), in: .rect(cornerRadius: 8))
                .padding(.leading, 22)
            }
        }
    }

    private var projectBinding: Binding<Bool> {
        Binding(
            get: { model.selectedProjects.contains(candidate.name) },
            set: { selected in
                if selected {
                    model.selectedProjects.insert(candidate.name)
                } else {
                    model.selectedProjects.remove(candidate.name)
                }
            }
        )
    }

    private func windowBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { model.isIncluded(index, of: candidate) },
            set: { model.setIncluded($0, window: index, of: candidate) }
        )
    }
}
