import Foundation
import Combine

final class CSVStore: ObservableObject {
    static let dataDirectoryURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/MenuProUI", isDirectory: true)
    }()

    @Published var clients: [Client] = []
    @Published var ssh: [SSHServer] = []
    @Published var rdp: [RDPServer] = []
    @Published var urls: [URLAccess] = []

    private let loggingEnabled = true

    private let clientsURL: URL
    private let accessesURL: URL

    var clientsPath: String { clientsURL.path }
    var acessosPath: String { accessesURL.path }

    init() {
        clientsURL = Self.dataDirectoryURL.appendingPathComponent("clientes.csv")
        accessesURL = Self.dataDirectoryURL.appendingPathComponent("acessos.csv")
        try? FileManager.default.createDirectory(at: Self.dataDirectoryURL, withIntermediateDirectories: true)
        ensureFile(clientsURL, header: "Id,Nome,Observacoes,CriadoEm,AtualizadoEm")
        ensureFile(accessesURL, header: "Id,ClientId,Tipo,Apelido,Host,Porta,Usuario,Dominio,RdpIgnoreCert,RdpFullScreen,RdpDynamicResolution,RdpWidth,RdpHeight,Url,Observacoes,CriadoEm,AtualizadoEm")
        migrateAccessesIfNeeded()
        reload()
    }

    func reload() {
        let rows = loadAccessRows()
        if loggingEnabled { print("[CSVStore] Loaded accesses: \(rows.count)") }
        clients = loadClientRows().map { Client(id: $0.id, name: $0.name, tags: $0.tags, notes: $0.notes) }
        ssh = rows
            .filter { $0.kind == .ssh }
            .map {
                SSHServer(
                    id: $0.id,
                    alias: $0.alias,
                    clientId: $0.clientId,
                    name: $0.name,
                    host: $0.host,
                    port: $0.port,
                    user: $0.user,
                    tags: $0.tags,
                    notes: $0.notes
                )
            }
        rdp = rows
            .filter { $0.kind == .rdp }
            .map {
                RDPServer(
                    id: $0.id,
                    alias: $0.alias,
                    clientId: $0.clientId,
                    name: $0.name,
                    host: $0.host,
                    port: $0.port,
                    domain: $0.domain,
                    user: $0.user,
                    tags: $0.tags,
                    ignoreCert: $0.rdpIgnoreCert,
                    fullScreen: $0.rdpFullScreen,
                    dynamicResolution: $0.rdpDynamicResolution,
                    width: $0.rdpWidth,
                    height: $0.rdpHeight,
                    notes: $0.notes
                )
            }
        urls = rows
            .filter { $0.kind == .url }
            .map {
                URLAccess(
                    id: $0.id,
                    alias: $0.alias,
                    clientId: $0.clientId,
                    name: $0.name,
                    host: $0.host,
                    port: $0.port,
                    path: $0.path,
                    tags: $0.tags,
                    notes: $0.notes
                )
            }
    }

    func addClient(id: String, name: String, tags: String, notes: String) throws {
        var rows = loadClientRows()
        let now = nowTimestamp()
        rows.append(ClientRow(id: id.isEmpty ? UUID().uuidString : id, name: name, tags: tags, notes: notes, createdAt: now, updatedAt: now))
        try saveClientRows(rows)
        reload()
    }

    func updateClient(_ updated: Client) throws {
        var rows = loadClientRows()
        guard let idx = rows.firstIndex(where: { $0.id.caseInsensitiveCompare(updated.id) == .orderedSame }) else { return }
        rows[idx].name = updated.name
        rows[idx].tags = updated.tags
        rows[idx].notes = updated.notes
        try saveClientRows(rows)
        reload()
    }

    func deleteClientCascade(clientId: String) throws {
        var clientRows = loadClientRows()
        clientRows.removeAll { $0.id.caseInsensitiveCompare(clientId) == .orderedSame }
        try saveClientRows(clientRows)

        var accessRows = loadAccessRows()
        accessRows.removeAll { $0.clientId.caseInsensitiveCompare(clientId) == .orderedSame }
        try saveAccessRows(accessRows)
        reload()
    }

    func addSSH(alias: String, clientId: String, name: String, host: String, port: Int, user: String, tags: String, notes: String) throws {
        var rows = loadAccessRows()
        rows.append(
            AccessRowStored(
                id: UUID().uuidString,
                clientId: clientId,
                kind: .ssh,
                alias: alias,
                name: name,
                host: host,
                port: sanitizePort(port, fallback: 22),
                user: user,
                domain: "",
                rdpIgnoreCert: true,
                rdpFullScreen: false,
                rdpDynamicResolution: true,
                rdpWidth: nil,
                rdpHeight: nil,
                path: "",
                tags: tags,
                notes: notes,
                createdAt: nowTimestamp(),
                updatedAt: nowTimestamp()
            )
        )
        try saveAccessRows(rows)
        reload()
    }

    func updateSSH(_ updated: SSHServer) throws {
        var rows = loadAccessRows()
        guard let idx = rows.firstIndex(where: { $0.kind == .ssh && $0.id.caseInsensitiveCompare(updated.id) == .orderedSame }) else { return }
        rows[idx].clientId = updated.clientId
        rows[idx].alias = updated.alias
        rows[idx].name = updated.name
        rows[idx].host = updated.host
        rows[idx].port = sanitizePort(updated.port, fallback: 22)
        rows[idx].user = updated.user
        rows[idx].tags = updated.tags
        rows[idx].notes = updated.notes
        try saveAccessRows(rows)
        reload()
    }

    func deleteSSH(id: String) throws {
        var rows = loadAccessRows()
        rows.removeAll { $0.kind == .ssh && $0.id.caseInsensitiveCompare(id) == .orderedSame }
        try saveAccessRows(rows)
        reload()
    }

    func addRDP(payload: AddRDPPayload) throws {
        var rows = loadAccessRows()
        rows.append(
            AccessRowStored(
                id: UUID().uuidString,
                clientId: payload.clientId,
                kind: .rdp,
                alias: payload.alias,
                name: payload.name,
                host: payload.host,
                port: sanitizePort(payload.port, fallback: 3389),
                user: payload.user,
                domain: payload.domain,
                rdpIgnoreCert: payload.ignoreCert,
                rdpFullScreen: payload.fullScreen,
                rdpDynamicResolution: payload.dynamicResolution,
                rdpWidth: payload.width,
                rdpHeight: payload.height,
                path: "",
                tags: payload.tags,
                notes: payload.notes,
                createdAt: nowTimestamp(),
                updatedAt: nowTimestamp()
            )
        )
        try saveAccessRows(rows)
        reload()
    }

    func updateRDP(_ updated: RDPServer) throws {
        var rows = loadAccessRows()
        guard let idx = rows.firstIndex(where: { $0.kind == .rdp && $0.id.caseInsensitiveCompare(updated.id) == .orderedSame }) else { return }
        rows[idx].clientId = updated.clientId
        rows[idx].alias = updated.alias
        rows[idx].name = updated.name
        rows[idx].host = updated.host
        rows[idx].port = sanitizePort(updated.port, fallback: 3389)
        rows[idx].user = updated.user
        rows[idx].domain = updated.domain
        rows[idx].tags = updated.tags
        rows[idx].rdpIgnoreCert = updated.ignoreCert
        rows[idx].rdpFullScreen = updated.fullScreen
        rows[idx].rdpDynamicResolution = updated.dynamicResolution
        rows[idx].rdpWidth = updated.width
        rows[idx].rdpHeight = updated.height
        rows[idx].notes = updated.notes
        try saveAccessRows(rows)
        reload()
    }

    func deleteRDP(id: String) throws {
        var rows = loadAccessRows()
        rows.removeAll { $0.kind == .rdp && $0.id.caseInsensitiveCompare(id) == .orderedSame }
        try saveAccessRows(rows)
        reload()
    }

    func addURL(_ access: URLAccess) throws {
        var rows = loadAccessRows()
        rows.append(
            AccessRowStored(
                id: UUID().uuidString,
                clientId: access.clientId,
                kind: .url,
                alias: access.alias,
                name: access.name,
                host: access.host,
                port: sanitizePort(access.port, fallback: 443),
                user: "",
                domain: "",
                rdpIgnoreCert: true,
                rdpFullScreen: false,
                rdpDynamicResolution: true,
                rdpWidth: nil,
                rdpHeight: nil,
                path: sanitizePath(access.path),
                tags: access.tags,
                notes: access.notes,
                createdAt: nowTimestamp(),
                updatedAt: nowTimestamp()
            )
        )
        try saveAccessRows(rows)
        reload()
    }

    func updateURL(_ access: URLAccess) throws {
        var rows = loadAccessRows()
        guard let idx = rows.firstIndex(where: { $0.kind == .url && $0.id.caseInsensitiveCompare(access.id) == .orderedSame }) else { return }
        rows[idx].clientId = access.clientId
        rows[idx].alias = access.alias
        rows[idx].name = access.name
        rows[idx].host = access.host
        rows[idx].port = sanitizePort(access.port, fallback: 443)
        rows[idx].path = sanitizePath(access.path)
        rows[idx].tags = access.tags
        rows[idx].notes = access.notes
        try saveAccessRows(rows)
        reload()
    }

    func deleteURL(id: String) throws {
        var rows = loadAccessRows()
        rows.removeAll { $0.kind == .url && $0.id.caseInsensitiveCompare(id) == .orderedSame }
        try saveAccessRows(rows)
        reload()
    }

    private struct ClientRow {
        var id: String
        var name: String
        var tags: String
        var notes: String
        var createdAt: String
        var updatedAt: String
    }

    private struct AccessRowStored {
        var id: String
        var clientId: String
        var kind: AccessKind
        var alias: String
        var name: String
        var host: String
        var port: Int
        var user: String
        var domain: String
        var rdpIgnoreCert: Bool
        var rdpFullScreen: Bool
        var rdpDynamicResolution: Bool
        var rdpWidth: Int?
        var rdpHeight: Int?
        var path: String
        var tags: String
        var notes: String
        var createdAt: String
        var updatedAt: String
    }

    private func loadClientRows() -> [ClientRow] {
        let lines = readLines(clientsURL)
        guard !lines.isEmpty else { return [] }
        let columns = splitCSV(lines[0])
        let map = makeColumnMap(columns)
        let idIdx = findColumn(map, aliases: ["id"]) ?? 0
        let nameIdx = findColumn(map, aliases: ["nome", "name", "client_name"]) ?? 1
        let tagsIdx = findColumn(map, aliases: ["tags"])
        let notesIdx = findColumn(map, aliases: ["observacoes", "observacao", "notes"]) ?? 2
        let createdIdx = findColumn(map, aliases: ["criadoem", "createdat"])
        let updatedIdx = findColumn(map, aliases: ["atualizadoem", "updatedat"])

        return lines.dropFirst().compactMap { line in
            let c = splitCSV(line)
            let id = cell(c, at: idIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            let name = cell(c, at: nameIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if id.isEmpty || name.isEmpty { return nil }
            return ClientRow(
                id: id,
                name: name,
                tags: tagsIdx.map { cell(c, at: $0) } ?? "",
                notes: cell(c, at: notesIdx),
                createdAt: createdIdx.map { cell(c, at: $0) } ?? "",
                updatedAt: updatedIdx.map { cell(c, at: $0) } ?? ""
            )
        }
    }

    private func loadAccessRows() -> [AccessRowStored] {
        let lines = readLines(accessesURL)
        guard !lines.isEmpty else { return [] }
        let columns = splitCSV(lines[0])
        let map = makeColumnMap(columns)
        let idIdx = findColumn(map, aliases: ["id"]) ?? 0
        let clientIdIdx = findColumn(map, aliases: ["clientid", "client_id"]) ?? 1
        let kindIdx = findColumn(map, aliases: ["tipo", "type"]) ?? 2
        let aliasIdx = findColumn(map, aliases: ["apelido", "alias"]) ?? 3
        let nameIdx = findColumn(map, aliases: ["nome", "name", "server_name"])
        let hostIdx = findColumn(map, aliases: ["host"]) ?? 4
        let portIdx = findColumn(map, aliases: ["porta", "port"]) ?? 5
        let userIdx = findColumn(map, aliases: ["usuario", "user"]) ?? 6
        let domainIdx = findColumn(map, aliases: ["dominio", "domain"]) ?? 7
        let ignoreCertIdx = findColumn(map, aliases: ["rdpignorecert", "ignore_cert"]) ?? 8
        let fullScreenIdx = findColumn(map, aliases: ["rdpfullscreen", "full_screen"]) ?? 9
        let dynamicResolutionIdx = findColumn(map, aliases: ["rdpdynamicresolution", "dynamic_resolution"]) ?? 10
        let widthIdx = findColumn(map, aliases: ["rdpwidth", "width"]) ?? 11
        let heightIdx = findColumn(map, aliases: ["rdpheight", "height"]) ?? 12
        let urlIdx = findColumn(map, aliases: ["url"])
        let pathIdx = findColumn(map, aliases: ["path"])
        let tagsIdx = findColumn(map, aliases: ["tags"])
        let notesIdx = findColumn(map, aliases: ["observacoes", "observacao", "notes"]) ?? 14
        let createdIdx = findColumn(map, aliases: ["criadoem", "createdat"])
        let updatedIdx = findColumn(map, aliases: ["atualizadoem", "updatedat"])

        return lines.dropFirst().compactMap { line in
            let c = splitCSV(line)
            let kindRaw = cell(c, at: kindIdx).uppercased()
            guard let kind = AccessKind(rawValue: kindRaw) else { return nil }

            var host = cell(c, at: hostIdx)
            // Try to parse a numeric port from the CSV cell, trimming non-digits from ends
            let rawPort = cell(c, at: portIdx)
            let trimmedPort = rawPort.trimmingCharacters(in: .whitespacesAndNewlines)
            let numericPort = Int(trimmedPort) ?? Int(trimmedPort.filter({ $0.isNumber }))
            var port = sanitizePort(numericPort ?? 0, fallback: kind == .ssh ? 22 : (kind == .rdp ? 3389 : 443))
            var path = pathIdx.map { sanitizePath(cell(c, at: $0)) } ?? "/"
            let urlValue = urlIdx.map { cell(c, at: $0) } ?? ""
            if !urlValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let parsed = parseURL(urlValue)
                let parsedHost = parsed.host.trimmingCharacters(in: .whitespacesAndNewlines)
                if !parsedHost.isEmpty {
                    host = parsed.host
                    port = parsed.port
                    path = parsed.path
                } else if loggingEnabled {
                    print("[CSVStore] Ignored Url due to empty host: \(urlValue)")
                }
            }
            // Final safety: if host is empty but port "looks like" an IP (e.g., "10.0.0.1"), swap them back
            if host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let candidate = trimmedPort
                if isLikelyIPAddress(candidate) {
                    host = candidate
                    port = kind == .ssh ? 22 : (kind == .rdp ? 3389 : 443)
                }
            }

            let alias = cell(c, at: aliasIdx)
            let resolvedName = nameIdx.map { cell(c, at: $0) }.flatMap { $0.isEmpty ? nil : $0 } ?? alias
            return AccessRowStored(
                id: cell(c, at: idIdx),
                clientId: cell(c, at: clientIdIdx),
                kind: kind,
                alias: alias,
                name: resolvedName,
                host: host,
                port: port,
                user: cell(c, at: userIdx),
                domain: cell(c, at: domainIdx),
                rdpIgnoreCert: parseBool(cell(c, at: ignoreCertIdx)),
                rdpFullScreen: parseBool(cell(c, at: fullScreenIdx)),
                rdpDynamicResolution: parseBool(cell(c, at: dynamicResolutionIdx)),
                rdpWidth: Int(cell(c, at: widthIdx)),
                rdpHeight: Int(cell(c, at: heightIdx)),
                path: path,
                tags: tagsIdx.map { cell(c, at: $0) } ?? "",
                notes: cell(c, at: notesIdx),
                createdAt: createdIdx.map { cell(c, at: $0) } ?? "",
                updatedAt: updatedIdx.map { cell(c, at: $0) } ?? ""
            )
        }
    }

    private func saveClientRows(_ rows: [ClientRow]) throws {
        let header = "Id,Nome,Observacoes,CriadoEm,AtualizadoEm"
        let body = rows.map {
            let createdAt = $0.createdAt.isEmpty ? nowTimestamp() : $0.createdAt
            let updatedAt = nowTimestamp()
            return "\(csv($0.id)),\(csv($0.name)),\(csv($0.notes)),\(csv(createdAt)),\(csv(updatedAt))"
        }
        try writeFile(clientsURL, lines: [header] + body)
    }

    private func saveAccessRows(_ rows: [AccessRowStored]) throws {
        let header = "Id,ClientId,Tipo,Apelido,Host,Porta,Usuario,Dominio,RdpIgnoreCert,RdpFullScreen,RdpDynamicResolution,RdpWidth,RdpHeight,Url,Observacoes,CriadoEm,AtualizadoEm"
        let body = rows.map {
            let w = $0.rdpWidth.map(String.init) ?? ""
            let h = $0.rdpHeight.map(String.init) ?? ""
            let url = $0.kind == .url ? formatURL(host: $0.host, port: $0.port, path: $0.path) : ""
            let createdAt = $0.createdAt.isEmpty ? nowTimestamp() : $0.createdAt
            let updatedAt = nowTimestamp()
            return "\(csv($0.id)),\(csv($0.clientId)),\($0.kind.rawValue),\(csv($0.alias)),\(csv($0.host)),\($0.port),\(csv($0.user)),\(csv($0.domain)),\($0.rdpIgnoreCert),\($0.rdpFullScreen),\($0.rdpDynamicResolution),\(w),\(h),\(csv(url)),\(csv($0.notes)),\(csv(createdAt)),\(csv(updatedAt))"
        }
        try writeFile(accessesURL, lines: [header] + body)
    }

    private func ensureFile(_ url: URL, header: String) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? writeFile(url, lines: [header])
    }

    private func writeFile(_ url: URL, lines: [String]) throws {
        let content = lines.joined(separator: "\n") + "\n"
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func readLines(_ url: URL) -> [String] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return content.split(whereSeparator: \ .isNewline).map(String.init)
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

    private func csv(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func cell(_ values: [String], at index: Int) -> String {
        guard values.indices.contains(index) else { return "" }
        return values[index].trimmingCharacters(in: .whitespacesAndNewlines)
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
            if let idx = map[normalizeHeader(alias)] { return idx }
        }
        return nil
    }

    private func normalizeHeader(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    private func parseURL(_ raw: String) -> (host: String, port: Int, path: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = value.contains("://") ? value : "https://\(value)"
        guard let comps = URLComponents(string: candidate) else {
            return ("", 443, "/")
        }
        let host = comps.host ?? ""
        let port = sanitizePort(comps.port ?? 443, fallback: 443)
        let path = sanitizePath(comps.percentEncodedPath.isEmpty ? "/" : comps.percentEncodedPath)
        return (host, port, path)
    }

    private func formatURL(host: String, port: Int, path: String) -> String {
        "https://\(host):\(sanitizePort(port, fallback: 443))\(sanitizePath(path))"
    }

    private func nowTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
        return formatter.string(from: Date())
    }

    private func parseBool(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "1" || normalized == "true" || normalized == "sim" || normalized == "yes"
    }

    private func sanitizePort(_ port: Int, fallback: Int) -> Int {
        (1...65535).contains(port) ? port : fallback
    }

    private func sanitizePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "/" }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    private func isLikelyIPAddress(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        // Quick IPv4 check: 4 octets 0-255
        let parts = trimmed.split(separator: ".")
        if parts.count == 4, parts.allSatisfy({ p in
            guard let v = Int(p), (0...255).contains(v) else { return false }
            return true
        }) { return true }
        // Quick IPv6 heuristic: contains ':' and hex digits
        if trimmed.contains(":") {
            let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF:")
            return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
        }
        return false
    }

    private func migrateAccessesIfNeeded() {
        // Read current rows
        var rows = loadAccessRows()
        guard !rows.isEmpty else { return }
        var changed = false
        var swappedFromPortIP = 0
        var numericHostHeuristic = 0
        for i in rows.indices {
            // If host is empty but port "looks like" an IP, swap back
            let hostEmpty = rows[i].host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let portString = String(rows[i].port)
            if hostEmpty, isLikelyIPAddress(portString) {
                // Move IP from port back to host and restore default port by kind
                rows[i].host = portString
                rows[i].port = rows[i].kind == .ssh ? 22 : (rows[i].kind == .rdp ? 3389 : 443)
                changed = true
                swappedFromPortIP += 1
            }
            // If host contains only digits and is within 1...65535, and port seems invalid, it's likely swapped
            let hostAsInt = Int(rows[i].host)
            if let h = hostAsInt, (1...65535).contains(h) {
                // If host is a pure number and port is default but URL/path suggest otherwise, treat as swapped
                // Heuristic: if there's no dot in host and no colon, it's not an IP; swap
                if !rows[i].host.contains(".") && !rows[i].host.contains(":") {
                    rows[i].host = ""
                    rows[i].port = sanitizePort(h, fallback: rows[i].kind == .ssh ? 22 : (rows[i].kind == .rdp ? 3389 : 443))
                    // Can't infer original host; leave empty for user correction
                    changed = true
                    numericHostHeuristic += 1
                }
            }
            // Ensure path defaults for URL kind
            if rows[i].kind == .url {
                rows[i].path = sanitizePath(rows[i].path)
                rows[i].port = sanitizePort(rows[i].port, fallback: 443)
            }
            // Ensure ports are within valid range for all kinds
            let fallback = rows[i].kind == .ssh ? 22 : (rows[i].kind == .rdp ? 3389 : 443)
            rows[i].port = sanitizePort(rows[i].port, fallback: fallback)
        }

        if changed {
            if loggingEnabled {
                print("[CSVStore] Migration summary: swappedFromPortIP=\(swappedFromPortIP), numericHostHeuristic=\(numericHostHeuristic)")
            }
            do {
                try saveAccessRows(rows)
                if loggingEnabled { print("[CSVStore] Migration saved to acessos.csv") }
            } catch {
                if loggingEnabled { print("[CSVStore] Migration failed: \(error)") }
            }
        }
    }
}

