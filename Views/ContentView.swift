import SwiftUI
import Charts

private enum ConnectivityState {
    case unknown
    case checking
    case online
    case offline
}

struct ContentView: View {
    @StateObject private var store = CSVStore()
    @StateObject private var logs = LogParser()

    @State private var selectedClientId: String?
    @State private var selectedAccessId: String?
    @State private var clientsSearchText = ""
    @State private var accessesSearchText = ""

    @State private var showAddClient = false
    @State private var showAddSSH = false
    @State private var showAddRDP = false
    @State private var showAddURL = false
    @State private var showAddAccessChooser = false
    @State private var showHelp = false

    @State private var editingClient: Client?
    @State private var editingSSH: SSHServer?
    @State private var editingRDP: RDPServer?
    @State private var editingURL: URLAccess?

    @State private var confirmDeleteClient: Client?
    @State private var confirmDeleteSSH: SSHServer?
    @State private var confirmDeleteRDP: RDPServer?
    @State private var confirmDeleteURL: URLAccess?

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var accessConnectivity: [String: ConnectivityState] = [:]
    @State private var isCheckingConnectivity = false
    @State private var lastConnectivityCheck: Date?

    var body: some View {
        dialogsLayer
    }

    private var selectedClient: Client? {
        guard let selectedClientId else { return nil }
        return store.clients.first { $0.id.caseInsensitiveCompare(selectedClientId) == .orderedSame }
    }

