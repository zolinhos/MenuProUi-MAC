import SwiftUI

struct EditURLView: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: URLAccess
    let onSave: (URLAccess) -> Void

    @State private var urlText: String

    init(item: URLAccess, onSave: @escaping (URLAccess) -> Void) {
        self._item = State(initialValue: item)
        self.onSave = onSave
        let portPart = item.port == 443 ? "" : ":\(item.port)"
        self._urlText = State(initialValue: "https://\(item.host)\(portPart)\(item.path)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Editar URL (HTTPS)").font(.title2).bold()

            Form {
                Text("Alias: \(item.alias)").foregroundStyle(.secondary)
                Text("Cliente: \(item.clientId)").foregroundStyle(.secondary)

                TextField("Nome", text: $item.name)
                TextField("URL completa", text: $urlText)
                TextField("Tags", text: $item.tags)
                TextField("Observações", text: $item.notes)
            }

            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Salvar") {
                    let parsed = parseHTTPS(urlText.trimmed)
                    item.host = parsed.host
                    item.port = parsed.port
                    item.path = parsed.path
                    onSave(item)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .preferredColorScheme(.dark)
    }

    private func parseHTTPS(_ s: String) -> (host: String, port: Int, path: String) {
        let raw = s.lowercased().hasPrefix("http") ? s : "https://\(s)"
        guard let comps = URLComponents(string: raw) else { return (item.host, item.port, item.path) }
        let host = comps.host ?? item.host
        let port = comps.port ?? 443
        let path = comps.path.isEmpty ? "/" : comps.path
        return (host, port, path)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
