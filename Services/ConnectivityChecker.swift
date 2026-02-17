import Foundation
@preconcurrency import Network

enum ConnectivityChecker {
    private final class ProbeState: @unchecked Sendable {
        let lock = NSLock()
        var finished = false
    }

    static func checkAll(rows: [AccessRow], timeout: TimeInterval = 3.0) async -> [String: Bool] {
        var results: [String: Bool] = [:]
        for row in rows {
            let ok = await check(row: row, timeout: timeout)
            results[row.id] = ok
        }
        return results
    }

    static func check(row: AccessRow, timeout: TimeInterval = 3.0) async -> Bool {
        guard let endpoint = endpoint(for: row) else {
            return false
        }
        return await checkTCP(host: endpoint.host, port: endpoint.port, timeout: timeout)
    }

    private static func endpoint(for row: AccessRow) -> (host: String, port: Int)? {
        if row.kind == .url {
            let raw = row.url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty {
                let candidate = raw.contains("://") ? raw : "http://\(raw)"
                if let comps = URLComponents(string: candidate),
                   let host = comps.host?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !host.isEmpty {
                    let scheme = (comps.scheme ?? "http").lowercased()
                    let defaultPort = defaultPort(for: scheme)
                    let port = sanitizePort(comps.port ?? defaultPort, fallback: defaultPort)
                    return (host, port)
                }
            }
        }

        let host = row.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, let rawPort = Int(row.port) else {
            return nil
        }

        let fallback = row.kind == .ssh ? 22 : (row.kind == .rdp ? 3389 : 80)
        return (host, sanitizePort(rawPort, fallback: fallback))
    }

    private static func sanitizePort(_ port: Int, fallback: Int) -> Int {
        (1...65535).contains(port) ? port : fallback
    }

    private static func defaultPort(for scheme: String) -> Int {
        switch scheme {
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

    private static func checkTCP(host: String, port: Int, timeout: TimeInterval) async -> Bool {
        guard (1...65535).contains(port),
              let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "ConnectivityChecker.\(host).\(port)")
            let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
            let state = ProbeState()

            let complete: @Sendable (Bool) -> Void = { value in
                state.lock.lock()
                defer { state.lock.unlock() }
                guard !state.finished else { return }
                state.finished = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    complete(true)
                case .failed(_):
                    complete(false)
                case .cancelled:
                    complete(false)
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                complete(false)
            }
        }
    }
}
