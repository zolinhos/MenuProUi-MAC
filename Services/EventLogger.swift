import Foundation
import CryptoKit

struct EventLogger {
    private let fm = FileManager.default
    private let maxEventsFileBytes: UInt64 = 5 * 1024 * 1024

    private let chainFileName = "eventos.chain"

    enum IntegrityStatus: String {
        case ok = "OK"
        case missing = "Indisponível"
        case mismatch = "Falha"
        case error = "Erro"
    }

    func log(action: String, entityType: String, entityName: String, details: String) {
        let eventsURL = CSVStore.dataDirectoryURL.appendingPathComponent("eventos.csv")
        ensureFile(at: eventsURL)
        rotateIfNeeded(eventsURL)
        ensureFile(at: eventsURL)
        let line = "\(csv(nowTimestampUTC())),\(csv(action)),\(csv(entityType)),\(csv(entityName)),\(csv(details))"

        if let handle = try? FileHandle(forWritingTo: eventsURL) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            if let data = (line + "\n").data(using: .utf8) {
                handle.write(data)
            }

            updateChainAfterAppend(line: line)
            return
        }

        let fallback = [header(), line].joined(separator: "\n") + "\n"
        try? fallback.write(to: eventsURL, atomically: true, encoding: .utf8)
        rebuildChainFromFile(eventsURL: eventsURL)
    }

    private func ensureFile(at url: URL) {
        try? fm.createDirectory(at: CSVStore.dataDirectoryURL, withIntermediateDirectories: true)
        guard !fm.fileExists(atPath: url.path) else { return }
        let content = header() + "\n"
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func rotateIfNeeded(_ url: URL) {
        guard fm.fileExists(atPath: url.path) else { return }
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else {
            return
        }

        guard size.uint64Value >= maxEventsFileBytes else { return }

        let stamp = rotationStamp()
        let rotatedURL = CSVStore.dataDirectoryURL.appendingPathComponent("eventos_\(stamp).csv")
        let chainURL = CSVStore.dataDirectoryURL.appendingPathComponent(chainFileName)
        let rotatedChainURL = CSVStore.dataDirectoryURL.appendingPathComponent("eventos_\(stamp).chain")

        do {
            if fm.fileExists(atPath: rotatedURL.path) {
                try? fm.removeItem(at: rotatedURL)
            }
            try fm.moveItem(at: url, to: rotatedURL)

            if fm.fileExists(atPath: chainURL.path) {
                if fm.fileExists(atPath: rotatedChainURL.path) {
                    try? fm.removeItem(at: rotatedChainURL)
                }
                try? fm.moveItem(at: chainURL, to: rotatedChainURL)
            }
        } catch {
            // If rotation fails, keep writing to the original file.
        }
    }

    private func rotationStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private func header() -> String {
        "TimestampUtc,Action,EntityType,EntityName,Details"
    }

    private func nowTimestampUTC() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
        return formatter.string(from: Date())
    }

    private func csv(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func chainURL() -> URL {
        CSVStore.dataDirectoryURL.appendingPathComponent(chainFileName)
    }

    private func readChainState() -> (count: Int, lastHash: String)? {
        let url = chainURL()
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var count: Int?
        var last: String?
        for line in content.split(whereSeparator: \ .isNewline).map(String.init) {
            if line.hasPrefix("count=") {
                count = Int(line.replacingOccurrences(of: "count=", with: ""))
            } else if line.hasPrefix("last=") {
                last = line.replacingOccurrences(of: "last=", with: "")
            }
        }
        guard let c = count, let l = last else { return nil }
        return (c, l)
    }

    private func writeChainState(count: Int, lastHash: String) {
        let content = "count=\(max(0, count))\nlast=\(lastHash)\n"
        try? content.write(to: chainURL(), atomically: true, encoding: .utf8)
    }

    private func updateChainAfterAppend(line: String) {
        let state = readChainState() ?? (0, "GENESIS")
        let next = sha256Hex("\(state.lastHash)\n\(line)")
        writeChainState(count: state.count + 1, lastHash: next)
    }

    private func rebuildChainFromFile(eventsURL: URL) {
        guard let content = try? String(contentsOf: eventsURL, encoding: .utf8) else { return }
        let lines = content.split(whereSeparator: \ .isNewline).map(String.init)
        guard lines.count > 1 else {
            writeChainState(count: 0, lastHash: "GENESIS")
            return
        }

        var last = "GENESIS"
        var count = 0
        for line in lines.dropFirst() {
            last = sha256Hex("\(last)\n\(line)")
            count += 1
        }
        writeChainState(count: count, lastHash: last)
    }

    private func sha256Hex(_ s: String) -> String {
        let data = Data(s.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func verifyIntegrity(eventsURL: URL) -> IntegrityStatus {
        let logger = EventLogger()
        let chainURL = logger.chainURL()
        guard FileManager.default.fileExists(atPath: chainURL.path) else {
            return .missing
        }
        guard let chain = logger.readChainState() else {
            return .error
        }

        guard let content = try? String(contentsOf: eventsURL, encoding: .utf8) else {
            return .error
        }

        let lines = content.split(whereSeparator: \ .isNewline).map(String.init)
        let dataLines = lines.dropFirst()

        var last = "GENESIS"
        var count = 0
        for line in dataLines {
            last = logger.sha256Hex("\(last)\n\(line)")
            count += 1
        }

        if count == chain.count && last == chain.lastHash {
            return .ok
        }
        return .mismatch
    }
}
