import SwiftUI

// MARK: - Cadastrar Cliente
/// Diálogo para cadastro de um novo cliente.
/// Exige preenchimento de ID e Nome antes de permitir salvar.
struct AddClientView: View {
    @Environment(\.dismiss) private var dismiss

    /// Campos do formulário.
    @State private var id = ""
    @State private var name = ""
    @State private var tags = ""
    @State private var notes = ""

    /// Callback executado ao salvar com sucesso.
    let onSave: (_ id: String, _ name: String, _ tags: String, _ notes: String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cadastrar Cliente").font(.title2).bold()

            Form {
                TextField("ID (ex: c123 / cliente01)", text: $id)
                TextField("Nome (ex: Santa Casa)", text: $name)
                TextField("Tags (opcional)", text: $tags)
                TextField("Observações (opcional)", text: $notes)
            }

            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Salvar") {
                    onSave(id.trimmed, name.trimmed, tags.trimmed, notes.trimmed)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(id.trimmed.isEmpty || name.trimmed.isEmpty)
            }
        }
        .padding()
        .preferredColorScheme(.dark)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
