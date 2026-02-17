import SwiftUI
import AppKit
import UniformTypeIdentifiers

private enum ConnectivityState {
    case unknown
    case checking
    case online
    case offline
}

private enum SearchField: Hashable {
    case global
    case clients
    case accesses
}

private enum ConnectivityFilter: String, CaseIterable {
    case all = "Todos"
    case online = "Online"
    case offline = "Offline"
    case checking = "Checando"
    case unknown = "Não checado"
}

struct ContentView: View {
    @StateObject private var store = CSVStore()
    @StateObject private var logs = LogParser()

    @AppStorage("connectivity.timeoutSeconds") private var connectivityTimeoutSeconds: Double = 3.0
    @AppStorage("connectivity.maxConcurrency") private var connectivityMaxConcurrency: Int = 12
    @AppStorage("connectivity.cacheTTLSeconds") private var connectivityCacheTTLSeconds: Double = 10.0
    @AppStorage("connectivity.urlFallbackPorts") private var urlFallbackPortsCSV: String = "443,80,8443,8080,9443"
    @AppStorage("connectivity.autoCheckOnSelect") private var autoCheckOnSelect = false
    @AppStorage("connectivity.autoCheckDebounceMs") private var autoCheckDebounceMs: Int = 800

    @State private var selectedClientId: String?
    @State private var selectedAccessId: String?
    @State private var globalSearchText = ""
    @State private var clientsSearchText = ""
    @State private var accessesSearchText = ""
    @State private var connectivityFilter: ConnectivityFilter = .all
    @State private var sortByConnectivityStatus = false

    @State private var showAddClient = false
    @State private var showAddSSH = false
    @State private var showAddRDP = false
    @State private var showAddURL = false
    @State private var showAddAccessChooser = false
    @State private var showHelp = false
    @State private var showAuditLog = false
    @State private var showConnectivityScopeChooser = false
    @State private var showSettings = false
    @State private var auditLogText = ""
    @State private var auditSearchText = ""
    @State private var auditActionFilter = "Todos"
    @State private var auditEntityFilter = "Todos"
    @State private var auditActions: [String] = ["Todos"]
    @State private var auditEntities: [String] = ["Todos"]
    @State private var auditIntegrityStatus = EventLogger.IntegrityStatus.missing
    @State private var isVerifyingAuditIntegrity = false
    @State private var auditEvents: [AuditEvent] = []

    @State private var editingClient: Client?
    @State private var editingSSH: SSHServer?
    @State private var editingRDP: RDPServer?
    @State private var editingURL: URLAccess?

    @State private var confirmDeleteClient: Client?
    @State private var confirmDeleteSSH: SSHServer?
    @State private var confirmDeleteRDP: RDPServer?
    @State private var confirmDeleteURL: URLAccess?

    @State private var showError = false
    @State private var alertTitle = "Erro"
    @State private var errorMessage = ""
    @State private var accessConnectivity: [String: ConnectivityState] = [:]
    @State private var isCheckingConnectivity = false
    @State private var lastConnectivityCheck: Date?
    @State private var connectivityTask: Task<Void, Never>?
    @State private var lastConnectivityRows: [AccessRow] = []
    @State private var connectivityProgressTotal = 0
    @State private var connectivityProgressDone = 0
    @State private var scanBannerMessage = ""
    @State private var showScanBanner = false

    @State private var scanStartedAt: Date?
    @State private var scanEndedAt: Date?
    @State private var scanDurationSeconds: TimeInterval?
    @State private var lastConnectivityButtonTapAt: Date?
    private struct ConnectivitySnapshot {
        let isOnline: Bool
        let checkedAt: Date
        let method: ConnectivityChecker.ProbeMethod
        let durationMs: Int
    }

    private struct ConnectivityEndpoint: Hashable {
        let kind: AccessKind
        let host: String
        let port: String
        let url: String
    }

    @State private var endpointConnectivityCache: [ConnectivityEndpoint: ConnectivitySnapshot] = [:]
    @State private var autoCheckTask: Task<Void, Never>?

    @State private var connectivityCache: [String: ConnectivitySnapshot] = [:]
    @State private var f1KeyMonitor: Any?
    @FocusState private var focusedSearchField: SearchField?

    var body: some View {
        dialogsLayer
            .overlay(shortcutActionsView.hidden())
            .overlay(alignment: .top) {
                if showScanBanner || isCheckingConnectivity {
                    scanStatusBanner
                        .padding(.top, 12)
                }
            }
    }

    private var selectedClient: Client? {
        guard let selectedClientId else { return nil }
        return store.clients.first { $0.id.caseInsensitiveCompare(selectedClientId) == .orderedSame }
    }

    private var filteredClients: [Client] {
        let localTerm = clientsSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let globalTerm = globalSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return store.clients.filter { client in
            let matchesLocal = localTerm.isEmpty || clientMatches(client, term: localTerm)
            let matchesGlobal = globalTerm.isEmpty || clientMatches(client, term: globalTerm) || allRows(for: client.id).contains(where: { rowMatches($0, term: globalTerm) })
            return matchesLocal && matchesGlobal
        }
    }

    private var allRowsForSelectedClient: [AccessRow] {
        guard let selectedClientId else { return [] }
        return allRows(for: selectedClientId)
    }

