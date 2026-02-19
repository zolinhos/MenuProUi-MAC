import SwiftUI

struct AddMTKPayload {
    var alias: String
    var clientId: String
    var name: String
    var host: String
    var port: Int
    var user: String
    var tags: String
    var notes: String
}

struct AddMTKView: View {
    @Environment(\.dismiss) private var dismiss

    let clients: [Client]
    let preselected: Client?
    let onSave: (AddMTKPayload) -> Void

    @State private var alias = ""
    @State private var clientId = ""
    @State private var name = ""
    @State private var host = ""
    @State private var portText = "8291"
    @State private var user = ""
    @State private var tags = ""
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cadastrar MTK (WinBox)").font(.title2).bold()

            Form {
                Picker("Cliente", selection: $clientId) {
                    Text("Selecione...").tag("")
                    ForEach(clients, id: \.id) { c in
                        Text("\(c.name) (\(c.id))").tag(c.id)
                    }
                }

                TextField("Alias (ex: mikrotik-matriz)", text: $alias)
                TextField("Nome do equipamento", text: $name)
                TextField("Host/IP", text: $host)
                TextField("Porta (padrão 8291)", text: $portText)
                TextField("Usuário", text: $user)
                TextField("Tags (opcional)", text: $tags)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Observações (opcional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                }
            }

            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Salvar") {
                    onSave(.init(
                        alias: alias.trimmed,
                        clientId: clientId.trimmed,
                        name: name.trimmed,
                        host: host.trimmed,
                        port: Int(portText.trimmed) ?? 8291,
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
