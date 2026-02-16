import SwiftUI

struct EditSSHView: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: SSHServer
    let onSave: (SSHServer) -> Void

    @State private var portText: String

    init(item: SSHServer, onSave: @escaping (SSHServer) -> Void) {
        self._item = State(initialValue: item)
        self.onSave = onSave
        self._portText = State(initialValue: "\(item.port)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Editar SSH").font(.title2).bold()

            Form {
                TextField("Alias", text: $item.alias)
                Text("Cliente: \(item.clientId)").foregroundStyle(.secondary)

                TextField("Nome", text: $item.name)
                TextField("Host/IP", text: $item.host)
                TextField("Porta", text: $portText)
                TextField("Usuário", text: $item.user)
                TextField("Tags", text: $item.tags)
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
