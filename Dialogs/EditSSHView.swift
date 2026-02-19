import SwiftUI

// MARK: - Editar SSH
/// Diálogo para edição de um acesso SSH existente.
/// Valida que alias, nome, host e usuário não fiquem vazios antes de permitir salvar.
struct EditSSHView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app.language") private var appLanguageRaw = AppLanguage.pt.rawValue

    /// Servidor SSH sendo editado (cópia local mutável).
    @State var item: SSHServer

    /// Callback executado ao salvar com sucesso.
    let onSave: (SSHServer) -> Void

    /// Porta como texto para permitir digitação livre.
    @State private var portText: String
    private var appLanguage: AppLanguage { .from(appLanguageRaw) }
    private func t(_ pt: String, _ en: String) -> String { I18n.text(pt, en, language: appLanguage) }

    init(item: SSHServer, onSave: @escaping (SSHServer) -> Void) {
        self._item = State(initialValue: item)
        self.onSave = onSave
        self._portText = State(initialValue: "\(item.port)")
    }

    /// Validação: alias, nome, host e usuário obrigatórios.
    private var isFormValid: Bool {
        !item.alias.trimmed.isEmpty &&
        !item.name.trimmed.isEmpty &&
        !item.host.trimmed.isEmpty &&
        !item.user.trimmed.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("Editar SSH", "Edit SSH")).font(.title2).bold()

            Form {
                TextField(t("Alias", "Alias"), text: $item.alias)
                // ClientId — somente leitura
                Text("\(t("Cliente", "Client")): \(item.clientId)").foregroundStyle(.secondary)

                TextField(t("Nome", "Name"), text: $item.name)
                TextField(t("Host/IP", "Host/IP"), text: $item.host)
                TextField(t("Porta", "Port"), text: $portText)
                TextField(t("Usuário", "User"), text: $item.user)
                TextField(t("Tags", "Tags"), text: $item.tags)

                // Observações — campo multi-linha
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("Observações", "Notes"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $item.notes)
                        .frame(minHeight: 90)
                }
            }

            HStack {
                Button(t("Cancelar", "Cancel")) { dismiss() }
                Spacer()
                Button(t("Salvar", "Save")) {
                    item.port = Int(portText.trimmed) ?? item.port
                    onSave(item)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
            }
        }
        .padding()
        .frame(minWidth: 760, minHeight: 520)
        .preferredColorScheme(.dark)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