    private var filteredClients: [Client] {
        let term = clientsSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return store.clients }
        return store.clients.filter {
            $0.id.lowercased().contains(term) ||
            $0.name.lowercased().contains(term) ||
            $0.tags.lowercased().contains(term)
        }
    }

    private var allRowsForSelectedClient: [AccessRow] {
        guard let selectedClientId else { return [] }
        return allRows(for: selectedClientId)
    }

    private func allRows(for clientId: String) -> [AccessRow] {
        let client = clientId.lowercased()

        let sshRows = store.ssh.filter { $0.clientId.lowercased() == client }.map {
            AccessRow(id: $0.id, kind: .ssh, alias: $0.alias, name: $0.name, host: $0.host, port: "\($0.port)", user: $0.user, url: "")
        }
        let rdpRows = store.rdp.filter { $0.clientId.lowercased() == client }.map {
            AccessRow(id: $0.id, kind: .rdp, alias: $0.alias, name: $0.name, host: $0.host, port: "\($0.port)", user: $0.user, url: "")
        }
        let urlRows = store.urls.filter { $0.clientId.lowercased() == client }.map {
            AccessRow(id: $0.id, kind: .url, alias: $0.alias, name: $0.name, host: $0.host, port: "\($0.port)", user: "", url: "https://\($0.host):\($0.port)\($0.path)")
        }
        return (sshRows + rdpRows + urlRows).sorted { lhs, rhs in
            if lhs.kind.rawValue == rhs.kind.rawValue {
                return lhs.alias.localizedCaseInsensitiveCompare(rhs.alias) == .orderedAscending
            }
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
    }

    private var filteredRows: [AccessRow] {
        let term = accessesSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return allRowsForSelectedClient }
        return allRowsForSelectedClient.filter {
            $0.alias.lowercased().contains(term) ||
            $0.name.lowercased().contains(term) ||
            $0.host.lowercased().contains(term) ||
            $0.user.lowercased().contains(term) ||
            $0.url.lowercased().contains(term)
        }
    }

    private var selectedAccessRow: AccessRow? {
        guard let selectedAccessId else { return nil }
        return filteredRows.first { $0.id == selectedAccessId }
            ?? allRowsForSelectedClient.first { $0.id == selectedAccessId }
    }

    private var baseLayout: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
        } detail: {
            detail
        }
        .tint(.blue)
        .onAppear {
            if selectedClientId == nil { selectedClientId = store.clients.first?.id }
            if selectedAccessId == nil { selectedAccessId = filteredRows.first?.id }
        }
        .onChange(of: selectedClientId) { _ in
            selectedAccessId = filteredRows.first?.id
        }
        .onChange(of: store.clients) { _ in
            if let selectedClientId,
               !store.clients.contains(where: { $0.id.caseInsensitiveCompare(selectedClientId) == .orderedSame }) {
                self.selectedClientId = store.clients.first?.id
            }
        }
    }

    private var dialogsLayer: some View {
        baseLayout
            .alert("Erro", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog("Novo acesso", isPresented: $showAddAccessChooser) {
                Button("Cadastrar SSH") { showAddSSH = true }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("Cadastrar RDP") { showAddRDP = true }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("Cadastrar URL") { showAddURL = true }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("Cancelar", role: .cancel) {}
                    .keyboardShortcut(.cancelAction)
            } message: {
                Text("Escolha o tipo de acesso para o cliente selecionado.")
            }
            .sheet(isPresented: $showHelp) { helpSheet }
            .sheet(isPresented: $showAddClient) {
                AddClientView { id, name, tags, notes in
                    do {
                        try store.addClient(id: id, name: name, tags: tags, notes: notes)
                        selectedClientId = store.clients.first(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame })?.id
                    } catch { showErr(error) }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAddSSH) {
                AddSSHView(clients: store.clients, preselected: selectedClient) { payload in
                    do {
                        try store.addSSH(alias: payload.alias, clientId: payload.clientId, name: payload.name, host: payload.host, port: payload.port, user: payload.user, tags: payload.tags, notes: payload.notes)
                        selectedAccessId = store.ssh.first(where: {
                            $0.clientId.caseInsensitiveCompare(payload.clientId) == .orderedSame &&
                            $0.alias.caseInsensitiveCompare(payload.alias) == .orderedSame
                        })?.id
                    } catch { showErr(error) }
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showAddRDP) {
                AddRDPView(clients: store.clients, preselected: selectedClient) { payload in
                    do {
                        try store.addRDP(payload: payload)
                        selectedAccessId = store.rdp.first(where: {
                            $0.clientId.caseInsensitiveCompare(payload.clientId) == .orderedSame &&
                            $0.alias.caseInsensitiveCompare(payload.alias) == .orderedSame
                        })?.id
                    } catch { showErr(error) }
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showAddURL) {
                AddURLView(clients: store.clients, preselected: selectedClient) { access in
                    do {
                        try store.addURL(access)
                        selectedAccessId = store.urls.first(where: {
                            $0.clientId.caseInsensitiveCompare(access.clientId) == .orderedSame &&
                            $0.alias.caseInsensitiveCompare(access.alias) == .orderedSame
                        })?.id
                    } catch { showErr(error) }
                }
                .presentationDetents([.large])
            }
            .sheet(item: $editingClient) { client in
                EditClientView(item: client) { updated in
                    do { try store.updateClient(updated) } catch { showErr(error) }
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $editingSSH) { item in
                EditSSHView(item: item) { updated in
                    do { try store.updateSSH(updated) } catch { showErr(error) }
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $editingRDP) { item in
                EditRDPView(item: item) { updated in
                    do { try store.updateRDP(updated) } catch { showErr(error) }
                }
                .presentationDetents([.large])
            }
            .sheet(item: $editingURL) { item in
                EditURLView(item: item) { updated in
                    do { try store.updateURL(updated) } catch { showErr(error) }
                }
                .presentationDetents([.large])
            }
            .confirmationDialog("Apagar cliente?", isPresented: Binding(get: { confirmDeleteClient != nil }, set: { if !$0 { confirmDeleteClient = nil } })) {
                Button("Apagar (cascata)", role: .destructive) {
                    guard let client = confirmDeleteClient else { return }
                    do {
                        try store.deleteClientCascade(clientId: client.id)
                        selectedClientId = store.clients.first?.id
                        selectedAccessId = nil
                    } catch { showErr(error) }
                    confirmDeleteClient = nil
                }
                Button("Cancelar", role: .cancel) { confirmDeleteClient = nil }
            }
            .confirmationDialog("Apagar SSH?", isPresented: Binding(get: { confirmDeleteSSH != nil }, set: { if !$0 { confirmDeleteSSH = nil } })) {
                Button("Apagar", role: .destructive) {
                    guard let item = confirmDeleteSSH else { return }
                    do {
                        try store.deleteSSH(id: item.id)
                        selectedAccessId = filteredRows.first?.id
                    } catch { showErr(error) }
                    confirmDeleteSSH = nil
                }
                Button("Cancelar", role: .cancel) { confirmDeleteSSH = nil }
            }
            .confirmationDialog("Apagar RDP?", isPresented: Binding(get: { confirmDeleteRDP != nil }, set: { if !$0 { confirmDeleteRDP = nil } })) {
                Button("Apagar", role: .destructive) {
                    guard let item = confirmDeleteRDP else { return }
                    do {
                        try store.deleteRDP(id: item.id)
                        selectedAccessId = filteredRows.first?.id
                    } catch { showErr(error) }
                    confirmDeleteRDP = nil
                }
                Button("Cancelar", role: .cancel) { confirmDeleteRDP = nil }
            }
            .confirmationDialog("Apagar URL?", isPresented: Binding(get: { confirmDeleteURL != nil }, set: { if !$0 { confirmDeleteURL = nil } })) {
                Button("Apagar", role: .destructive) {
                    guard let item = confirmDeleteURL else { return }
                    do {
                        try store.deleteURL(id: item.id)
                        selectedAccessId = filteredRows.first?.id
                    } catch { showErr(error) }
                    confirmDeleteURL = nil
                }
                Button("Cancelar", role: .cancel) { confirmDeleteURL = nil }
            }
    }

    private var sidebar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("MenuProUI-MAC")
                    .font(.title2)
                    .bold()
                Spacer()
                Button {
                    store.reload()
                    logs.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("r", modifiers: [.command])
            }

            HStack(spacing: 8) {
                Button { showAddClient = true } label: {
                    Label("Novo Cliente", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("n", modifiers: [.command])

                Button {
                    guard selectedClient != nil else {
                        showErrText("Selecione um cliente antes de criar um acesso.")
                        return
                    }
                    showAddAccessChooser = true
                } label: {
                    Label("Novo Acesso", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            TextField("Buscar cliente...", text: $clientsSearchText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Clientes").font(.headline)
                Spacer()
                Text("\(filteredClients.count)").foregroundStyle(.secondary)
            }

            List(selection: $selectedClientId) {
                ForEach(filteredClients) { client in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            connectivityIndicator(for: clientConnectivityState(clientId: client.id), size: 9)
                            Text(client.name).font(.headline)
                        }
                        if !client.tags.isEmpty {
                            Text(client.tags).font(.caption).foregroundStyle(.blue.opacity(0.9))
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(client.id)
                    .contextMenu {
                        Button("Editar") { editingClient = client }
                        Button("Apagar", role: .destructive) { confirmDeleteClient = client }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Arquivos").font(.caption).foregroundStyle(.secondary)
                Text(store.clientsPath).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Text(store.acessosPath).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding()
        .background(Color.black.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var detail: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedClient?.name ?? "Visão Geral")
                        .font(.title)
                        .bold()
                    Text("Conexões SSH, RDP e HTTPS")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Ajuda") { showHelp = true }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("/", modifiers: [.command])
            }

            if !logs.points.isEmpty { chartCard }

            if selectedClient == nil {
                Text("Selecione um cliente para visualizar os acessos.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                VStack(spacing: 10) {
                    HStack {
                        TextField("Buscar acesso...", text: $accessesSearchText)
                            .textFieldStyle(.roundedBorder)
                        Text("\(filteredRows.count) acessos")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Button("Abrir") { openSelectedAccess() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                            .disabled(selectedAccessRow == nil)
                        Button {
                            checkSelectedClientConnectivity()
                        } label: {
                            Label(isCheckingConnectivity ? "Checando..." : "Checar Conectividade", systemImage: "wave.3.right")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isCheckingConnectivity || selectedClient == nil || allRowsForSelectedClient.isEmpty)
                        Button("Editar") { editSelectedAccess() }
                            .buttonStyle(.bordered)
                            .keyboardShortcut("e", modifiers: [.command])
                            .disabled(selectedAccessRow == nil)
                        Button("Excluir", role: .destructive) { deleteSelectedAccess() }
                            .buttonStyle(.bordered)
                            .keyboardShortcut(.delete, modifiers: [])
                            .disabled(selectedAccessRow == nil)
                        Spacer()
                    }

                    if let lastConnectivityCheck {
                        HStack {
                            Text("Última checagem: \(lastConnectivityCheck.formatted(date: .abbreviated, time: .standard))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }

                    accessHeader

                    List(selection: $selectedAccessId) {
                        ForEach(filteredRows) { row in
                            accessRowView(row)
                                .tag(row.id)
                                .contextMenu {
                                    Button("Abrir") { open(row: row) }
                                    Button("Clonar") { clone(row: row) }
                                    Button("Editar") { edit(row: row) }
                                    Button("Excluir", role: .destructive) { delete(row: row) }
                                }
                                .onTapGesture(count: 2) { open(row: row) }
                        }
                    }
                }
                .padding()
                .background(Color(red: 0.03, green: 0.05, blue: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer(minLength: 0)
            }
        }
        .padding()
        .background(Color.black)
    }

    private var accessHeader: some View {
        HStack {
            Text("Status").frame(width: 54, alignment: .leading)
            Text("Tipo").frame(width: 60, alignment: .leading)
            Text("Alias").frame(maxWidth: .infinity, alignment: .leading)
            Text("Host").frame(maxWidth: .infinity, alignment: .leading)
            Text("Porta").frame(width: 60, alignment: .leading)
            Text("Usuário/URL").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func accessRowView(_ row: AccessRow) -> some View {
        HStack {
            connectivityIndicator(for: connectivityState(for: row.id), size: 10)
                .frame(width: 54, alignment: .leading)
            Text(row.kind.rawValue).frame(width: 60, alignment: .leading)
            Text(row.alias).frame(maxWidth: .infinity, alignment: .leading)
            Text(row.host).frame(maxWidth: .infinity, alignment: .leading)
            Text(row.port).frame(width: 60, alignment: .leading)
            Text(row.kind == .url ? row.url : row.user)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }

    private func openSelectedAccess() {
        guard let row = selectedAccessRow else { return }
        open(row: row)
    }

    private func editSelectedAccess() {
        guard let row = selectedAccessRow else { return }
        edit(row: row)
    }

    private func deleteSelectedAccess() {
        guard let row = selectedAccessRow else { return }
        delete(row: row)
    }

    private func open(row: AccessRow) {
        switch row.kind {
        case .ssh:
            guard let access = store.ssh.first(where: { $0.id == row.id }) else { return }
            SSHLauncher.openSSH(host: access.host, port: access.port, user: access.user)
        case .rdp:
            guard let access = store.rdp.first(where: { $0.id == row.id }) else { return }
            RDPFileWriter.writeAndOpen(server: access)
        case .url:
            guard let access = store.urls.first(where: { $0.id == row.id }) else { return }
            URLLauncher.openHTTPS(host: access.host, port: access.port, path: access.path)
        }
    }

    private func edit(row: AccessRow) {
        switch row.kind {
        case .ssh:
            editingSSH = store.ssh.first(where: { $0.id == row.id })
        case .rdp:
            editingRDP = store.rdp.first(where: { $0.id == row.id })
        case .url:
            editingURL = store.urls.first(where: { $0.id == row.id })
        }
    }

    private func delete(row: AccessRow) {
        switch row.kind {
        case .ssh:
            confirmDeleteSSH = store.ssh.first(where: { $0.id == row.id })
        case .rdp:
            confirmDeleteRDP = store.rdp.first(where: { $0.id == row.id })
        case .url:
            confirmDeleteURL = store.urls.first(where: { $0.id == row.id })
        }
    }

    private func clone(row: AccessRow) {
        do {
            switch row.kind {
            case .ssh:
                guard let access = store.ssh.first(where: { $0.id == row.id }) else { return }
                let alias = makeCloneAlias(base: access.alias, kind: .ssh, clientId: access.clientId)
                try store.addSSH(
                    alias: alias,
                    clientId: access.clientId,
                    name: access.name,
                    host: access.host,
                    port: access.port,
                    user: access.user,
                    tags: access.tags,
                    notes: access.notes
                )
                selectedAccessId = store.ssh.first(where: {
                    $0.clientId.caseInsensitiveCompare(access.clientId) == .orderedSame &&
                    $0.alias.caseInsensitiveCompare(alias) == .orderedSame
                })?.id
            case .rdp:
                guard let access = store.rdp.first(where: { $0.id == row.id }) else { return }
                let alias = makeCloneAlias(base: access.alias, kind: .rdp, clientId: access.clientId)
                try store.addRDP(payload: .init(
                    alias: alias,
                    clientId: access.clientId,
                    name: access.name,
                    host: access.host,
                    port: access.port,
                    domain: access.domain,
                    user: access.user,
                    tags: access.tags,
                    ignoreCert: access.ignoreCert,
                    fullScreen: access.fullScreen,
                    dynamicResolution: access.dynamicResolution,
                    width: access.width,
                    height: access.height,
                    notes: access.notes
                ))
                selectedAccessId = store.rdp.first(where: {
                    $0.clientId.caseInsensitiveCompare(access.clientId) == .orderedSame &&
                    $0.alias.caseInsensitiveCompare(alias) == .orderedSame
                })?.id
            case .url:
                guard let access = store.urls.first(where: { $0.id == row.id }) else { return }
                let alias = makeCloneAlias(base: access.alias, kind: .url, clientId: access.clientId)
                try store.addURL(.init(
                    alias: alias,
                    clientId: access.clientId,
                    name: access.name,
                    host: access.host,
                    port: access.port,
                    path: access.path,
                    tags: access.tags,
                    notes: access.notes
                ))
                selectedAccessId = store.urls.first(where: {
                    $0.clientId.caseInsensitiveCompare(access.clientId) == .orderedSame &&
                    $0.alias.caseInsensitiveCompare(alias) == .orderedSame
                })?.id
            }
        } catch {
            showErr(error)
        }
    }

    private func makeCloneAlias(base: String, kind: AccessKind, clientId: String) -> String {
        let normalizedClient = clientId.lowercased()
        let used: Set<String>
        switch kind {
        case .ssh:
            used = Set(store.ssh.filter { $0.clientId.lowercased() == normalizedClient }.map { $0.alias.lowercased() })
        case .rdp:
            used = Set(store.rdp.filter { $0.clientId.lowercased() == normalizedClient }.map { $0.alias.lowercased() })
        case .url:
            used = Set(store.urls.filter { $0.clientId.lowercased() == normalizedClient }.map { $0.alias.lowercased() })
        }

        let root = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = root.isEmpty ? "acesso" : root
        let first = "\(fallback)-copia"
        if !used.contains(first.lowercased()) {
            return first
        }

        var index = 2
        while index < 1000 {
            let candidate = "\(fallback)-copia-\(index)"
            if !used.contains(candidate.lowercased()) {
                return candidate
            }
            index += 1
        }
        return "\(fallback)-copia-\(UUID().uuidString.prefix(6))"
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conexões por dia (SSH x RDP)").font(.headline)
            Chart(logs.points) { point in
                BarMark(
                    x: .value("Dia", point.day, unit: .day),
                    y: .value("Qtd", point.count)
                )
                .foregroundStyle(point.type == .ssh ? .blue : .cyan)
                .position(by: .value("Tipo", point.type.rawValue))
            }
            .frame(height: 120)
        }
        .padding()
        .background(Color(red: 0.05, green: 0.07, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var helpSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("MenuProUI-MAC - Ajuda")
                        .font(.title2)
                        .bold()

                    Text("Atalhos de teclado")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("⌘R  — Atualizar dados")
                        Text("⌘N  — Novo Cliente")
                        Text("⇧⌘N — Novo Acesso")
                        Text("↩︎   — Abrir acesso selecionado")
                        Text("⌘E  — Editar acesso selecionado")
                        Text("⌫   — Excluir acesso selecionado")
                        Text("⌘/  — Abrir Ajuda")
                        Text("No diálogo \"Novo acesso\":")
                        Text("⌘1  — Cadastrar SSH")
                        Text("⌘2  — Cadastrar RDP")
                        Text("⌘3  — Cadastrar URL")
                        Text("Esc  — Cancelar")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text("Armazenamento").font(.headline)
                    Text("Pasta base: \(CSVStore.dataDirectoryURL.path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Clientes: \(store.clientsPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Acessos: \(store.acessosPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Fechar") { showHelp = false }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func showErr(_ error: Error) {
        showErrText(error.localizedDescription)
    }

    private func showErrText(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func checkSelectedClientConnectivity() {
        let rows = allRowsForSelectedClient
        guard !rows.isEmpty else { return }

        isCheckingConnectivity = true
        for row in rows {
            accessConnectivity[row.id] = .checking
        }

        Task {
            let results = await ConnectivityChecker.checkAll(rows: rows)
            await MainActor.run {
                for row in rows {
                    accessConnectivity[row.id] = (results[row.id] == true) ? .online : .offline
                }
                lastConnectivityCheck = Date()
                isCheckingConnectivity = false
            }
        }
    }

    private func connectivityState(for accessId: String) -> ConnectivityState {
        accessConnectivity[accessId] ?? .unknown
    }

    private func clientConnectivityState(clientId: String) -> ConnectivityState {
        let rows = allRows(for: clientId)
        guard !rows.isEmpty else { return .unknown }
        let states = rows.map { connectivityState(for: $0.id) }

        if states.contains(.checking) {
            return .checking
        }
        if states.allSatisfy({ $0 == .online }) {
            return .online
        }
        if states.contains(.offline) {
            return .offline
        }
        return .unknown
    }

    @ViewBuilder
    private func connectivityIndicator(for state: ConnectivityState, size: CGFloat) -> some View {
        Circle()
            .fill(connectivityColor(for: state))
            .frame(width: size, height: size)
    }

    private func connectivityColor(for state: ConnectivityState) -> Color {
        switch state {
        case .online:
            return .green
        case .offline:
            return .red
        case .checking:
            return .yellow
        case .unknown:
            return .gray
        }
    }
}