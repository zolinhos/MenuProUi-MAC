import SwiftUI

// MARK: - Editar Cliente
/// Diálogo para edição de um cliente existente.
/// Exibe ID como somente leitura e permite alterar nome, tags e observações.
struct EditClientView: View {
    @Environment(\.dismiss) private var dismiss

    /// Cliente sendo editado (cópia local mutável).
    @State var item: Client

    /// Callback executado ao salvar com sucesso.
    let onSave: (Client) -> Void

    /// Validação: nome não pode ficar vazio.
    private var isFormValid: Bool {
        !item.name.trimmed.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Editar Cliente").font(.title2).bold()

            Form {
                // ID do cliente — somente leitura
                Text("ID: \(item.id)").foregroundStyle(.secondary)
                TextField("Nome", text: $item.name)
                TextField("Tags", text: $item.tags)
                TextField("Observações", text: $item.notes)
            }

            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Salvar") { onSave(item); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 300)
        .preferredColorScheme(.dark)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
