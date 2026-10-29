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
            Text("Importar desde Warp")
                .font(.title2.bold())
            Text("Se agregan al final de proyectos.yaml (antes se guarda una copia .bak). Después puedes ajustarlos en Zed.")
                .foregroundStyle(.secondary)

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
                Button("Importar \(model.specsToImport.count) proyectos") { model.importSelected() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.specsToImport.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 620, height: 640)
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
                .disabled(model.isExisting(candidate.name))
                Spacer()
                if model.isExisting(candidate.name) {
                    Text("Ya está en tu archivo: se omite")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
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
        .padding(12)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 12))
        .opacity(model.isExisting(candidate.name) ? 0.6 : 1)
    }

    private func windowRow(_ window: ImportWindow, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: windowBinding(index)) {
                Text("Ventana \(index + 1): " + window.tabs.map { "\($0.title) (\($0.directories.count))" }.joined(separator: " · "))
                    .font(.callout)
            }
            .disabled(!model.selectedProjects.contains(candidate.name))
            ForEach(window.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
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
