import SwiftUI

// MARK: - Payload de criação SSH
/// Dados coletados pelo formulário e enviados ao CSVStore para persistência.
struct AddSSHPayload {
    var alias: String
    var clientId: String
    var name: String
    var host: String
    var port: Int
    var user: String
    var tags: String
    var notes: String
}

// MARK: - Cadastrar SSH
/// Diálogo para cadastro de um novo acesso SSH.
/// Exige preenchimento de alias, nome, host e usuário.
struct AddSSHView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app.language") private var appLanguageRaw = AppLanguage.pt.rawValue

    let clients: [Client]
    /// Cliente pré-selecionado na lista lateral (já preenchido no dropdown).
    let preselected: Client?
    let onSave: (AddSSHPayload) -> Void

    @State private var alias = ""
    @State private var clientId = ""
    @State private var name = ""
    @State private var host = ""
    @State private var portText = "22"     // ✅ digitável
    @State private var user = ""
    @State private var tags = ""
    @State private var notes = ""
    private var appLanguage: AppLanguage { .from(appLanguageRaw) }
    private func t(_ pt: String, _ en: String) -> String { I18n.text(pt, en, language: appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("Cadastrar SSH", "Add SSH")).font(.title2).bold()

            Form {
                Picker(t("Cliente", "Client"), selection: $clientId) {
                    Text(t("Selecione...", "Select...")).tag("")
                    ForEach(clients, id: \.id) { c in
                        Text("\(c.name) (\(c.id))").tag(c.id)
                    }
                }

                TextField(t("Alias (ex: scma-ssh01)", "Alias (e.g. scma-ssh01)"), text: $alias)
                TextField(t("Nome do servidor", "Server name"), text: $name)
                TextField(t("Host/IP", "Host/IP"), text: $host)

                TextField(t("Porta (padrão 22)", "Port (default 22)"), text: $portText)

                TextField(t("Usuário", "User"), text: $user)
                TextField(t("Tags (opcional)", "Tags (optional)"), text: $tags)
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("Observações (opcional)", "Notes (optional)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                }
            }

            HStack {
                Button(t("Cancelar", "Cancel")) { dismiss() }
                Spacer()
                Button(t("Salvar", "Save")) {
                    let p = Int(portText.trimmed) ?? 22
                    onSave(.init(
                        alias: alias.trimmed,
                        clientId: clientId.trimmed,
                        name: name.trimmed,
                        host: host.trimmed,
                        port: p,
                        user: user.trimmed,
                        tags: tags.trimmed,
                        notes: notes.trimmed
                    ))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(clientId.trimmed.isEmpty || alias.trimmed.isEmpty || name.trimmed.isEmpty || host.trimmed.isEmpty || user.trimmed.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 760, minHeight: 560)
        .preferredColorScheme(.dark)
        .onAppear {
            if clientId.isEmpty {
                clientId = preselected?.id ?? clients.first?.id ?? ""
            }
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
