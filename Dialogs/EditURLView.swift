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
        self._urlText = State(initialValue: "\(item.scheme)://\(item.host)\(portPart)\(item.path)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Editar URL").font(.title2).bold()

            Form {
                TextField("Alias", text: $item.alias)
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
                    let parsed = parseURL(urlText.trimmed)
                    item.scheme = parsed.scheme
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

    private func parseURL(_ s: String) -> (scheme: String, host: String, port: Int, path: String) {
        let raw = s.contains("://") ? s : "http://\(s)"
        guard let comps = URLComponents(string: raw) else { return (item.scheme, item.host, item.port, item.path) }
        let scheme = (comps.scheme ?? item.scheme).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let host = comps.host ?? item.host
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
