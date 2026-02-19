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

    let clients: [Client]
    let preselected: Client?
    let initialKind: AccessKind
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

    init(clients: [Client], preselected: Client?, initialKind: AccessKind, onSave: @escaping (AddAccessPayload) -> Void) {
        self.clients = clients
        self.preselected = preselected
        self.initialKind = initialKind
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
            Text("Novo acesso").font(.title2).bold()

            Form {
                Picker("Cliente", selection: $clientId) {
                    Text("Selecione...").tag("")
                    ForEach(clients, id: \.id) { c in
                        Text("\(c.name) (\(c.id))").tag(c.id)
                    }
                }

                Picker("Tipo", selection: $kind) {
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

                TextField("Alias", text: $alias)
                TextField("Nome", text: $name)
                TextField("Host/IP", text: $host)
                TextField("Porta", text: $portText)

                if requiresUser {
                    TextField("Usuário", text: $user)
                }

                if isRDP {
                    TextField("Domínio", text: $domain)
                    Toggle("Ignorar certificado", isOn: $rdpIgnoreCert)
                    Toggle("Tela cheia", isOn: $rdpFullScreen)
                    Toggle("Resolução dinâmica", isOn: $rdpDynamicResolution)
                    if !rdpDynamicResolution {
                        TextField("Largura (opcional)", text: $rdpWidthText)
                        TextField("Altura (opcional)", text: $rdpHeightText)
                    }
                }

                if isURL {
                    Picker("Esquema", selection: $scheme) {
                        Text("https").tag("https")
                        Text("http").tag("http")
                        Text("ftp").tag("ftp")
                    }
                    TextField("Path", text: $path)
                }

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
            if clientId.isEmpty {
                clientId = preselected?.id ?? clients.first?.id ?? ""
            }
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
