import Foundation
import Combine

final class LogParser: ObservableObject {
    @Published var points: [ConnLogPoint] = []

    private let logURL: URL
    private let fm = FileManager.default

    init() {
        logURL = CSVStore.dataDirectoryURL.appendingPathComponent("conexoes.log")
        reload()
    }

    func reload() {
        guard let s = try? String(contentsOf: logURL, encoding: .utf8) else {
            points = []
            return
        }

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

        let dayDF = DateFormatter()
        dayDF.dateFormat = "yyyy-MM-dd"

        var out: [ConnLogPoint] = []
        for (dayKey, counts) in bucket {
            guard let day = dayDF.date(from: dayKey) else { continue }
            for (t, c) in counts {
                out.append(.init(day: day, type: t, count: c))
            }
        }

        points = out.sorted { $0.day < $1.day }
    }
}
