import SwiftUI

// MARK: - Editar SSH
/// Diálogo para edição de um acesso SSH existente.
/// Valida que alias, nome, host e usuário não fiquem vazios antes de permitir salvar.
struct EditSSHView: View {
    @Environment(\.dismiss) private var dismiss

    /// Servidor SSH sendo editado (cópia local mutável).
    @State var item: SSHServer

    /// Callback executado ao salvar com sucesso.
    let onSave: (SSHServer) -> Void

    /// Porta como texto para permitir digitação livre.
    @State private var portText: String

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
            Text("Editar SSH").font(.title2).bold()

            Form {
                TextField("Alias", text: $item.alias)
                // ClientId — somente leitura
                Text("Cliente: \(item.clientId)").foregroundStyle(.secondary)

                TextField("Nome", text: $item.name)
                TextField("Host/IP", text: $item.host)
                TextField("Porta", text: $portText)
                TextField("Usuário", text: $item.user)
                TextField("Tags", text: $item.tags)

                // Observações — campo multi-linha
                VStack(alignment: .leading, spacing: 6) {
                    Text("Observações")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $item.notes)
                        .frame(minHeight: 90)
                }
            }

            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Salvar") {
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
