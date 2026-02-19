import SwiftUI

struct AddAccessPayload {
    var kind: AccessKind
    var alias: String
    var clientId: String
    var name: String
    var host: String
    var port: Int
    var user: String
    var domain: String
    var scheme: String
    var path: String
    var tags: String
    var notes: String
    var rdpIgnoreCert: Bool
    var rdpFullScreen: Bool
    var rdpDynamicResolution: Bool
    var rdpWidth: Int?
    var rdpHeight: Int?
}

struct AddAccessView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app.language") private var appLanguageRaw = AppLanguage.pt.rawValue

    let clients: [Client]
    let preselected: Client?
    let initialKind: AccessKind
    let initialPayload: AddAccessPayload?
    let onSave: (AddAccessPayload) -> Void

    @State private var kind: AccessKind
    @State private var alias = ""
    @State private var clientId = ""
    @State private var name = ""
    @State private var host = ""
    @State private var portText = "22"
    @State private var user = ""
    @State private var domain = ""
    @State private var scheme = "https"
    @State private var path = "/"
    @State private var tags = ""
    @State private var notes = ""
    @State private var rdpIgnoreCert = true
    @State private var rdpFullScreen = false
    @State private var rdpDynamicResolution = true
    @State private var rdpWidthText = ""
    @State private var rdpHeightText = ""

    private var appLanguage: AppLanguage { .from(appLanguageRaw) }
    private func t(_ pt: String, _ en: String) -> String { I18n.text(pt, en, language: appLanguage) }

    init(clients: [Client], preselected: Client?, initialKind: AccessKind, initialPayload: AddAccessPayload? = nil, onSave: @escaping (AddAccessPayload) -> Void) {
        self.clients = clients
        self.preselected = preselected
        self.initialKind = initialKind
        self.initialPayload = initialPayload
        self.onSave = onSave
        _kind = State(initialValue: initialKind)
    }

    private var requiresUser: Bool { kind == .ssh || kind == .rdp || kind == .mtk }
    private var isURL: Bool { kind == .url }
    private var isRDP: Bool { kind == .rdp }

    private var isFormValid: Bool {
        if clientId.trimmed.isEmpty || alias.trimmed.isEmpty || name.trimmed.isEmpty || host.trimmed.isEmpty {
            return false
        }
        if requiresUser && user.trimmed.isEmpty { return false }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(initialPayload == nil ? t("Novo acesso", "New access") : t("Editar acesso", "Edit access")).font(.title2).bold()

            Form {
                Picker(t("Cliente", "Client"), selection: $clientId) {
                    Text(t("Selecione...", "Select...")).tag("")
                    ForEach(clients, id: \.id) { c in
                        Text("\(c.name) (\(c.id))").tag(c.id)
                    }
                }

                Picker(t("Tipo", "Type"), selection: $kind) {
                    Text("SSH").tag(AccessKind.ssh)
                    Text("RDP").tag(AccessKind.rdp)
                    Text("URL").tag(AccessKind.url)
                    Text("MTK").tag(AccessKind.mtk)
                }
                .onChange(of: kind) { newKind in
                    switch newKind {
                    case .ssh: portText = "22"
                    case .rdp: portText = "3389"
                    case .url: portText = scheme.lowercased() == "http" ? "80" : "443"
                    case .mtk: portText = "8291"
                    }
                }

                TextField(t("Alias", "Alias"), text: $alias)
                TextField(t("Nome", "Name"), text: $name)
                TextField(t("Host/IP", "Host/IP"), text: $host)
                TextField(t("Porta", "Port"), text: $portText)

                if requiresUser {
                    TextField(t("Usuário", "User"), text: $user)
                }

                if isRDP {
                    TextField(t("Domínio", "Domain"), text: $domain)
                    Toggle(t("Ignorar certificado", "Ignore certificate"), isOn: $rdpIgnoreCert)
                    Toggle(t("Tela cheia", "Full screen"), isOn: $rdpFullScreen)
                    Toggle(t("Resolução dinâmica", "Dynamic resolution"), isOn: $rdpDynamicResolution)
                    if !rdpDynamicResolution {
                        TextField(t("Largura (opcional)", "Width (optional)"), text: $rdpWidthText)
                        TextField(t("Altura (opcional)", "Height (optional)"), text: $rdpHeightText)
                    }
                }

                if isURL {
                    Picker(t("Esquema", "Scheme"), selection: $scheme) {
                        Text("https").tag("https")
                        Text("http").tag("http")
                        Text("ftp").tag("ftp")
                    }
                    TextField("Path", text: $path)
                }

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
                    onSave(.init(
                        kind: kind,
                        alias: alias.trimmed,
                        clientId: clientId.trimmed,
                        name: name.trimmed,
                        host: host.trimmed,
                        port: Int(portText.trimmed) ?? 22,
                        user: user.trimmed,
                        domain: domain.trimmed,
                        scheme: scheme.trimmed,
                        path: path.trimmed.isEmpty ? "/" : path.trimmed,
                        tags: tags.trimmed,
                        notes: notes.trimmed,
                        rdpIgnoreCert: rdpIgnoreCert,
                        rdpFullScreen: rdpFullScreen,
                        rdpDynamicResolution: rdpDynamicResolution,
                        rdpWidth: Int(rdpWidthText.trimmed),
                        rdpHeight: Int(rdpHeightText.trimmed)
                    ))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
            }
        }
        .padding()
        .frame(minWidth: 780, minHeight: 620)
        .preferredColorScheme(.dark)
        .onAppear {
            if let payload = initialPayload {
                kind = payload.kind
                alias = payload.alias
                clientId = payload.clientId
                name = payload.name
                host = payload.host
                portText = "\(payload.port)"
                user = payload.user
                domain = payload.domain
                scheme = payload.scheme
                path = payload.path
                tags = payload.tags
                notes = payload.notes
                rdpIgnoreCert = payload.rdpIgnoreCert
                rdpFullScreen = payload.rdpFullScreen
                rdpDynamicResolution = payload.rdpDynamicResolution
                rdpWidthText = payload.rdpWidth.map(String.init) ?? ""
                rdpHeightText = payload.rdpHeight.map(String.init) ?? ""
                return
            }
            if clientId.isEmpty { clientId = preselected?.id ?? clients.first?.id ?? "" }
            switch initialKind {
            case .ssh: portText = "22"
            case .rdp: portText = "3389"
            case .url: portText = scheme.lowercased() == "http" ? "80" : "443"
            case .mtk: portText = "8291"
            }
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
