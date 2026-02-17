import Foundation
import Combine

// MARK: - Parser de logs de conexão
/// Lê eventos de conexão (arquivo `eventos.csv`) e gera pontos de dados
/// para o gráfico de conexões por dia.
/// Também suporta leitura de formato legado (`conexoes.log`) para retrocompatibilidade.
final class LogParser: ObservableObject {
    /// Pontos de dados agrupados por dia e tipo de conexão.
    @Published var points: [ConnLogPoint] = []

    private let eventsURL: URL
    private let legacyLogURL: URL
    private let fm = FileManager.default

    init() {
        eventsURL = CSVStore.dataDirectoryURL.appendingPathComponent("eventos.csv")
        legacyLogURL = CSVStore.dataDirectoryURL.appendingPathComponent("conexoes.log")
        reload()
    }

    /// Recarrega os dados de log do disco.
    func reload() {
        if fm.fileExists(atPath: eventsURL.path),
           let content = try? String(contentsOf: eventsURL, encoding: .utf8) {
            points = parseEventsCSV(content)
            return
        }

        guard let legacy = try? String(contentsOf: legacyLogURL, encoding: .utf8) else {
            points = []
            return
        }

        points = parseLegacyLog(legacy)
    }

    private func parseEventsCSV(_ s: String) -> [ConnLogPoint] {
        let lines = s.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count > 1 else { return [] }

        let header = splitCSV(lines[0])
        let map = makeColumnMap(header)
        let tsIdx = findColumn(map, aliases: ["timestamputc"]) ?? 0
        let actionIdx = findColumn(map, aliases: ["action"]) ?? 1
        let entityTypeIdx = findColumn(map, aliases: ["entitytype"]) ?? 2
        let detailsIdx = findColumn(map, aliases: ["details"]) ?? 4

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MM/dd/yyyy HH:mm:ss"

        var bucket: [String: [ConnType: Int]] = [:]

        for line in lines.dropFirst() {
            let parts = splitCSV(line)
            let action = cell(parts, at: actionIdx).lowercased()
            let entityType = cell(parts, at: entityTypeIdx).lowercased()
            guard action == "open", entityType == "access" else { continue }

            let rawTimestamp = cell(parts, at: tsIdx)
            guard df.date(from: rawTimestamp) != nil else { continue }

            let details = cell(parts, at: detailsIdx)
            let type = connType(from: details)
            let dayKey = String(rawTimestamp.prefix(10))
            bucket[dayKey, default: [:]][type, default: 0] += 1
        }

        return buildPoints(bucket: bucket)
    }

    private func parseLegacyLog(_ s: String) -> [ConnLogPoint] {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var bucket: [String: [ConnType: Int]] = [:]

        for line in s.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 2 else { continue }
            guard df.date(from: parts[0]) != nil else { continue }

            let dayKey = String(parts[0].prefix(10))
            let type = ConnType(rawValue: parts[1]) ?? .ssh
            bucket[dayKey, default: [:]][type, default: 0] += 1
        }

        return buildPoints(bucket: bucket)
    }

    private func buildPoints(bucket: [String: [ConnType: Int]]) -> [ConnLogPoint] {
        let dayDF = DateFormatter()
        dayDF.dateFormat = "MM/dd/yyyy"

        var out: [ConnLogPoint] = []
        for (dayKey, counts) in bucket {
            guard let day = dayDF.date(from: dayKey) ?? isoDay(from: dayKey) else { continue }
            for (t, c) in counts {
                out.append(.init(day: day, type: t, count: c))
            }
        }

        return out.sorted { $0.day < $1.day }
    }

    private func connType(from details: String) -> ConnType {
        let normalized = details.uppercased()
        if normalized.contains("TIPO=RDP") { return .rdp }
        if normalized.contains("TIPO=URL") { return .url }
        return .ssh
    }

    private func isoDay(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
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

    private func cell(_ values: [String], at index: Int) -> String {
        guard values.indices.contains(index) else { return "" }
        return values[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
