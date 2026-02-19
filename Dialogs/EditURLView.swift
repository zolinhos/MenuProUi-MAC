import SwiftUI

// MARK: - Editar URL
/// Diálogo para edição de um acesso URL existente.
/// Valida que alias e nome não fiquem vazios, além da validação de URL.
/// A URL é parseada em scheme/host/port/path ao salvar.
struct EditURLView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app.language") private var appLanguageRaw = AppLanguage.pt.rawValue

    /// Acesso URL sendo editado (cópia local mutável).
    @State var item: URLAccess

    /// Callback executado ao salvar com sucesso.
    let onSave: (URLAccess) -> Void

    /// URL completa como texto editável.
    @State private var urlText: String

    // Configurações de conectividade (compartilhadas via AppStorage)
    @AppStorage("connectivity.timeoutSeconds") private var connectivityTimeoutSeconds: Double = 3.0
    @AppStorage("connectivity.urlFallbackPorts") private var urlFallbackPortsCSV: String = "443,80,8443,8080,9443"

    /// Chave separada do AddURLView para não misturar sessões.
    @SceneStorage("session.editLastTestedURL") private var lastTestedURL: String = ""

    /// Estado do teste de conectividade inline.
    @State private var isTestingURL = false
    @State private var urlTestResultText: String = ""
    @State private var urlTestResultIsOnline: Bool?
    private var appLanguage: AppLanguage { .from(appLanguageRaw) }
    private func t(_ pt: String, _ en: String) -> String { I18n.text(pt, en, language: appLanguage) }

    /// URL parseada em componentes (scheme, host, port, path).
    private var parsed: (scheme: String, host: String, port: Int, path: String) {
        parseURL(urlText.trimmed)
    }

    /// Prévia da URL final formatada para exibição.
    private var finalURLPreview: String {
        let p = parsed
        guard !p.host.isEmpty else { return "" }
        let defaultPort = defaultPort(for: p.scheme)
        let portPart = p.port == defaultPort ? "" : ":\(p.port)"
        return "\(p.scheme)://\(p.host)\(portPart)\(p.path)"
    }

    /// Retorna mensagem de erro se a URL é inválida, ou nil se está ok.
    private var urlValidationError: String? {
        let raw = urlText.trimmed
        if raw.isEmpty { return t("Informe uma URL", "Enter a URL") }
        let normalized = normalizedURLInput(raw)
        guard let comps = URLComponents(string: normalized) else { return t("URL inválida", "Invalid URL") }
        if (comps.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return t("Host ausente na URL", "Missing host in URL")
        }
        return nil
    }

    /// Validação completa: alias, nome e URL válida.
    private var isFormValid: Bool {
        !item.alias.trimmed.isEmpty &&
        !item.name.trimmed.isEmpty &&
        urlValidationError == nil
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
            Text(t("Editar URL", "Edit URL")).font(.title2).bold()

            Form {
                TextField(t("Alias", "Alias"), text: $item.alias)
                // ClientId — somente leitura
                Text("\(t("Cliente", "Client")): \(item.clientId)").foregroundStyle(.secondary)

                TextField(t("Nome", "Name"), text: $item.name)
                TextField(t("URL completa", "Full URL"), text: $urlText)

                // Exibe erro de validação ou prévia da URL final
                if let urlValidationError {
                    Text(urlValidationError)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if !finalURLPreview.isEmpty {
                    Text("\(t("URL final", "Final URL")): \(finalURLPreview)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !lastTestedURL.isEmpty {
                    Text("\(t("Última URL testada (sessão)", "Last tested URL (session)")): \(lastTestedURL)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Botão de teste de conectividade inline
                HStack {
                    Button(isTestingURL ? t("Testando...", "Testing...") : t("Testar URL", "Test URL")) {
                        testURLNow()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingURL || urlValidationError != nil)

                    if !urlTestResultText.isEmpty {
                        Text(urlTestResultText)
                            .font(.caption)
                            .foregroundStyle(urlTestResultIsOnline == true ? .green : (urlTestResultIsOnline == false ? .red : .secondary))
                            .lineLimit(2)
                    }
                    Spacer()
                }

                TextField(t("Tags", "Tags"), text: $item.tags)

                // Observações — campo multi-linha (consistente com AddURLView)
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
                    let parsed = parsed
                    item.scheme = parsed.scheme
                    item.host = parsed.host
                    item.port = parsed.port
                    item.path = parsed.path
                    onSave(item)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
            }
        }
        .padding()
        .frame(minWidth: 760, minHeight: 560)
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

    private func testURLNow() {
        guard !isTestingURL else { return }
        guard urlValidationError == nil else { return }
        let preview = finalURLPreview
        guard !preview.isEmpty else { return }

        isTestingURL = true
        urlTestResultText = ""
        urlTestResultIsOnline = nil
        lastTestedURL = preview

        let timeout = max(0.5, min(connectivityTimeoutSeconds, 60.0))
        let fallbackPorts = parsePortsCSV(urlFallbackPortsCSV, fallback: [443, 80, 8443, 8080, 9443])

        let testRow = AccessRow(
            id: "url-test",
            clientId: item.clientId,
            clientName: "",
            kind: .url,
            alias: item.alias,
            name: item.name,
            host: parsed.host,
            port: "\(parsed.port)",
            user: "",
            url: preview,
            tags: "",
            notes: "",
            isFavorite: false,
            openCount: 0,
            lastOpenedAt: ""
        )

        Task(priority: .utility) {
            let results = await ConnectivityChecker.checkAll(rows: [testRow], timeout: timeout, maxConcurrency: 1, urlFallbackPorts: fallbackPorts)
            let result = results[testRow.id]
            await MainActor.run {
                isTestingURL = false
                guard let result else {
                    urlTestResultIsOnline = false
                    urlTestResultText = t("Falha ao testar", "Failed to test")
                    return
                }
                urlTestResultIsOnline = result.isOnline
                if result.isOnline {
                    urlTestResultText = "Online (\(result.method.rawValue)) \(max(0, result.durationMs))ms"
                } else {
                    urlTestResultText = "\(t("Offline", "Offline")): \(result.errorDetail)"
                }
            }
        }
    }

    private func parsePortsCSV(_ raw: String, fallback: [Int]) -> [Int] {
        let parts = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var ports: [Int] = []
        for p in parts {
            if let v = Int(p), (1...65535).contains(v), !ports.contains(v) {
                ports.append(v)
            }
        }
        return ports.isEmpty ? fallback : ports
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
