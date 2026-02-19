import SwiftUI

// MARK: - Editar Cliente
/// Diálogo para edição de um cliente existente.
/// Exibe ID como somente leitura e permite alterar nome, tags e observações.
struct EditClientView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app.language") private var appLanguageRaw = AppLanguage.pt.rawValue

    /// Cliente sendo editado (cópia local mutável).
    @State var item: Client

    /// Callback executado ao salvar com sucesso.
    let onSave: (Client) -> Void

    /// Validação: nome não pode ficar vazio.
    private var isFormValid: Bool {
        !item.name.trimmed.isEmpty
    }
    private var appLanguage: AppLanguage { .from(appLanguageRaw) }
    private func t(_ pt: String, _ en: String) -> String { I18n.text(pt, en, language: appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("Editar Cliente", "Edit Client")).font(.title2).bold()

            Form {
                // ID do cliente — somente leitura
                Text("ID: \(item.id)").foregroundStyle(.secondary)
                TextField(t("Nome", "Name"), text: $item.name)
                TextField(t("Tags", "Tags"), text: $item.tags)
                TextField(t("Observações", "Notes"), text: $item.notes)
            }

            HStack {
                Button(t("Cancelar", "Cancel")) { dismiss() }
                Spacer()
                Button(t("Salvar", "Save")) { onSave(item); dismiss() }
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
