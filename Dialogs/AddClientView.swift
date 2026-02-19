import SwiftUI

// MARK: - Cadastrar Cliente
/// Diálogo para cadastro de um novo cliente.
/// Exige preenchimento de ID e Nome antes de permitir salvar.
struct AddClientView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app.language") private var appLanguageRaw = AppLanguage.pt.rawValue

    /// Campos do formulário.
    @State private var id = ""
    @State private var name = ""
    @State private var tags = ""
    @State private var notes = ""
    private var appLanguage: AppLanguage { .from(appLanguageRaw) }
    private func t(_ pt: String, _ en: String) -> String { I18n.text(pt, en, language: appLanguage) }

    /// Callback executado ao salvar com sucesso.
    let onSave: (_ id: String, _ name: String, _ tags: String, _ notes: String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("Cadastrar Cliente", "Add Client")).font(.title2).bold()

            Form {
                TextField(t("ID (ex: c123 / cliente01)", "ID (e.g. c123 / client01)"), text: $id)
                TextField(t("Nome (ex: Santa Casa)", "Name (e.g. Santa Casa)"), text: $name)
                TextField(t("Tags (opcional)", "Tags (optional)"), text: $tags)
                TextField(t("Observações (opcional)", "Notes (optional)"), text: $notes)
            }

            HStack {
                Button(t("Cancelar", "Cancel")) { dismiss() }
                Spacer()
                Button(t("Salvar", "Save")) {
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
