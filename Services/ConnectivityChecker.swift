import Foundation
@preconcurrency import Network

enum ConnectivityChecker {
    private final class ProbeState: @unchecked Sendable {
        let lock = NSLock()
        var finished = false
    }

    private static let nmapExecutablePath: String? = {
        let candidates = ["/opt/homebrew/bin/nmap", "/usr/local/bin/nmap", "/usr/bin/nmap"]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }()

    static var hasNmap: Bool {
        nmapExecutablePath != nil
    }

    static func checkAll(rows: [AccessRow], timeout: TimeInterval = 3.0) async -> [String: Bool] {
        await withTaskGroup(of: (String, Bool).self) { group in
            for row in rows {
                group.addTask {
                    let ok = await check(row: row, timeout: timeout)
                    return (row.id, ok)
                }
            }

            var results: [String: Bool] = [:]
            for await (id, isOnline) in group {
                results[id] = isOnline
            }
            return results
        }
    }

    static func check(row: AccessRow, timeout: TimeInterval = 3.0) async -> Bool {
        guard let endpoint = endpoint(for: row) else {
            return false
        }

        if row.kind == .ssh || row.kind == .rdp {
            if hasNmap {
                return await checkWithNmap(host: endpoint.host, ports: [endpoint.port], timeout: timeout)
            }
            return await checkTCP(host: endpoint.host, port: endpoint.port, timeout: timeout)
        }

        if await checkTCP(host: endpoint.host, port: endpoint.port, timeout: timeout) {
            return true
        }

        guard row.kind == .url else {
            return false
        }

        let fallbackPorts = fallbackPortsForURL(from: row.url, preferredPort: endpoint.port)
        return await checkWithNmap(host: endpoint.host, ports: fallbackPorts, timeout: timeout)
    }

    private static func endpoint(for row: AccessRow) -> (host: String, port: Int)? {
        if row.kind == .url {
            let raw = row.url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty {
                let candidate = normalizedURLInput(raw)
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

    private static func fallbackPortsForURL(from raw: String, preferredPort: Int) -> [Int] {
        var ports: [Int] = []
        let normalized = normalizedURLInput(raw)
        if let comps = URLComponents(string: normalized) {
            let scheme = (comps.scheme ?? "http").lowercased()
            ports.append(defaultPort(for: scheme))
        }
        ports.append(preferredPort)
        ports.append(contentsOf: [443, 80, 8443, 8080, 9443])

        var uniquePorts: [Int] = []
        for port in ports {
            if (1...65535).contains(port), !uniquePorts.contains(port) {
                uniquePorts.append(port)
            }
        }
        return uniquePorts
    }

    private static func normalizedURLInput(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "http://" }
        if trimmed.contains("://") { return trimmed }

        if let colonIndex = trimmed.firstIndex(of: ":") {
            let schemePart = String(trimmed[..<colonIndex]).lowercased()
            let remainder = String(trimmed[trimmed.index(after: colonIndex)...])
            if isValidScheme(schemePart), !remainder.isEmpty, !remainder.hasPrefix("//") {
                return "\(schemePart)://\(remainder)"
            }
        }

        return "http://\(trimmed)"
    }

    private static func isValidScheme(_ value: String) -> Bool {
        guard let first = value.first else { return false }
        guard first.isLetter else { return false }
        return value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }
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

    private static func checkWithNmap(host: String, ports: [Int], timeout: TimeInterval) async -> Bool {
        guard let nmapPath = nmapExecutablePath else { return false }
        guard !ports.isEmpty else { return false }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: nmapPath)
                process.arguments = [
                    "-Pn",
                    "-n",
                    "-T4",
                    "--max-retries", "0",
                    "--host-timeout", "\(max(1, Int(timeout * 1000)))ms",
                    "--open",
                    "-p", ports.map(String.init).joined(separator: ","),
                    host
                ]
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let errors = String(data: errorData, encoding: .utf8) ?? ""
                    let combined = (output + "\n" + errors).lowercased()

                    let hasOpenTcp = combined.contains("/tcp") && combined.contains(" open")
                    continuation.resume(returning: hasOpenTcp)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
