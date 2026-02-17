import SwiftUI

struct EditURLView: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: URLAccess
    let onSave: (URLAccess) -> Void

    @State private var urlText: String

    private var parsed: (scheme: String, host: String, port: Int, path: String) {
        parseURL(urlText.trimmed)
    }

    private var finalURLPreview: String {
        let p = parsed
        guard !p.host.isEmpty else { return "" }
        let defaultPort = defaultPort(for: p.scheme)
        let portPart = p.port == defaultPort ? "" : ":\(p.port)"
        return "\(p.scheme)://\(p.host)\(portPart)\(p.path)"
    }

    private var urlValidationError: String? {
        let raw = urlText.trimmed
        if raw.isEmpty { return "Informe uma URL" }
        let normalized = normalizedURLInput(raw)
        guard let comps = URLComponents(string: normalized) else { return "URL inválida" }
        if (comps.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Host ausente na URL"
        }
        return nil
    }

    init(item: URLAccess, onSave: @escaping (URLAccess) -> Void) {
        self._item = State(initialValue: item)
        self.onSave = onSave
        let defaultPort = item.scheme.lowercased() == "https" ? 443 : (item.scheme.lowercased() == "http" ? 80 : 80)
        let portPart = item.port == defaultPort ? "" : ":\(item.port)"
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

                if let urlValidationError {
                    Text(urlValidationError)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if !finalURLPreview.isEmpty {
                    Text("URL final: \(finalURLPreview)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                TextField("Tags", text: $item.tags)
                TextField("Observações", text: $item.notes)
            }

            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Salvar") {
                    let parsed = parsed
                    item.scheme = parsed.scheme
                    item.host = parsed.host
                    item.port = parsed.port
                    item.path = parsed.path
                    onSave(item)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlValidationError != nil)
            }
        }
        .padding()
        .preferredColorScheme(.dark)
    }

    private func parseURL(_ s: String) -> (scheme: String, host: String, port: Int, path: String) {
        let raw = normalizedURLInput(s)
        guard let comps = URLComponents(string: raw) else { return (item.scheme, item.host, item.port, item.path) }
        let scheme = (comps.scheme ?? item.scheme).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let host = (comps.host ?? item.host).trimmingCharacters(in: .whitespacesAndNewlines)

        let fallbackPort = defaultPort(for: scheme)
        let port = sanitizePort(comps.port ?? fallbackPort, fallback: fallbackPort)

        let basePath = comps.path.isEmpty ? "/" : comps.path
        let queryPart = (comps.percentEncodedQuery?.isEmpty == false) ? "?\(comps.percentEncodedQuery!)" : ""
        let fragmentPart = (comps.percentEncodedFragment?.isEmpty == false) ? "#\(comps.percentEncodedFragment!)" : ""
        let path = basePath + queryPart + fragmentPart
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

    private func sanitizePort(_ port: Int, fallback: Int) -> Int {
        (1...65535).contains(port) ? port : fallback
    }

    private func normalizedURLInput(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "http://" }
        if trimmed.contains("://") { return trimmed }

        if let colonIndex = trimmed.firstIndex(of: ":") {
            let schemePart = String(trimmed[..<colonIndex]).lowercased()
            let remainder = String(trimmed[trimmed.index(after: colonIndex)...])
            if isValidScheme(schemePart), !remainder.isEmpty, !remainder.hasPrefix("//") {
                return "\(schemePart)://\(remainder)"
            }
        }

        return "http://\(trimmed)"
    }

    private func isValidScheme(_ value: String) -> Bool {
        guard let first = value.first else { return false }
        guard first.isLetter else { return false }
        return value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