    private var isGlobalSearchActive: Bool {
        !globalSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func allRows(for clientId: String) -> [AccessRow] {
        let client = clientId.lowercased()
        let clientName = store.clients.first(where: { $0.id.lowercased() == client })?.name ?? clientId

        let sshRows = store.ssh.filter { $0.clientId.lowercased() == client }.map {
            AccessRow(id: $0.id, clientName: clientName, kind: .ssh, alias: $0.alias, name: $0.name, host: $0.host, port: "\($0.port)", user: $0.user, url: "", tags: $0.tags, notes: $0.notes, isFavorite: $0.isFavorite, openCount: $0.openCount, lastOpenedAt: $0.lastOpenedAt)
        }
        let rdpRows = store.rdp.filter { $0.clientId.lowercased() == client }.map {
            AccessRow(id: $0.id, clientName: clientName, kind: .rdp, alias: $0.alias, name: $0.name, host: $0.host, port: "\($0.port)", user: $0.user, url: "", tags: $0.tags, notes: $0.notes, isFavorite: $0.isFavorite, openCount: $0.openCount, lastOpenedAt: $0.lastOpenedAt)
        }
        let urlRows = store.urls.filter { $0.clientId.lowercased() == client }.map {
            AccessRow(id: $0.id, clientName: clientName, kind: .url, alias: $0.alias, name: $0.name, host: $0.host, port: "\($0.port)", user: "", url: "\($0.scheme)://\($0.host):\($0.port)\($0.path)", tags: $0.tags, notes: $0.notes, isFavorite: $0.isFavorite, openCount: $0.openCount, lastOpenedAt: $0.lastOpenedAt)
        }
        return sortRows(sshRows + rdpRows + urlRows)
    }

    private func sortRows(_ rows: [AccessRow]) -> [AccessRow] {
        rows.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite && !rhs.isFavorite
            }
            if lhs.clientName != rhs.clientName {
                return lhs.clientName.localizedCaseInsensitiveCompare(rhs.clientName) == .orderedAscending
            }
            if lhs.kind.rawValue == rhs.kind.rawValue {
                return lhs.alias.localizedCaseInsensitiveCompare(rhs.alias) == .orderedAscending
            }
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
    }

    private func sortRowsWithConnectivity(_ rows: [AccessRow]) -> [AccessRow] {
        rows.sorted { lhs, rhs in
            let ls = connectivityState(for: lhs.id)
            let rs = connectivityState(for: rhs.id)
            let lo = connectivityOrder(ls)
            let ro = connectivityOrder(rs)
            if lo != ro { return lo < ro }
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite && !rhs.isFavorite
            }
            if lhs.clientName != rhs.clientName {
                return lhs.clientName.localizedCaseInsensitiveCompare(rhs.clientName) == .orderedAscending
            }
            if lhs.kind.rawValue == rhs.kind.rawValue {
                return lhs.alias.localizedCaseInsensitiveCompare(rhs.alias) == .orderedAscending
            }
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
    }

    private func connectivityOrder(_ state: ConnectivityState) -> Int {
        switch state {
        case .offline:
            return 0
        case .checking:
            return 1
        case .unknown:
            return 2
        case .online:
            return 3
        }
    }

    private func matchesConnectivityFilter(_ row: AccessRow) -> Bool {
        let state = connectivityState(for: row.id)
        switch connectivityFilter {
        case .all:
            return true
        case .online:
            return state == .online
        case .offline:
            return state == .offline
        case .checking:
            return state == .checking
        case .unknown:
            return state == .unknown
        }
    }

    private var filteredRows: [AccessRow] {
        let localTerm = accessesSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let globalTerm = globalSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let sourceRows: [AccessRow]
        if isGlobalSearchActive {
            sourceRows = store.clients.flatMap { allRows(for: $0.id) }
        } else {
            sourceRows = allRowsForSelectedClient
        }

        let filtered = sourceRows.filter { row in
            let matchesLocal = localTerm.isEmpty || rowMatches(row, term: localTerm)
            let matchesGlobal = globalTerm.isEmpty || rowMatches(row, term: globalTerm)
            let matchesConn = matchesConnectivityFilter(row)
            return matchesLocal && matchesGlobal && matchesConn
        }

        return sortByConnectivityStatus ? sortRowsWithConnectivity(filtered) : sortRows(filtered)
    }

    private func clientMatches(_ client: Client, term: String) -> Bool {
        client.id.lowercased().contains(term) ||
        client.name.lowercased().contains(term) ||
        client.tags.lowercased().contains(term) ||
        client.notes.lowercased().contains(term)
    }

    private func rowMatches(_ row: AccessRow, term: String) -> Bool {
        row.clientName.lowercased().contains(term) ||
        row.alias.lowercased().contains(term) ||
        row.name.lowercased().contains(term) ||
        row.host.lowercased().contains(term) ||
        row.user.lowercased().contains(term) ||
        row.url.lowercased().contains(term) ||
        row.port.lowercased().contains(term) ||
        row.tags.lowercased().contains(term) ||
        row.notes.lowercased().contains(term)
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
        .onChange(of: selectedAccessId) { _ in
            scheduleAutoCheckIfNeeded()
        }
        .onChange(of: store.clients) { _ in
            if let selectedClientId,
               !store.clients.contains(where: { $0.id.caseInsensitiveCompare(selectedClientId) == .orderedSame }) {
                self.selectedClientId = store.clients.first?.id
            }
        }
        .onAppear {
            installF1KeyMonitorIfNeeded()
        }
        .onDisappear {
            removeF1KeyMonitor()
        }
    }

