import SwiftUI

struct AddURLView: View {
    @Environment(\.dismiss) private var dismiss

    let clients: [Client]
    let preselected: Client?
    let onSave: (URLAccess) -> Void

    @State private var alias = ""
    @State private var clientId = ""
    @State private var name = ""
    @State private var urlText = "http://"
    @State private var tags = ""
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cadastrar URL").font(.title2).bold()

            Form {
                Picker("Cliente", selection: $clientId) {
                    Text("Selecione...").tag("")
                    ForEach(clients, id: \.id) { c in
                        Text("\(c.name) (\(c.id))").tag(c.id)
                    }
                }

                TextField("Alias (ex: fw-web01)", text: $alias)
                TextField("Nome (ex: Firewall / VMware)", text: $name)

                TextField("URL completa (ex: http://firewall...:4444)", text: $urlText)

                TextField("Tags (opcional)", text: $tags)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Observações (opcional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                }

                Text("Se não informar esquema, será assumido http://")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Salvar") {
                    let parsed = parseURL(urlText.trimmed)
                    onSave(URLAccess(
                        alias: alias.trimmed,
                        clientId: clientId.trimmed,
                        name: name.trimmed,
                        scheme: parsed.scheme,
                        host: parsed.host,
                        port: parsed.port,
                        path: parsed.path,
                        tags: tags.trimmed,
                        notes: notes.trimmed
                    ))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(clientId.trimmed.isEmpty || alias.trimmed.isEmpty || name.trimmed.isEmpty || urlText.trimmed.isEmpty)
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

    private func parseURL(_ s: String) -> (scheme: String, host: String, port: Int, path: String) {
        let raw = s.contains("://") ? s : "http://\(s)"
        guard let comps = URLComponents(string: raw) else {
            return ("http", "", 80, "/")
        }
        let scheme = (comps.scheme ?? "http").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let host = comps.host ?? ""
        let port = comps.port ?? defaultPort(for: scheme)
        let path = comps.path.isEmpty ? "/" : comps.path
        return (scheme, host, port, path)
    }

    private func defaultPort(for scheme: String) -> Int {
        switch scheme {
        case "http":
            return 80
        case "https":
            return 443
        case "ftp":
            return 21
        default:
            return 80
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
