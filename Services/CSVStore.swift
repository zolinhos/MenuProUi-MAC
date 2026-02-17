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
    private let eventsURL: URL

    var clientsPath: String { clientsURL.path }
    var acessosPath: String { accessesURL.path }
    var eventosPath: String { eventsURL.path }

    init() {
        clientsURL = Self.dataDirectoryURL.appendingPathComponent("clientes.csv")
        accessesURL = Self.dataDirectoryURL.appendingPathComponent("acessos.csv")
        eventsURL = Self.dataDirectoryURL.appendingPathComponent("eventos.csv")
        try? FileManager.default.createDirectory(at: Self.dataDirectoryURL, withIntermediateDirectories: true)
        ensureFile(clientsURL, header: "Id,Nome,Observacoes,CriadoEm,AtualizadoEm")
        ensureFile(accessesURL, header: "Id,ClientId,Tipo,Apelido,Host,Porta,Usuario,Dominio,RdpIgnoreCert,RdpFullScreen,RdpDynamicResolution,RdpWidth,RdpHeight,Url,Observacoes,IsFavorite,OpenCount,LastOpenedAt,CriadoEm,AtualizadoEm")
        migrateAccessesIfNeeded()
        reload()
    }

    private func logEvent(action: String, entityType: String, entityName: String, details: String) {
        EventLogger().log(action: action, entityType: entityType, entityName: entityName, details: details)
    }

    func logCloneEvent(sourceAlias: String, newAlias: String, kind: AccessKind) {
        logEvent(
            action: "clone",
            entityType: "access",
            entityName: newAlias,
            details: "Clonado de \(sourceAlias); Tipo=\(kind.rawValue)"
        )
    }

    func logConnectivityCheck(scope: String, rowCount: Int) {
        logEvent(
            action: "check_connectivity",
            entityType: "access",
            entityName: scope,
            details: "Checagem executada; Itens=\(max(0, rowCount))"
        )
    }

    func logConnectivityProbe(
        scope: String,
        kind: String,
        target: String,
        method: String,
        effectivePort: Int,
        durationMs: Int,
        outcome: String,
        reason: String,
        replicas: Int
    ) {
        let safeReplicas = max(1, replicas)
        let safeMs = max(0, durationMs)
        let safePort = max(0, effectivePort)
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)

        logEvent(
            action: "check_connectivity_probe",
            entityType: "connectivity",
            entityName: scope,
            details: "Tipo=\(kind); Target=\(target); Method=\(method); Port=\(safePort); ms=\(safeMs); Outcome=\(outcome); Replicas=\(safeReplicas); Reason=\(trimmedReason)"
        )
    }

    func logHelpOpened() {
        logEvent(
            action: "help_opened",
            entityType: "ui",
            entityName: "Ajuda",
            details: "Painel de ajuda aberto"
        )
    }

    func logUIAction(action: String, entityName: String, details: String) {
        logEvent(action: action, entityType: "ui", entityName: entityName, details: details)
    }

    func logDeleteDecision(entityType: String, entityName: String, confirmed: Bool) {
        logEvent(
            action: confirmed ? "delete_confirmed" : "delete_cancelled",
            entityType: entityType,
            entityName: entityName,
            details: confirmed ? "Exclusão confirmada" : "Exclusão cancelada"
        )
    }

    func exportCSVs(to directoryURL: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let safeExportEnabled = UserDefaults.standard.bool(forKey: "export.formulaProtection")

        let exportedClients = directoryURL.appendingPathComponent("clientes.csv")
        let exportedAccesses = directoryURL.appendingPathComponent("acessos.csv")
        let exportedEvents = directoryURL.appendingPathComponent("eventos.csv")

        if fm.fileExists(atPath: exportedClients.path) { try fm.removeItem(at: exportedClients) }
        if fm.fileExists(atPath: exportedAccesses.path) { try fm.removeItem(at: exportedAccesses) }
        if fm.fileExists(atPath: exportedEvents.path) { try fm.removeItem(at: exportedEvents) }

        if safeExportEnabled {
            try exportClientsSafe(to: exportedClients)
            try exportAccessesSafe(to: exportedAccesses)
            if fm.fileExists(atPath: eventsURL.path) {
                try exportEventsSafe(to: exportedEvents)
            }
        } else {
            try fm.copyItem(at: clientsURL, to: exportedClients)
            try fm.copyItem(at: accessesURL, to: exportedAccesses)
            if fm.fileExists(atPath: eventsURL.path) {
                try fm.copyItem(at: eventsURL, to: exportedEvents)
            }
        }

        logEvent(action: "export", entityType: "data", entityName: "csv", details: "Exportado para \(directoryURL.path)")
    }

    func importCSVs(from fileURLs: [URL]) throws {
        let fm = FileManager.default
        var byName: [String: URL] = [:]

        for fileURL in fileURLs {
            byName[fileURL.lastPathComponent.lowercased()] = fileURL
        }

        guard let clientsFile = byName["clientes.csv"], let accessesFile = byName["acessos.csv"] else {
            throw NSError(domain: "CSVStore", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Selecione ao menos clientes.csv e acessos.csv para importar."])
        }

        try validateCSVHeader(fileURL: clientsFile, requiredColumns: ["id", "nome"])
        try validateCSVHeader(fileURL: accessesFile, requiredColumns: ["id", "clientid", "tipo"])

        let backupURL = try createBackupSnapshot()

        do {
            if fm.fileExists(atPath: clientsURL.path) { try fm.removeItem(at: clientsURL) }
            if fm.fileExists(atPath: accessesURL.path) { try fm.removeItem(at: accessesURL) }

            try fm.copyItem(at: clientsFile, to: clientsURL)
            try fm.copyItem(at: accessesFile, to: accessesURL)

            if let eventsFile = byName["eventos.csv"] {
                if fm.fileExists(atPath: eventsURL.path) { try fm.removeItem(at: eventsURL) }
                try fm.copyItem(at: eventsFile, to: eventsURL)
            }

            let strictResult = try validateImportedDataStrict(clientsFile: clientsURL, accessesFile: accessesURL)
            if strictResult.hasErrors {
                throw NSError(domain: "CSVStore", code: 1006, userInfo: [NSLocalizedDescriptionKey: "Importação bloqueada por erros de validação:\n\n\(strictResult.report)"])
            }

            migrateAccessesIfNeeded()
            reload()
            pruneBackups(keep: 5)
            logEvent(action: "import", entityType: "data", entityName: "csv", details: "Importado de \(clientsFile.deletingLastPathComponent().path); Backup=\(backupURL.lastPathComponent)")
        } catch {
            try? restoreBackupSnapshot(from: backupURL)
            throw error
        }
    }

    struct ImportPreview {
        let hasErrors: Bool
        let report: String
    }

    func previewImportCSVs(from fileURLs: [URL]) throws -> ImportPreview {
        var byName: [String: URL] = [:]
        for fileURL in fileURLs {
            byName[fileURL.lastPathComponent.lowercased()] = fileURL
        }

        guard let clientsFile = byName["clientes.csv"], let accessesFile = byName["acessos.csv"] else {
            return .init(hasErrors: true, report: "ERRO\n- Selecione ao menos clientes.csv e acessos.csv")
        }

        var errors: [String] = []
        var warnings: [String] = []

        do {
            try validateCSVHeader(fileURL: clientsFile, requiredColumns: ["id", "nome"])
        } catch {
            errors.append(error.localizedDescription)
        }
        do {
            try validateCSVHeader(fileURL: accessesFile, requiredColumns: ["id", "clientid", "tipo"])
        } catch {
            errors.append(error.localizedDescription)
        }

        let clientsInfo = previewClients(fileURL: clientsFile, errors: &errors, warnings: &warnings)
        let accessesInfo = previewAccesses(fileURL: accessesFile, errors: &errors, warnings: &warnings)

        if byName["eventos.csv"] == nil {
            warnings.append("eventos.csv não selecionado (opcional) — auditoria não será importada")
        }

        var report: [String] = []
        report.append("PRÉVIA DE IMPORTAÇÃO")
        report.append("══════════════════")
        report.append("")
        report.append("Arquivos:")
        report.append("- clientes.csv: \(clientsFile.path)")
        report.append("- acessos.csv:  \(accessesFile.path)")
        let eventsPath = byName["eventos.csv"]?.path ?? "(não selecionado)"
        report.append("- eventos.csv:  \(eventsPath)")
        report.append("")
        report.append("Resumo:")
        report.append("- Clientes: \(clientsInfo.count)")
        report.append("- Acessos:  \(accessesInfo.count)")
        report.append("")

        if !errors.isEmpty {
            report.append("ERROS:")
            for e in errors.prefix(30) { report.append("- \(e)") }
            if errors.count > 30 { report.append("- ... (\(errors.count - 30) adicionais)") }
            report.append("")
        }
        if !warnings.isEmpty {
            report.append("AVISOS:")
            for w in warnings.prefix(30) { report.append("- \(w)") }
            if warnings.count > 30 { report.append("- ... (\(warnings.count - 30) adicionais)") }
            report.append("")
        }

        report.append("Ação:")
        report.append(errors.isEmpty ? "- Você pode prosseguir com a importação." : "- Corrija os erros antes de importar.")

        return .init(hasErrors: !errors.isEmpty, report: report.joined(separator: "\n"))
    }

    private func validateImportedDataStrict(clientsFile: URL, accessesFile: URL) throws -> ImportPreview {
        var errors: [String] = []
        var warnings: [String] = []

        _ = previewClients(fileURL: clientsFile, errors: &errors, warnings: &warnings, strict: true)
        _ = previewAccesses(fileURL: accessesFile, errors: &errors, warnings: &warnings, strict: true)

        var report: [String] = []
        report.append("VALIDAÇÃO DE IMPORTAÇÃO")
        report.append("════════════════════")
        report.append("")

        if !errors.isEmpty {
            report.append("ERROS:")
            for e in errors.prefix(50) { report.append("- \(e)") }
            if errors.count > 50 { report.append("- ... (\(errors.count - 50) adicionais)") }
            report.append("")
        }

        if !warnings.isEmpty {
            report.append("AVISOS:")
            for w in warnings.prefix(50) { report.append("- \(w)") }
            if warnings.count > 50 { report.append("- ... (\(warnings.count - 50) adicionais)") }
        }

        return .init(hasErrors: !errors.isEmpty, report: report.joined(separator: "\n"))
    }

    private struct PreviewCounts {
        let count: Int
    }

    private func previewClients(fileURL: URL, errors: inout [String], warnings: inout [String], strict: Bool = false) -> PreviewCounts {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            errors.append("Não foi possível ler \(fileURL.lastPathComponent)")
            return .init(count: 0)
        }
        let lines = content.split(whereSeparator: \ .isNewline).map(String.init)
        guard lines.count >= 2 else {
            warnings.append("clientes.csv sem dados")
            return .init(count: 0)
        }

        let header = splitCSV(lines[0])
        let map = makeColumnMap(header)
        let idIdx = findColumn(map, aliases: ["id"]) ?? 0
        let nameIdx = findColumn(map, aliases: ["nome", "name"]) ?? 1

        var seen: Set<String> = []
        var dup = 0
        var emptyName = 0
        var emptyId = 0

        for line in lines.dropFirst() {
            let c = splitCSV(line)
            let id = cell(c, at: idIdx).lowercased()
            let name = cell(c, at: nameIdx)
            if id.isEmpty { emptyId += 1; continue }
            if seen.contains(id) { dup += 1 } else { seen.insert(id) }
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { emptyName += 1 }
        }

        if emptyId > 0 {
            if strict { errors.append("clientes.csv possui \(emptyId) registros com Id vazio") }
            else { warnings.append("clientes.csv possui \(emptyId) registros com Id vazio") }
        }
        if dup > 0 {
            if strict { errors.append("clientes.csv possui \(dup) IDs duplicados") }
            else { warnings.append("clientes.csv possui \(dup) IDs duplicados") }
        }
        if emptyName > 0 {
            if strict { errors.append("clientes.csv possui \(emptyName) registros com nome vazio") }
            else { warnings.append("clientes.csv possui \(emptyName) registros com nome vazio") }
        }
        return .init(count: max(0, lines.count - 1))
    }

    private func previewAccesses(fileURL: URL, errors: inout [String], warnings: inout [String], strict: Bool = false) -> PreviewCounts {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            errors.append("Não foi possível ler \(fileURL.lastPathComponent)")
            return .init(count: 0)
        }
        let lines = content.split(whereSeparator: \ .isNewline).map(String.init)
        guard lines.count >= 2 else {
            warnings.append("acessos.csv sem dados")
            return .init(count: 0)
        }

        let header = splitCSV(lines[0])
        let map = makeColumnMap(header)
        let idIdx = findColumn(map, aliases: ["id"]) ?? 0
        let clientIdIdx = findColumn(map, aliases: ["clientid", "client_id"]) ?? 1
        let kindIdx = findColumn(map, aliases: ["tipo", "type"]) ?? 2
        let aliasIdx = findColumn(map, aliases: ["apelido", "alias"]) ?? 3
        let hostIdx = findColumn(map, aliases: ["host"]) ?? 4
        let portIdx = findColumn(map, aliases: ["porta", "port"]) ?? 5

        var seenId: Set<String> = []
        var dupId = 0
        var unknownType = 0
        var emptyId = 0
        var emptyClientId = 0
        var emptyAlias = 0
        var invalidPort = 0
        var aliasDup: Set<String> = []
        var aliasSeen: Set<String> = []

        for line in lines.dropFirst() {
            let c = splitCSV(line)
            let id = cell(c, at: idIdx).lowercased()
            if id.isEmpty { emptyId += 1 } else {
                if seenId.contains(id) { dupId += 1 } else { seenId.insert(id) }
            }

            let clientId = cell(c, at: clientIdIdx).lowercased()
            if clientId.isEmpty { emptyClientId += 1 }

            let kindRaw = cell(c, at: kindIdx).uppercased()
            if AccessKind(rawValue: kindRaw) == nil { unknownType += 1 }

            let alias = cell(c, at: aliasIdx).lowercased()
            if alias.isEmpty { emptyAlias += 1 }
            if !clientId.isEmpty, !alias.isEmpty {
                let key = "\(clientId)|\(kindRaw)|\(alias)"
                if aliasSeen.contains(key) { aliasDup.insert(key) } else { aliasSeen.insert(key) }
            }

            let portRaw = cell(c, at: portIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if !portRaw.isEmpty {
                let numeric = Int(portRaw) ?? Int(portRaw.filter({ $0.isNumber }))
                if let p = numeric {
                    if !(1...65535).contains(p) { invalidPort += 1 }
                } else {
                    invalidPort += 1
                }
            }

            let host = cell(c, at: hostIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if host.isEmpty {
                // for URL, host may come from Url column; keep as warning only
                warnings.append("acessos.csv possui registros com Host vazio (pode ser esperado para URL se Url estiver preenchida)")
                break
            }
        }

        if emptyId > 0 {
            if strict { errors.append("acessos.csv possui \(emptyId) registros com Id vazio") }
            else { warnings.append("acessos.csv possui \(emptyId) registros com Id vazio") }
        }
        if emptyClientId > 0 {
            if strict { errors.append("acessos.csv possui \(emptyClientId) registros com ClientId vazio") }
            else { warnings.append("acessos.csv possui \(emptyClientId) registros com ClientId vazio") }
        }
        if emptyAlias > 0 {
            if strict { errors.append("acessos.csv possui \(emptyAlias) registros com Alias vazio") }
            else { warnings.append("acessos.csv possui \(emptyAlias) registros com Alias vazio") }
        }

        if dupId > 0 {
            if strict { errors.append("acessos.csv possui \(dupId) IDs duplicados") }
            else { warnings.append("acessos.csv possui \(dupId) IDs duplicados") }
        }
        if unknownType > 0 {
            if strict { errors.append("acessos.csv possui \(unknownType) registros com Tipo desconhecido") }
            else { warnings.append("acessos.csv possui \(unknownType) registros com Tipo desconhecido") }
        }
        if invalidPort > 0 {
            if strict { errors.append("acessos.csv possui \(invalidPort) registros com Porta inválida") }
            else { warnings.append("acessos.csv possui \(invalidPort) registros com Porta inválida") }
        }
        if !aliasDup.isEmpty {
            if strict { errors.append("acessos.csv possui \(aliasDup.count) conflitos de alias por cliente/tipo") }
            else { warnings.append("acessos.csv possui \(aliasDup.count) conflitos de alias por cliente/tipo") }
        }
        return .init(count: max(0, lines.count - 1))
    }

    func latestBackupName() -> String? {
        let fm = FileManager.default
        let root = backupsRootURL()
        guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        let sorted = items.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }
        return sorted.first?.lastPathComponent
    }

    func restoreLatestBackup() throws {
        let fm = FileManager.default
        let root = backupsRootURL()
        guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            throw NSError(domain: "CSVStore", code: 1101, userInfo: [NSLocalizedDescriptionKey: "Nenhum backup encontrado."])
        }
        let sorted = items.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }
        guard let latest = sorted.first else {
            throw NSError(domain: "CSVStore", code: 1102, userInfo: [NSLocalizedDescriptionKey: "Nenhum backup encontrado."])
        }
        try restoreBackupSnapshot(from: latest)
    }

    private func validateCSVHeader(fileURL: URL, requiredColumns: [String]) throws {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        guard let firstLine = content.split(whereSeparator: \ .isNewline).first else {
            throw NSError(domain: "CSVStore", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Arquivo inválido: \(fileURL.lastPathComponent)"])
        }
        let headerCells = splitCSV(String(firstLine))
        let map = makeColumnMap(headerCells)
        for col in requiredColumns {
            if findColumn(map, aliases: [col]) == nil {
                throw NSError(domain: "CSVStore", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Header inválido em \(fileURL.lastPathComponent): faltando coluna \(col)"])
            }
        }
    }

    private func backupsRootURL() -> URL {
        Self.dataDirectoryURL.appendingPathComponent("backups", isDirectory: true)
    }

    private func createBackupSnapshot() throws -> URL {
        let fm = FileManager.default
        let root = backupsRootURL()
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let stamp = backupStamp()
        let backupDir = root.appendingPathComponent(stamp, isDirectory: true)
        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

        if fm.fileExists(atPath: clientsURL.path) {
            try fm.copyItem(at: clientsURL, to: backupDir.appendingPathComponent("clientes.csv"))
        }
        if fm.fileExists(atPath: accessesURL.path) {
            try fm.copyItem(at: accessesURL, to: backupDir.appendingPathComponent("acessos.csv"))
        }
        if fm.fileExists(atPath: eventsURL.path) {
            try fm.copyItem(at: eventsURL, to: backupDir.appendingPathComponent("eventos.csv"))
        }

        return backupDir
    }

    private func restoreBackupSnapshot(from backupDir: URL) throws {
        let fm = FileManager.default

        let bClients = backupDir.appendingPathComponent("clientes.csv")
        let bAccesses = backupDir.appendingPathComponent("acessos.csv")
        let bEvents = backupDir.appendingPathComponent("eventos.csv")

        if fm.fileExists(atPath: bClients.path) {
            if fm.fileExists(atPath: clientsURL.path) { try? fm.removeItem(at: clientsURL) }
            try fm.copyItem(at: bClients, to: clientsURL)
        }
        if fm.fileExists(atPath: bAccesses.path) {
            if fm.fileExists(atPath: accessesURL.path) { try? fm.removeItem(at: accessesURL) }
            try fm.copyItem(at: bAccesses, to: accessesURL)
        }
        if fm.fileExists(atPath: bEvents.path) {
            if fm.fileExists(atPath: eventsURL.path) { try? fm.removeItem(at: eventsURL) }
            try fm.copyItem(at: bEvents, to: eventsURL)
        }

        migrateAccessesIfNeeded()
        reload()
        logEvent(action: "import_rollback", entityType: "data", entityName: "csv", details: "Rollback executado; Backup=\(backupDir.lastPathComponent)")
    }

    private func pruneBackups(keep: Int) {
        let fm = FileManager.default
        let root = backupsRootURL()
        guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return
        }
        let sorted = items.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }
        if sorted.count <= max(0, keep) { return }
        for url in sorted.dropFirst(max(0, keep)) {
            try? fm.removeItem(at: url)
        }
    }

    private func backupStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private func exportClientsSafe(to url: URL) throws {
        let header = "Id,Nome,Observacoes,CriadoEm,AtualizadoEm"
        let rows = loadClientRows()
        let body = rows.map {
            let createdAt = $0.createdAt.isEmpty ? nowTimestamp() : $0.createdAt
            let updatedAt = $0.updatedAt.isEmpty ? nowTimestamp() : $0.updatedAt
            return "\(csv($0.id)),\(csvExport($0.name)),\(csvExport($0.notes)),\(csv(createdAt)),\(csv(updatedAt))"
        }
        try writeFile(url, lines: [header] + body)
    }

    private func exportAccessesSafe(to url: URL) throws {
        let header = "Id,ClientId,Tipo,Apelido,Host,Porta,Usuario,Dominio,RdpIgnoreCert,RdpFullScreen,RdpDynamicResolution,RdpWidth,RdpHeight,Url,Observacoes,IsFavorite,OpenCount,LastOpenedAt,CriadoEm,AtualizadoEm"
        let rows = loadAccessRows()
        let body = rows.map {
            let w = $0.rdpWidth.map(String.init) ?? ""
            let h = $0.rdpHeight.map(String.init) ?? ""
            let urlValue = $0.kind == .url ? formatURL(scheme: $0.scheme, host: $0.host, port: $0.port, path: $0.path) : ""
            let createdAt = $0.createdAt.isEmpty ? nowTimestamp() : $0.createdAt
            let updatedAt = $0.updatedAt.isEmpty ? nowTimestamp() : $0.updatedAt
            let openCount = max(0, $0.openCount)
            return "\(csv($0.id)),\(csv($0.clientId)),\($0.kind.rawValue),\(csvExport($0.alias)),\(csv($0.host)),\($0.port),\(csvExport($0.user)),\(csvExport($0.domain)),\($0.rdpIgnoreCert),\($0.rdpFullScreen),\($0.rdpDynamicResolution),\(w),\(h),\(csv(urlValue)),\(csvExport($0.notes)),\($0.isFavorite),\(openCount),\(csv($0.lastOpenedAt)),\(csv(createdAt)),\(csv(updatedAt))"
        }
        try writeFile(url, lines: [header] + body)
    }

    private func exportEventsSafe(to url: URL) throws {
        let lines = readLines(eventsURL)
        guard !lines.isEmpty else {
            try writeFile(url, lines: ["TimestampUtc,Action,EntityType,EntityName,Details"])
            return
        }

        let header = lines[0]
        let body = lines.dropFirst().map { line -> String in
            let c = splitCSV(line)
            let ts = cell(c, at: 0)
            let action = cell(c, at: 1)
            let entityType = cell(c, at: 2)
            let entityName = cell(c, at: 3)
            let details = cell(c, at: 4)
            return "\(csv(ts)),\(csv(action)),\(csv(entityType)),\(csvExport(entityName)),\(csvExport(details))"
        }

        try writeFile(url, lines: [header] + body)
    }

    private func csvExport(_ value: String) -> String {
        let protected = protectCSVFormula(value)
        let escaped = protected.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func protectCSVFormula(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return value }
        if first == "=" || first == "+" || first == "-" || first == "@" {
            return "'\(value)"
        }
        return value
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
                    notes: $0.notes,
                    isFavorite: $0.isFavorite,
                    openCount: $0.openCount,
                    lastOpenedAt: $0.lastOpenedAt
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
                    notes: $0.notes,
                    isFavorite: $0.isFavorite,
                    openCount: $0.openCount,
                    lastOpenedAt: $0.lastOpenedAt
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
                    scheme: $0.scheme,
                    host: $0.host,
                    port: $0.port,
                    path: $0.path,
                    tags: $0.tags,
                    notes: $0.notes,
                    isFavorite: $0.isFavorite,
                    openCount: $0.openCount,
                    lastOpenedAt: $0.lastOpenedAt
                )
            }
    }

    func addClient(id: String, name: String, tags: String, notes: String) throws {
        var rows = loadClientRows()
        let now = nowTimestamp()
        let clientId = id.isEmpty ? UUID().uuidString : id
        rows.append(ClientRow(id: clientId, name: name, tags: tags, notes: notes, createdAt: now, updatedAt: now))
        try saveClientRows(rows)
        reload()
        logEvent(action: "create", entityType: "client", entityName: name, details: "Cliente criado")
    }

    func updateClient(_ updated: Client) throws {
        var rows = loadClientRows()
        guard let idx = rows.firstIndex(where: { $0.id.caseInsensitiveCompare(updated.id) == .orderedSame }) else { return }
        rows[idx].name = updated.name
        rows[idx].tags = updated.tags
        rows[idx].notes = updated.notes
        try saveClientRows(rows)
        reload()
        logEvent(action: "edit", entityType: "client", entityName: updated.name, details: "Cliente atualizado")
    }

    func deleteClientCascade(clientId: String) throws {
        var clientRows = loadClientRows()
        let deletedClient = clientRows.first { $0.id.caseInsensitiveCompare(clientId) == .orderedSame }
        clientRows.removeAll { $0.id.caseInsensitiveCompare(clientId) == .orderedSame }
        try saveClientRows(clientRows)

        var accessRows = loadAccessRows()
        accessRows.removeAll { $0.clientId.caseInsensitiveCompare(clientId) == .orderedSame }
        try saveAccessRows(accessRows)
        reload()
        logEvent(action: "delete", entityType: "client", entityName: deletedClient?.name ?? clientId, details: "Cliente excluído em cascata")
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
                scheme: "https",
                tags: tags,
                notes: notes,
                isFavorite: false,
                openCount: 0,
                lastOpenedAt: "",
                createdAt: nowTimestamp(),
                updatedAt: nowTimestamp()
            )
        )
        try saveAccessRows(rows)
        reload()
        logEvent(action: "create", entityType: "access", entityName: alias, details: "Acesso SSH criado")
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
        rows[idx].isFavorite = updated.isFavorite
        rows[idx].openCount = max(0, updated.openCount)
        rows[idx].lastOpenedAt = updated.lastOpenedAt
        try saveAccessRows(rows)
        reload()
        logEvent(action: "edit", entityType: "access", entityName: updated.alias, details: "Acesso SSH atualizado")
    }

    func deleteSSH(id: String) throws {
        var rows = loadAccessRows()
        let deleted = rows.first { $0.kind == .ssh && $0.id.caseInsensitiveCompare(id) == .orderedSame }
        rows.removeAll { $0.kind == .ssh && $0.id.caseInsensitiveCompare(id) == .orderedSame }
        try saveAccessRows(rows)
        reload()
        logEvent(action: "delete", entityType: "access", entityName: deleted?.alias ?? id, details: "Acesso SSH excluído")
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
                scheme: "https",
                tags: payload.tags,
                notes: payload.notes,
                isFavorite: false,
                openCount: 0,
                lastOpenedAt: "",
                createdAt: nowTimestamp(),
                updatedAt: nowTimestamp()
            )
        )
        try saveAccessRows(rows)
        reload()
        logEvent(action: "create", entityType: "access", entityName: payload.alias, details: "Acesso RDP criado")
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
        rows[idx].isFavorite = updated.isFavorite
        rows[idx].openCount = max(0, updated.openCount)
        rows[idx].lastOpenedAt = updated.lastOpenedAt
        try saveAccessRows(rows)
        reload()
        logEvent(action: "edit", entityType: "access", entityName: updated.alias, details: "Acesso RDP atualizado")
    }

    func deleteRDP(id: String) throws {
        var rows = loadAccessRows()
        let deleted = rows.first { $0.kind == .rdp && $0.id.caseInsensitiveCompare(id) == .orderedSame }
        rows.removeAll { $0.kind == .rdp && $0.id.caseInsensitiveCompare(id) == .orderedSame }
        try saveAccessRows(rows)
        reload()
        logEvent(action: "delete", entityType: "access", entityName: deleted?.alias ?? id, details: "Acesso RDP excluído")
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
                port: sanitizePort(access.port, fallback: defaultPort(for: sanitizeScheme(access.scheme))),
                user: "",
                domain: "",
                rdpIgnoreCert: true,
                rdpFullScreen: false,
                rdpDynamicResolution: true,
                rdpWidth: nil,
                rdpHeight: nil,
                path: sanitizePath(access.path),
                scheme: sanitizeScheme(access.scheme),
                tags: access.tags,
                notes: access.notes,
                isFavorite: false,
                openCount: 0,
                lastOpenedAt: "",
                createdAt: nowTimestamp(),
                updatedAt: nowTimestamp()
            )
        )
        try saveAccessRows(rows)
        reload()
        logEvent(action: "create", entityType: "access", entityName: access.alias, details: "Acesso URL criado")
    }

    func updateURL(_ access: URLAccess) throws {
        var rows = loadAccessRows()
        guard let idx = rows.firstIndex(where: { $0.kind == .url && $0.id.caseInsensitiveCompare(access.id) == .orderedSame }) else { return }
        rows[idx].clientId = access.clientId
        rows[idx].alias = access.alias
        rows[idx].name = access.name
        rows[idx].scheme = sanitizeScheme(access.scheme)
        rows[idx].host = access.host
        rows[idx].port = sanitizePort(access.port, fallback: defaultPort(for: rows[idx].scheme))
        rows[idx].path = sanitizePath(access.path)
        rows[idx].tags = access.tags
        rows[idx].notes = access.notes
        rows[idx].isFavorite = access.isFavorite
        rows[idx].openCount = max(0, access.openCount)
        rows[idx].lastOpenedAt = access.lastOpenedAt
        try saveAccessRows(rows)
        reload()
        logEvent(action: "edit", entityType: "access", entityName: access.alias, details: "Acesso URL atualizado")
    }

    func deleteURL(id: String) throws {
        var rows = loadAccessRows()
        let deleted = rows.first { $0.kind == .url && $0.id.caseInsensitiveCompare(id) == .orderedSame }
        rows.removeAll { $0.kind == .url && $0.id.caseInsensitiveCompare(id) == .orderedSame }
        try saveAccessRows(rows)
        reload()
        logEvent(action: "delete", entityType: "access", entityName: deleted?.alias ?? id, details: "Acesso URL excluído")
    }

    func toggleFavorite(kind: AccessKind, id: String) throws -> Bool {
        var rows = loadAccessRows()
        guard let idx = rows.firstIndex(where: { $0.kind == kind && $0.id.caseInsensitiveCompare(id) == .orderedSame }) else {
            return false
        }
        rows[idx].isFavorite.toggle()
        rows[idx].updatedAt = nowTimestamp()
        let isFavorite = rows[idx].isFavorite
        let accessName = rows[idx].alias.isEmpty ? rows[idx].name : rows[idx].alias
        try saveAccessRows(rows)
        reload()
        logEvent(action: "favorite", entityType: "access", entityName: accessName, details: isFavorite ? "Favoritado" : "Desfavoritado")
        return isFavorite
    }

    func markAccessOpened(kind: AccessKind, id: String) throws {
        var rows = loadAccessRows()
        guard let idx = rows.firstIndex(where: { $0.kind == kind && $0.id.caseInsensitiveCompare(id) == .orderedSame }) else {
            return
        }

        rows[idx].openCount = max(0, rows[idx].openCount) + 1
        rows[idx].lastOpenedAt = nowTimestamp()
        rows[idx].updatedAt = nowTimestamp()
        let accessName = rows[idx].alias.isEmpty ? rows[idx].name : rows[idx].alias
        let accessType = rows[idx].kind.rawValue

        try saveAccessRows(rows)
        reload()

        logEvent(
            action: "open",
            entityType: "access",
            entityName: accessName,
            details: "Acesso aberto; Tipo=\(accessType)"
        )
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
        var scheme: String
        var tags: String
        var notes: String
        var isFavorite: Bool
        var openCount: Int
        var lastOpenedAt: String
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
        let notesIdx = findColumn(map, aliases: ["observacoes", "observacao", "notes"])
        let favoriteIdx = findColumn(map, aliases: ["isfavorite", "favorite"])
        let openCountIdx = findColumn(map, aliases: ["opencount", "open_count"])
        let lastOpenedIdx = findColumn(map, aliases: ["lastopenedat", "last_opened_at"])
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
            var port = sanitizePort(numericPort ?? 0, fallback: kind == .ssh ? 22 : (kind == .rdp ? 3389 : 80))
            var path = pathIdx.map { sanitizePath(cell(c, at: $0)) } ?? "/"
            var scheme = "http"
            let urlValue = urlIdx.map { cell(c, at: $0) } ?? ""
            if !urlValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let parsed = parseURL(urlValue)
                let parsedHost = parsed.host.trimmingCharacters(in: .whitespacesAndNewlines)
                if !parsedHost.isEmpty {
                    scheme = parsed.scheme
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
                    port = kind == .ssh ? 22 : (kind == .rdp ? 3389 : 80)
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
                scheme: sanitizeScheme(scheme),
                tags: tagsIdx.map { cell(c, at: $0) } ?? "",
                notes: notesIdx.map { cell(c, at: $0) } ?? "",
                isFavorite: favoriteIdx.map { parseBool(cell(c, at: $0)) } ?? false,
                openCount: openCountIdx.map { Int(cell(c, at: $0)) ?? 0 } ?? 0,
                lastOpenedAt: lastOpenedIdx.map { cell(c, at: $0) } ?? "",
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
        let header = "Id,ClientId,Tipo,Apelido,Host,Porta,Usuario,Dominio,RdpIgnoreCert,RdpFullScreen,RdpDynamicResolution,RdpWidth,RdpHeight,Url,Observacoes,IsFavorite,OpenCount,LastOpenedAt,CriadoEm,AtualizadoEm"
        let body = rows.map {
            let w = $0.rdpWidth.map(String.init) ?? ""
            let h = $0.rdpHeight.map(String.init) ?? ""
            let url = $0.kind == .url ? formatURL(scheme: $0.scheme, host: $0.host, port: $0.port, path: $0.path) : ""
            let createdAt = $0.createdAt.isEmpty ? nowTimestamp() : $0.createdAt
            let updatedAt = nowTimestamp()
            let openCount = max(0, $0.openCount)
            return "\(csv($0.id)),\(csv($0.clientId)),\($0.kind.rawValue),\(csv($0.alias)),\(csv($0.host)),\($0.port),\(csv($0.user)),\(csv($0.domain)),\($0.rdpIgnoreCert),\($0.rdpFullScreen),\($0.rdpDynamicResolution),\(w),\(h),\(csv(url)),\(csv($0.notes)),\($0.isFavorite),\(openCount),\(csv($0.lastOpenedAt)),\(csv(createdAt)),\(csv(updatedAt))"
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

    private func parseURL(_ raw: String) -> (scheme: String, host: String, port: Int, path: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = value.contains("://") ? value : "http://\(value)"
        guard let comps = URLComponents(string: candidate) else {
            return ("http", "", 80, "/")
        }
        let scheme = sanitizeScheme(comps.scheme ?? "http")
        let host = (comps.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackPort = defaultPort(for: scheme)
        let port = sanitizePort(comps.port ?? fallbackPort, fallback: fallbackPort)
        let basePath = comps.percentEncodedPath.isEmpty ? "/" : comps.percentEncodedPath
        let queryPart = (comps.percentEncodedQuery?.isEmpty == false) ? "?\(comps.percentEncodedQuery!)" : ""
        let fragmentPart = (comps.percentEncodedFragment?.isEmpty == false) ? "#\(comps.percentEncodedFragment!)" : ""
        let path = sanitizePath(basePath) + queryPart + fragmentPart
        return (scheme, host, port, path)
    }

    private func formatURL(scheme: String, host: String, port: Int, path: String) -> String {
        let normalizedScheme = sanitizeScheme(scheme)
        let fallbackPort = defaultPort(for: normalizedScheme)
        return "\(normalizedScheme)://\(host):\(sanitizePort(port, fallback: fallbackPort))\(sanitizePath(path))"
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

    private func sanitizeScheme(_ scheme: String) -> String {
        let normalized = scheme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? "http" : normalized
    }

    private func defaultPort(for scheme: String) -> Int {
        switch sanitizeScheme(scheme) {
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
                rows[i].port = sanitizePort(rows[i].port, fallback: defaultPort(for: rows[i].scheme))
            }
            // Ensure ports are within valid range for all kinds
            let fallback = rows[i].kind == .ssh ? 22 : (rows[i].kind == .rdp ? 3389 : defaultPort(for: rows[i].scheme))
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

