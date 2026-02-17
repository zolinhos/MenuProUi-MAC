import Foundation

struct EventLogger {
    private let fm = FileManager.default
    private let maxEventsFileBytes: UInt64 = 5 * 1024 * 1024

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
            return
        }

        let fallback = [header(), line].joined(separator: "\n") + "\n"
        try? fallback.write(to: eventsURL, atomically: true, encoding: .utf8)
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

        do {
            if fm.fileExists(atPath: rotatedURL.path) {
                try? fm.removeItem(at: rotatedURL)
            }
            try fm.moveItem(at: url, to: rotatedURL)
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
}