    private var dialogsLayer: some View {
        baseLayout
            .alert(alertTitle, isPresented: $showError) {
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
            .confirmationDialog("Checar conectividade", isPresented: $showConnectivityScopeChooser) {
                Button("Somente este cliente") {
                    checkSelectedClientConnectivity()
                }
                .keyboardShortcut(.defaultAction)

                Button("Todos os clientes") {
                    checkAllClientsConnectivity()
                }

                Button("Cancelar", role: .cancel) {}
                    .keyboardShortcut(.cancelAction)
            } message: {
                Text("Deseja checar conectividade apenas do cliente selecionado ou de todos os clientes?")
            }
            .sheet(isPresented: $showHelp) { helpSheet }
            .sheet(isPresented: $showAuditLog) { auditLogSheet }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    latestBackupName: store.latestBackupName() ?? "",
                    onRestoreLatestBackup: restoreLatestBackupFromSettings
                )
            }
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
                    store.logDeleteDecision(entityType: "client", entityName: client.name, confirmed: true)
                    do {
                        try store.deleteClientCascade(clientId: client.id)
                        selectedClientId = store.clients.first?.id
                        selectedAccessId = nil
                    } catch { showErr(error) }
                    confirmDeleteClient = nil
                }
                Button("Cancelar", role: .cancel) {
                    if let client = confirmDeleteClient {
                        store.logDeleteDecision(entityType: "client", entityName: client.name, confirmed: false)
                    }
                    confirmDeleteClient = nil
                }
            }
            .confirmationDialog("Apagar SSH?", isPresented: Binding(get: { confirmDeleteSSH != nil }, set: { if !$0 { confirmDeleteSSH = nil } })) {
                Button("Apagar", role: .destructive) {
                    guard let item = confirmDeleteSSH else { return }
                    store.logDeleteDecision(entityType: "access", entityName: item.alias, confirmed: true)
                    do {
                        try store.deleteSSH(id: item.id)
                        selectedAccessId = filteredRows.first?.id
                    } catch { showErr(error) }
                    confirmDeleteSSH = nil
                }
                Button("Cancelar", role: .cancel) {
                    if let item = confirmDeleteSSH {
                        store.logDeleteDecision(entityType: "access", entityName: item.alias, confirmed: false)
                    }
                    confirmDeleteSSH = nil
                }
            }
            .confirmationDialog("Apagar RDP?", isPresented: Binding(get: { confirmDeleteRDP != nil }, set: { if !$0 { confirmDeleteRDP = nil } })) {
                Button("Apagar", role: .destructive) {
                    guard let item = confirmDeleteRDP else { return }
                    store.logDeleteDecision(entityType: "access", entityName: item.alias, confirmed: true)
                    do {
                        try store.deleteRDP(id: item.id)
                        selectedAccessId = filteredRows.first?.id
                    } catch { showErr(error) }
                    confirmDeleteRDP = nil
                }
                Button("Cancelar", role: .cancel) {
                    if let item = confirmDeleteRDP {
                        store.logDeleteDecision(entityType: "access", entityName: item.alias, confirmed: false)
                    }
                    confirmDeleteRDP = nil
                }
            }
            .confirmationDialog("Apagar URL?", isPresented: Binding(get: { confirmDeleteURL != nil }, set: { if !$0 { confirmDeleteURL = nil } })) {
                Button("Apagar", role: .destructive) {
                    guard let item = confirmDeleteURL else { return }
                    store.logDeleteDecision(entityType: "access", entityName: item.alias, confirmed: true)
                    do {
                        try store.deleteURL(id: item.id)
                        selectedAccessId = filteredRows.first?.id
                    } catch { showErr(error) }
                    confirmDeleteURL = nil
                }
                Button("Cancelar", role: .cancel) {
                    if let item = confirmDeleteURL {
                        store.logDeleteDecision(entityType: "access", entityName: item.alias, confirmed: false)
                    }
                    confirmDeleteURL = nil
                }
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
                    store.logUIAction(action: "refresh", entityName: "Dados", details: "Atualização manual acionada")
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
                    store.logUIAction(action: "new_access_dialog_opened", entityName: selectedClient?.name ?? "cliente", details: "Origem=botão principal")
                    showAddAccessChooser = true
                } label: {
                    Label("Novo Acesso", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            HStack(spacing: 8) {
                Text("Exportar: ⇧⌘B")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Importar: ⇧⌘I")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Busca geral (cliente + acessos)...", text: $globalSearchText)
                .textFieldStyle(.roundedBorder)
                .focused($focusedSearchField, equals: .global)

            TextField("Buscar cliente...", text: $clientsSearchText)
                .textFieldStyle(.roundedBorder)
                .focused($focusedSearchField, equals: .clients)

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
                        Button("Novo Cliente") {
                            showAddClient = true
                        }
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
                Text(store.eventosPath).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
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
                    Text("Conexões SSH, RDP e URL")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Ajuda") {
                    store.logHelpOpened()
                    showHelp = true
                }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("/", modifiers: [.command])
            }

            if selectedClient == nil && !isGlobalSearchActive {
                Text("Selecione um cliente para visualizar os acessos.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                VStack(spacing: 10) {
                    HStack {
                        TextField("Buscar acesso...", text: $accessesSearchText)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedSearchField, equals: .accesses)
                        Text("\(filteredRows.count) acessos")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Picker("Filtro", selection: $connectivityFilter) {
                            ForEach(ConnectivityFilter.allCases, id: \ .self) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Ordenar por status", isOn: $sortByConnectivityStatus)
                            .toggleStyle(.switch)

                        Spacer()
                    }

                    HStack(spacing: 8) {
                        Button("Abrir") { openSelectedAccess() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                            .disabled(selectedAccessRow == nil)
                        Button {
                            // Debounce to avoid opening the scope chooser multiple times on double clicks / key repeat.
                            let now = Date()
                            if let last = lastConnectivityButtonTapAt, now.timeIntervalSince(last) < 0.6 {
                                return
                            }
                            lastConnectivityButtonTapAt = now
                            showConnectivityScopeChooser = true
                        } label: {
                            Label(isCheckingConnectivity ? "Checando..." : "Checar Conectividade", systemImage: "wave.3.right")
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut("k", modifiers: [.command, .shift])
                        .disabled(isCheckingConnectivity || selectedClient == nil || allRowsForSelectedClient.isEmpty)
                        Button {
                            checkSelectedAccessConnectivity()
                        } label: {
                            Label("Checar Selecionado", systemImage: "dot.radiowaves.left.and.right")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isCheckingConnectivity || selectedAccessRow == nil)
                        Button("Cancelar") {
                            cancelConnectivityCheck()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!isCheckingConnectivity)
                        Button("Editar") { editSelectedAccess() }
                            .buttonStyle(.bordered)
                            .keyboardShortcut("e", modifiers: [.command])
                            .disabled(selectedAccessRow == nil)
                        Button(selectedAccessRow?.isFavorite == true ? "Desfavoritar" : "Favoritar") {
                            toggleFavoriteSelectedAccess()
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedAccessRow == nil)
                        Button("Excluir", role: .destructive) { deleteSelectedAccess() }
                            .buttonStyle(.bordered)
                            .keyboardShortcut(.delete, modifiers: [])
                            .disabled(selectedAccessRow == nil)
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .buttonStyle(.bordered)
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

                    if isCheckingConnectivity {
                        HStack(spacing: 10) {
                            ProgressView(value: Double(connectivityProgressDone), total: Double(max(connectivityProgressTotal, 1)))
                                .frame(maxWidth: 260)
                            let total = max(connectivityProgressTotal, 1)
                            let done = max(0, min(connectivityProgressDone, total))
                            let percent = Int((Double(done) / Double(total)) * 100.0)

                            Text("\(done)/\(connectivityProgressTotal) — \(percent)%")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let scanStartedAt, done > 0 {
                                let elapsed = Date().timeIntervalSince(scanStartedAt)
                                let perItem = elapsed / Double(done)
                                let remaining = max(0, perItem * Double(total - done))
                                Text("ETA ~ \(formatDuration(seconds: remaining))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        if let scanStartedAt {
                            HStack {
                                Text("Início: \(scanStartedAt.formatted(date: .omitted, time: .standard))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    } else if let scanStartedAt, let scanEndedAt, let scanDurationSeconds {
                        HStack {
                            Text("Última varredura: início \(scanStartedAt.formatted(date: .omitted, time: .standard)) — fim \(scanEndedAt.formatted(date: .omitted, time: .standard)) — duração \(formatDuration(seconds: scanDurationSeconds))")
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
                                    Button("Novo Acesso") {
                                        guard selectedClient != nil else {
                                            showErrText("Selecione um cliente antes de criar um acesso.")
                                            return
                                        }
                                        store.logUIAction(action: "new_access_dialog_opened", entityName: selectedClient?.name ?? "cliente", details: "Origem=context menu acesso")
                                        showAddAccessChooser = true
                                    }
                                    Divider()
                                    Button("Abrir") { open(row: row) }
                                    Button("Checar este acesso") { checkSingleAccessConnectivity(row: row) }
                                    Button(row.isFavorite ? "Desfavoritar" : "Favoritar") { toggleFavorite(row: row) }
                                    Button("Clonar") { clone(row: row) }
                                    Button("Editar") { edit(row: row) }
                                    Button("Excluir", role: .destructive) { delete(row: row) }
                                }
                                .onTapGesture(count: 2) {
                                    open(row: row)
                                }
                        }
                    }
                    .contextMenu {
                        Button("Novo Acesso") {
                            guard selectedClient != nil else {
                                showErrText("Selecione um cliente antes de criar um acesso.")
                                return
                            }
                            store.logUIAction(action: "new_access_dialog_opened", entityName: selectedClient?.name ?? "cliente", details: "Origem=context menu grid acessos")
                            showAddAccessChooser = true
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
            Text("Checado").frame(width: 70, alignment: .leading)
            Text("Tipo").frame(width: 60, alignment: .leading)
            Text("Alias").frame(maxWidth: .infinity, alignment: .leading)
            Text("Host").frame(maxWidth: .infinity, alignment: .leading)
            Text("Porta").frame(width: 60, alignment: .leading)
            Text("Usuário/URL").frame(maxWidth: .infinity, alignment: .leading)
            Text("Método").frame(width: 60, alignment: .leading)
            Text("ms").frame(width: 50, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func accessRowView(_ row: AccessRow) -> some View {
        HStack {
            connectivityIndicator(for: connectivityState(for: row.id), size: 10)
                .frame(width: 54, alignment: .leading)

            Text(lastCheckedLabel(for: row.id))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(row.kind.rawValue).frame(width: 60, alignment: .leading)
            HStack(spacing: 6) {
                if row.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
                Text(row.alias)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.host).frame(maxWidth: .infinity, alignment: .leading)
            Text(row.port).frame(width: 60, alignment: .leading)
            Text(row.kind == .url ? row.url : row.user)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(connectivityMethodLabel(for: row.id))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(connectivityLatencyLabel(for: row.id))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }

    private func lastCheckedLabel(for accessId: String) -> String {
        guard let snap = connectivityCache[accessId] else { return "-" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "HH:mm"
        return df.string(from: snap.checkedAt)
    }

    private func connectivityMethodLabel(for accessId: String) -> String {
        guard let snap = connectivityCache[accessId] else { return "-" }
        return snap.method.rawValue
    }

    private func connectivityLatencyLabel(for accessId: String) -> String {
        guard let snap = connectivityCache[accessId] else { return "-" }
        return "\(max(0, snap.durationMs))"
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

    private func toggleFavoriteSelectedAccess() {
        guard let row = selectedAccessRow else { return }
        toggleFavorite(row: row)
    }

    private func cloneSelectedAccess() {
        guard let row = selectedAccessRow else { return }
        clone(row: row)
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
            URLLauncher.openURL(scheme: access.scheme, host: access.host, port: access.port, path: access.path)
        }

        do {
            try store.markAccessOpened(kind: row.kind, id: row.id)
            selectedAccessId = row.id
            logs.reload()
        } catch {
            showErr(error)
        }
    }

    private func toggleFavorite(row: AccessRow) {
        do {
            _ = try store.toggleFavorite(kind: row.kind, id: row.id)
            selectedAccessId = row.id
            logs.reload()
        } catch {
            showErr(error)
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
                store.logCloneEvent(sourceAlias: access.alias, newAlias: alias, kind: .ssh)
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
                store.logCloneEvent(sourceAlias: access.alias, newAlias: alias, kind: .rdp)
            case .url:
                guard let access = store.urls.first(where: { $0.id == row.id }) else { return }
                let alias = makeCloneAlias(base: access.alias, kind: .url, clientId: access.clientId)
                try store.addURL(.init(
                    alias: alias,
                    clientId: access.clientId,
                    name: access.name,
                    scheme: access.scheme,
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
                store.logCloneEvent(sourceAlias: access.alias, newAlias: alias, kind: .url)
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

    private func exportCSVs() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Exportar"
        panel.message = "Escolha a pasta de destino para exportar clientes.csv, acessos.csv e eventos.csv."

        guard panel.runModal() == .OK, let directoryURL = panel.url else { return }

        let fm = FileManager.default
        let targets = [
            directoryURL.appendingPathComponent("clientes.csv"),
            directoryURL.appendingPathComponent("acessos.csv"),
            directoryURL.appendingPathComponent("eventos.csv")
        ]
        let existing = targets.filter { fm.fileExists(atPath: $0.path) }
        if !existing.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Sobrescrever arquivos existentes?"
            alert.informativeText = "Já existem arquivos CSV na pasta de destino. Deseja sobrescrever?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Sobrescrever")
            alert.addButton(withTitle: "Cancelar")
            if alert.runModal() != .alertFirstButtonReturn {
                return
            }
        }

        do {
            try store.exportCSVs(to: directoryURL)
            showInfoText("Exportação concluída em: \(directoryURL.path)")
        } catch {
            showErr(error)
        }
    }

    private func importCSVs() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = true
        panel.prompt = "Importar"
        panel.message = "Selecione clientes.csv e acessos.csv (eventos.csv é opcional)."

        guard panel.runModal() == .OK else { return }

        do {
            let preview = try store.previewImportCSVs(from: panel.urls)
            let alert = NSAlert()
            alert.messageText = preview.hasErrors ? "Prévia de importação — erros" : "Prévia de importação"
            alert.informativeText = preview.report
            alert.alertStyle = preview.hasErrors ? .critical : .informational

            if preview.hasErrors {
                alert.addButton(withTitle: "OK")
                _ = alert.runModal()
                return
            }

            alert.addButton(withTitle: "Importar")
            alert.addButton(withTitle: "Cancelar")
            if alert.runModal() != .alertFirstButtonReturn {
                store.logUIAction(action: "import_cancelled", entityName: "Importação", details: "Cancelado após prévia")
                return
            }

            try store.importCSVs(from: panel.urls)
            logs.reload()
            showScanBanner = true
            scanBannerMessage = "Importação concluída com sucesso."
        } catch {
            showErr(error)
        }
    }

    private func restoreLatestBackupFromSettings() {
        let alert = NSAlert()
        alert.messageText = "Restaurar último backup?"
        alert.informativeText = "Isso vai substituir clientes.csv/acessos.csv/eventos.csv pelos arquivos do último backup disponível."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Restaurar")
        alert.addButton(withTitle: "Cancelar")
        if alert.runModal() != .alertFirstButtonReturn {
            store.logUIAction(action: "restore_backup_cancelled", entityName: "Backups", details: "Cancelado na confirmação")
            return
        }

        do {
            try store.restoreLatestBackup()
            logs.reload()
            showScanBanner = true
            scanBannerMessage = "Backup restaurado com sucesso."
            store.logUIAction(action: "restore_backup", entityName: "Backups", details: "Restaurado: \(store.latestBackupName() ?? "")")
        } catch {
            showErr(error)
        }
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
                        Text("⌘K  — Focar busca global")
                        Text("⌘F  — Focar busca de clientes")
                        Text("⇧⌘F — Focar busca de acessos")
                        Text("⌘L  — Limpar buscas")
                        Text("⌘N  — Novo Cliente")
                        Text("⇧⌘N — Novo Acesso")
                        Text("⇧⌘D — Clonar acesso selecionado")
                        Text("⇧⌘K — Checar conectividade")
                        Text("⇧⌘B — Exportar CSVs")
                        Text("⇧⌘I — Importar CSVs")
                        Text("⌥⌘J — Exibir auditoria de eventos")
                        Text("↩︎   — Abrir acesso selecionado")
                        Text("⌘E  — Editar acesso selecionado")
                        Text("Botão Favoritar — alterna favorito do acesso selecionado")
                        Text("⌫   — Excluir acesso selecionado")
                        Text("⌘/ ou F1 — Abrir Ajuda")
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
                    Text("Eventos: \(store.eventosPath)")
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

    private var auditLogSheet: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    TextField("Buscar (ação, entidade, detalhes)...", text: $auditSearchText)
                        .textFieldStyle(.roundedBorder)
                    Picker("Ação", selection: $auditActionFilter) {
                        ForEach(auditActions, id: \ .self) { Text($0).tag($0) }
                    }
                    .frame(width: 180)
                    Picker("Entidade", selection: $auditEntityFilter) {
                        ForEach(auditEntities, id: \ .self) { Text($0).tag($0) }
                    }
                    .frame(width: 180)
                }

                HStack {
                    Text("Integridade: \(auditIntegrityStatus.rawValue)")
                        .font(.caption)
                        .foregroundStyle(auditIntegrityStatus == .ok ? .green : (auditIntegrityStatus == .missing ? .secondary : .red))
                    Spacer()
                    Text("Arquivo: \(store.eventosPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Divider()

                ScrollView {
                    Text(auditLogText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(isVerifyingAuditIntegrity ? "Verificando..." : "Verificar integridade") {
                        verifyAuditIntegrity()
                    }
                    .disabled(isVerifyingAuditIntegrity)
                }
                ToolbarItem(placement: .automatic) {
                    Button("Fechar") { showAuditLog = false }
                }
            }
            .onAppear {
                loadAuditEvents()
                refreshAuditPresentation()
                verifyAuditIntegrity()
            }
            .onChange(of: auditSearchText) { _ in refreshAuditPresentation() }
            .onChange(of: auditActionFilter) { _ in refreshAuditPresentation() }
            .onChange(of: auditEntityFilter) { _ in refreshAuditPresentation() }
        }
        .presentationDetents([.large])
    }

    private var shortcutActionsView: some View {
        VStack {
            Button(action: focusGlobalSearch) { EmptyView() }
                .keyboardShortcut("k", modifiers: [.command])
            Button(action: focusClientsSearch) { EmptyView() }
                .keyboardShortcut("f", modifiers: [.command])
            Button(action: focusAccessesSearch) { EmptyView() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            Button(action: clearSearches) { EmptyView() }
                .keyboardShortcut("l", modifiers: [.command])
            Button(action: cloneSelectedAccess) { EmptyView() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button(action: exportCSVs) { EmptyView() }
                .keyboardShortcut("b", modifiers: [.command, .shift])
            Button(action: importCSVs) { EmptyView() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            Button(action: openAuditLog) { EmptyView() }
                .keyboardShortcut("j", modifiers: [.command, .option])
        }
    }

    private func focusGlobalSearch() {
        focusedSearchField = .global
    }

    private func focusClientsSearch() {
        focusedSearchField = .clients
    }

    private func focusAccessesSearch() {
        focusedSearchField = .accesses
    }

    private func clearSearches() {
        globalSearchText = ""
        clientsSearchText = ""
        accessesSearchText = ""
        store.logUIAction(action: "clear_searches", entityName: "Busca", details: "Campos de busca limpos")
    }

    private func openAuditLog() {
        loadAuditEvents()
        refreshAuditPresentation()
        verifyAuditIntegrity()
        store.logUIAction(action: "audit_log_opened", entityName: "Auditoria", details: "Visualização de eventos aberta")
        showAuditLog = true
    }

    private func installF1KeyMonitorIfNeeded() {
        guard f1KeyMonitor == nil else { return }
        f1KeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 122 {
                store.logHelpOpened()
                showHelp = true
                return nil
            }
            return event
        }
    }

    private func removeF1KeyMonitor() {
        guard let f1KeyMonitor else { return }
        NSEvent.removeMonitor(f1KeyMonitor)
        self.f1KeyMonitor = nil
    }

    private struct AuditEvent {
        let timestampRaw: String
        let timestamp: Date?
        let action: String
        let entityType: String
        let entityName: String
        let details: String
    }

    private func loadAuditEvents() {
        let url = URL(fileURLWithPath: store.eventosPath)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            auditLogText = "LOG DE EVENTOS\n\nNenhum arquivo de eventos encontrado em:\n\(store.eventosPath)"
            auditEvents = []
            auditActions = ["Todos"]
            auditEntities = ["Todos"]
            return
        }

        let lines = content.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count > 1 else {
            auditLogText = "LOG DE EVENTOS\n\nArquivo vazio: \(store.eventosPath)"
            auditEvents = []
            auditActions = ["Todos"]
            auditEntities = ["Todos"]
            return
        }

        let header = splitCSV(lines[0])
        let map = makeColumnMap(header)
        let tsIdx = findColumn(map, aliases: ["timestamputc"]) ?? 0
        let actionIdx = findColumn(map, aliases: ["action"]) ?? 1
        let entityTypeIdx = findColumn(map, aliases: ["entitytype"]) ?? 2
        let entityNameIdx = findColumn(map, aliases: ["entityname"]) ?? 3
        let detailsIdx = findColumn(map, aliases: ["details"]) ?? 4

        let events = lines.dropFirst().map { line -> AuditEvent in
            let cells = splitCSV(line)
            let timestampRaw = cell(cells, at: tsIdx)
            return AuditEvent(
                timestampRaw: timestampRaw,
                timestamp: parseEventDate(timestampRaw),
                action: cell(cells, at: actionIdx),
                entityType: cell(cells, at: entityTypeIdx),
                entityName: cell(cells, at: entityNameIdx),
                details: cell(cells, at: detailsIdx)
            )
        }
        .sorted { lhs, rhs in
            (lhs.timestamp ?? .distantPast) > (rhs.timestamp ?? .distantPast)
        }

        auditEvents = events

        let actionSet = Set(events.map { $0.action }.filter { !$0.isEmpty })
        auditActions = ["Todos"] + actionSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        let entitySet = Set(events.map { $0.entityType }.filter { !$0.isEmpty })
        auditEntities = ["Todos"] + entitySet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        if !auditActions.contains(auditActionFilter) { auditActionFilter = "Todos" }
        if !auditEntities.contains(auditEntityFilter) { auditEntityFilter = "Todos" }
    }

    private func refreshAuditPresentation() {
        guard !auditEvents.isEmpty else {
            return
        }

        let term = auditSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = auditEvents.filter { ev in
            let matchesAction = auditActionFilter == "Todos" || ev.action.caseInsensitiveCompare(auditActionFilter) == .orderedSame
            let matchesEntity = auditEntityFilter == "Todos" || ev.entityType.caseInsensitiveCompare(auditEntityFilter) == .orderedSame
            let matchesTerm: Bool
            if term.isEmpty {
                matchesTerm = true
            } else {
                matchesTerm = ev.action.lowercased().contains(term)
                    || ev.entityType.lowercased().contains(term)
                    || ev.entityName.lowercased().contains(term)
                    || ev.details.lowercased().contains(term)
                    || ev.timestampRaw.lowercased().contains(term)
            }
            return matchesAction && matchesEntity && matchesTerm
        }

        let recent = Array(filtered.prefix(120))
        let recentOpen = Array(recent.filter { $0.action.caseInsensitiveCompare("open") == .orderedSame }.prefix(40))

        let outputDate = DateFormatter()
        outputDate.locale = Locale(identifier: "pt_BR")
        outputDate.dateFormat = "dd/MM HH:mm:ss"

        var report: [String] = []
        report.append("LOG DE EVENTOS (últimos 120)")
        report.append("════════════════════════════════════════════")
        report.append("")
        report.append("ÚLTIMOS ACESSOS:")

        if recentOpen.isEmpty {
            report.append("- Nenhum acesso recente registrado.")
        } else {
            for item in recentOpen {
                let when = item.timestamp.map { outputDate.string(from: $0) } ?? item.timestampRaw
                report.append("- \(when) | \(item.entityName) | \(item.details)")
            }
        }

        report.append("")
        report.append("EVENTOS GERAIS:")

        if recent.isEmpty {
            report.append("- Nenhum evento registrado.")
        } else {
            for item in recent {
                let when = item.timestamp.map { outputDate.string(from: $0) } ?? item.timestampRaw
                report.append("- \(when) | \(item.action) | \(item.entityType) | \(item.entityName) | \(item.details)")
            }
        }

        if recent.isEmpty {
            report.append("")
            report.append("(sem resultados para os filtros atuais)")
        }

        report.append("")
        report.append("Arquivo: \(store.eventosPath)")
        auditLogText = report.joined(separator: "\n")
    }

    private func verifyAuditIntegrity() {
        guard !isVerifyingAuditIntegrity else { return }
        isVerifyingAuditIntegrity = true

        let eventsURL = URL(fileURLWithPath: store.eventosPath)
        Task(priority: .utility) {
            let status = EventLogger.verifyIntegrity(eventsURL: eventsURL)
            await MainActor.run {
                auditIntegrityStatus = status
                isVerifyingAuditIntegrity = false
            }
        }
    }

    private func parseEventDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
        return formatter.date(from: value)
    }

    private func splitCSV(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var isQuoted = false
        let chars = Array(line)
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if char == "\"" {
                if isQuoted && index + 1 < chars.count && chars[index + 1] == "\"" {
                    current.append("\"")
                    index += 1
                } else {
                    isQuoted.toggle()
                }
            } else if char == "," && !isQuoted {
                values.append(current)
                current = ""
            } else {
                current.append(char)
            }
            index += 1
        }
        values.append(current)
        return values
    }

    private func makeColumnMap(_ columns: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (index, raw) in columns.enumerated() {
            map[normalizeHeader(raw)] = index
        }
        return map
    }

    private func findColumn(_ map: [String: Int], aliases: [String]) -> Int? {
        for alias in aliases {
            if let idx = map[normalizeHeader(alias)] {
                return idx
            }
        }
        return nil
    }

    private func normalizeHeader(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    private func cell(_ values: [String], at index: Int) -> String {
        guard values.indices.contains(index) else { return "" }
        return values[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func showErr(_ error: Error) {
        showErrText(error.localizedDescription)
    }

    private func showErrText(_ message: String) {
        alertTitle = "Erro"
        errorMessage = message
        showError = true
    }

    private func showInfoText(_ message: String) {
        alertTitle = "Informação"
        errorMessage = message
        showError = true
    }

    private func checkSelectedClientConnectivity() {
        let rows = allRowsForSelectedClient
        guard !rows.isEmpty else { return }

        guard !isCheckingConnectivity else {
            showInfoText("Já existe uma varredura de conectividade em andamento.")
            return
        }

        if let selectedClient {
            store.logConnectivityCheck(scope: "cliente:\(selectedClient.name)", rowCount: rows.count)
            performConnectivityCheck(rows: rows, scopeName: "cliente \(selectedClient.name)")
        } else {
            store.logConnectivityCheck(scope: "cliente", rowCount: rows.count)
            performConnectivityCheck(rows: rows, scopeName: "cliente selecionado")
        }
    }

    private func checkAllClientsConnectivity() {
        let rows = store.clients.flatMap { allRows(for: $0.id) }
        guard !rows.isEmpty else { return }

        guard !isCheckingConnectivity else {
            showInfoText("Já existe uma varredura de conectividade em andamento.")
            return
        }

        store.logConnectivityCheck(scope: "todos", rowCount: rows.count)
        performConnectivityCheck(rows: rows, scopeName: "todos os clientes")
    }

    private func checkSingleAccessConnectivity(row: AccessRow) {
        guard !isCheckingConnectivity else {
            showInfoText("Já existe uma varredura de conectividade em andamento.")
            return
        }
        store.logConnectivityCheck(scope: "acesso:\(row.alias)", rowCount: 1)
        performConnectivityCheck(rows: [row], scopeName: "acesso \(row.alias)")
    }

    private func checkSelectedAccessConnectivity() {
        guard let row = selectedAccessRow else { return }
        checkSingleAccessConnectivity(row: row)
    }

    private func scheduleAutoCheckIfNeeded() {
        autoCheckTask?.cancel()
        guard autoCheckOnSelect else { return }
        guard !isCheckingConnectivity else { return }
        guard selectedAccessRow != nil else { return }

        let delayMs = max(0, min(autoCheckDebounceMs, 10_000))
        autoCheckTask = Task(priority: .utility) {
            if delayMs > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            }
            if Task.isCancelled { return }
            await MainActor.run {
                // Re-check current selection (may have changed).
                guard autoCheckOnSelect else { return }
                guard !isCheckingConnectivity else { return }
                guard let current = selectedAccessRow else { return }
                checkSingleAccessConnectivity(row: current)
            }
        }
    }

    private func performConnectivityCheck(rows: [AccessRow], scopeName: String) {
        guard !rows.isEmpty else { return }

        isCheckingConnectivity = true
        scanStartedAt = Date()
        scanEndedAt = nil
        scanDurationSeconds = nil
        lastConnectivityRows = rows
        connectivityProgressTotal = rows.count
        connectivityProgressDone = 0
        for row in rows {
            accessConnectivity[row.id] = .checking
        }

        let startMessage: String
        if ConnectivityChecker.hasNmap {
            startMessage = "Checando \(scopeName) em background. nmap: \(ConnectivityChecker.nmapPathDescription)"
        } else {
            startMessage = "Checando \(scopeName) em background. nmap não encontrado (\(ConnectivityChecker.nmapPathDescription)) — usando TCP nativo"
        }

        let ttl = max(0, connectivityCacheTTLSeconds)
        let now = Date()

        func endpoint(for row: AccessRow) -> ConnectivityEndpoint {
            ConnectivityEndpoint(
                kind: row.kind,
                host: row.host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                port: row.port.trimmingCharacters(in: .whitespacesAndNewlines),
                url: row.url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            )
        }

        var cachedDone = 0
        var toCheck: [AccessRow] = []
        for row in rows {
            if ttl > 0, let cached = connectivityCache[row.id], now.timeIntervalSince(cached.checkedAt) <= ttl {
                accessConnectivity[row.id] = cached.isOnline ? .online : .offline
                cachedDone += 1
                continue
            }

            let ep = endpoint(for: row)
            if ttl > 0, let cachedEP = endpointConnectivityCache[ep], now.timeIntervalSince(cachedEP.checkedAt) <= ttl {
                accessConnectivity[row.id] = cachedEP.isOnline ? .online : .offline
                connectivityCache[row.id] = cachedEP
                cachedDone += 1
                continue
            }

            toCheck.append(row)
        }

        // Deduplicate checks by endpoint so we don't probe the same target many times.
        var endpointToIds: [ConnectivityEndpoint: [String]] = [:]
        for row in toCheck {
            endpointToIds[endpoint(for: row), default: []].append(row.id)
        }

        // Represent each endpoint as a single synthetic row to check.
        var endpointToIdsByKey: [String: [String]] = [:]
        var endpointByKey: [String: ConnectivityEndpoint] = [:]
        let endpointRows: [AccessRow] = endpointToIds.map { (endpoint, ids) in
            let key = endpointKey(endpoint)
            endpointToIdsByKey[key] = ids
            endpointByKey[key] = endpoint
            let any = toCheck.first(where: { $0.id == ids.first }) ?? toCheck[0]
            return AccessRow(
                id: key,
                clientName: any.clientName,
                kind: endpoint.kind,
                alias: any.alias,
                name: any.name,
                host: endpoint.host,
                port: endpoint.port,
                user: any.user,
                url: endpoint.url,
                tags: any.tags,
                notes: any.notes,
                isFavorite: any.isFavorite,
                openCount: any.openCount,
                lastOpenedAt: any.lastOpenedAt
            )
        }

        connectivityProgressTotal = max(0, cachedDone + endpointToIds.count)
        connectivityProgressDone = cachedDone

        scanBannerMessage = "\(startMessage) — \(connectivityProgressDone)/\(connectivityProgressTotal)"
        showScanBanner = true

        connectivityTask?.cancel()
        connectivityTask = Task(priority: .utility) {
            let timeout = max(0.5, min(connectivityTimeoutSeconds, 60.0))
            let concurrency = max(1, min(connectivityMaxConcurrency, 128))
            let fallbackPorts = parsePortsCSV(urlFallbackPortsCSV, fallback: [443, 80, 8443, 8080, 9443])

            let results = await ConnectivityChecker.checkAll(
                rows: endpointRows,
                timeout: timeout,
                maxConcurrency: concurrency,
                urlFallbackPorts: fallbackPorts
            ) { endpointId, result in
                Task { @MainActor in
                    for originalId in endpointToIdsByKey[endpointId] ?? [] {
                        accessConnectivity[originalId] = result.isOnline ? .online : .offline
                        let snap = ConnectivitySnapshot(isOnline: result.isOnline, checkedAt: result.checkedAt, method: result.method, durationMs: result.durationMs)
                        connectivityCache[originalId] = snap
                    }

                    // Update endpoint cache as well.
                    if let endpoint = endpointByKey[endpointId] {
                        endpointConnectivityCache[endpoint] = ConnectivitySnapshot(isOnline: result.isOnline, checkedAt: result.checkedAt, method: result.method, durationMs: result.durationMs)
                    }
                    connectivityProgressDone += 1
                    scanBannerMessage = "\(startMessage) — \(connectivityProgressDone)/\(connectivityProgressTotal)"
                }
            }

            if Task.isCancelled {
                await MainActor.run {
                    isCheckingConnectivity = false
                    scanEndedAt = Date()
                    if let started = scanStartedAt, let ended = scanEndedAt {
                        scanDurationSeconds = max(0, ended.timeIntervalSince(started))
                    }
                    scanBannerMessage = "Varredura cancelada (\(scopeName))."
                    showScanBanner = true
                }
                return
            }

            await MainActor.run {
                for (endpoint, originalIds) in endpointToIds {
                    let key = endpointKey(endpoint)
                    let result = results[key]
                    let isOnline = result?.isOnline == true
                    for originalId in originalIds {
                        accessConnectivity[originalId] = isOnline ? .online : .offline
                        if let result {
                            let snap = ConnectivitySnapshot(isOnline: result.isOnline, checkedAt: result.checkedAt, method: result.method, durationMs: result.durationMs)
                            connectivityCache[originalId] = snap
                            endpointConnectivityCache[endpoint] = snap
                        }
                    }
                }
                lastConnectivityCheck = Date()
                isCheckingConnectivity = false
                scanEndedAt = Date()
                if let started = scanStartedAt, let ended = scanEndedAt {
                    scanDurationSeconds = max(0, ended.timeIntervalSince(started))
                }
                let onlineCount = rows.filter { connectivityState(for: $0.id) == .online }.count
                let offlineCount = rows.count - onlineCount
                scanBannerMessage = "Concluído (\(scopeName)): \(onlineCount) online, \(offlineCount) offline."
                showScanBanner = true
                store.logUIAction(action: "check_connectivity_completed", entityName: "Conectividade", details: "Escopo=\(scopeName); Online=\(onlineCount); Offline=\(offlineCount)")
            }
        }
    }

    private func endpointKey(_ endpoint: ConnectivityEndpoint) -> String {
        // Stable synthetic id used only during scans.
        return "ep|\(endpoint.kind.rawValue)|\(endpoint.host)|\(endpoint.port)|\(endpoint.url)"
    }

    private func cancelConnectivityCheck() {
        guard isCheckingConnectivity else { return }
        connectivityTask?.cancel()
        isCheckingConnectivity = false
        scanEndedAt = Date()
        if let started = scanStartedAt, let ended = scanEndedAt {
            scanDurationSeconds = max(0, ended.timeIntervalSince(started))
        }
        for row in lastConnectivityRows where accessConnectivity[row.id] == .checking {
            accessConnectivity[row.id] = .unknown
        }
        scanBannerMessage = "Varredura cancelada pelo usuário."
        showScanBanner = true
        store.logUIAction(action: "check_connectivity_cancelled", entityName: "Conectividade", details: "Varredura cancelada manualmente")
    }

    private func formatDuration(seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        if m > 99 {
            return "99:59+"
        }
        return String(format: "%02d:%02d", m, s)
    }

    private var scanStatusBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: isCheckingConnectivity ? "wave.3.right.circle.fill" : "checkmark.seal.fill")
                .foregroundStyle(isCheckingConnectivity ? .yellow : .green)
            Text(scanBannerMessage)
                .font(.caption)
                .lineLimit(2)
            Spacer(minLength: 8)
            if !isCheckingConnectivity {
                Button("Fechar") {
                    showScanBanner = false
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 900)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 6)
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