import Foundation
@preconcurrency import Network

enum ConnectivityChecker {
    private final class NmapTestState: @unchecked Sendable {
        let lock = NSLock()
        var finished = false
        var continuation: CheckedContinuation<NmapTestResult, Never>?
        let process: Process
        let pipe: Pipe

        init(continuation: CheckedContinuation<NmapTestResult, Never>, process: Process, pipe: Pipe) {
            self.continuation = continuation
            self.process = process
            self.pipe = pipe
        }

        func finish(_ result: NmapTestResult) {
            lock.lock()
            defer { lock.unlock() }
            guard !finished else { return }
            finished = true
            continuation?.resume(returning: result)
            continuation = nil
        }
    }
    private final class ProbeState: @unchecked Sendable {
        let lock = NSLock()
        var finished = false
    }

    private static let fixedNmapCandidates = [
        "/opt/homebrew/bin/nmap",
        "/opt/homebrew/sbin/nmap",
        "/usr/local/bin/nmap",
        "/usr/local/sbin/nmap",
        "/opt/local/bin/nmap",
        "/usr/bin/nmap"
    ]

    enum ProbeMethod: String {
        case tcp = "TCP"
        case nmap = "nmap"
    }

    enum FailureKind: String, Sendable {
        case dns
        case timeout
        case refused
        case unreachable
        case portClosed
        case invalidTarget
        case nmapAbsent
        case nmapFailed
        case cancelled
    }

    struct CheckResult: Sendable {
        let isOnline: Bool
        let method: ProbeMethod
        let effectivePort: Int
        let durationMs: Int
        let checkedAt: Date
        let failureKind: FailureKind?
        let failureMessage: String?
        let toolOutput: String?

        var errorDetail: String {
            guard !isOnline else { return "" }
            if let failureMessage, !failureMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return failureMessage
            }
            if let failureKind {
                switch failureKind {
                case .dns: return "Erro DNS"
                case .timeout: return "Timeout"
                case .refused: return "Conexão recusada (porta fechada)"
                case .unreachable: return "Host indisponível"
                case .portClosed: return "Porta fechada"
                case .invalidTarget: return "Destino inválido"
                case .nmapAbsent: return "nmap ausente"
                case .nmapFailed: return "nmap falhou"
                case .cancelled: return "Cancelado"
                }
            }
            return "Offline"
        }
    }

    static var hasNmap: Bool {
        resolveNmapPath() != nil
    }

    static var nmapPathDescription: String {
        resolveNmapPath() ?? "não encontrado"
    }

    struct NmapTestResult: Sendable {
        let ok: Bool
        let message: String
    }

    static func testNmapNow(timeoutSeconds: TimeInterval = 2.0) async -> NmapTestResult {
        guard let nmapPath = resolveNmapPath() else {
            return .init(ok: false, message: "nmap não encontrado")
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: nmapPath)
            process.arguments = ["--version"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let state = NmapTestState(continuation: continuation, process: process, pipe: pipe)
            let finish: @Sendable (NmapTestResult) -> Void = { result in
                state.finish(result)
            }

            process.terminationHandler = { _ in
                let data = state.pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                let firstLine = text.split(whereSeparator: \ .isNewline).map(String.init).first ?? ""
                if state.process.terminationStatus == 0 {
                    let ok = text.lowercased().contains("nmap") && text.lowercased().contains("version")
                    finish(.init(ok: ok, message: ok ? (firstLine.isEmpty ? "nmap OK" : firstLine) : (firstLine.isEmpty ? "nmap respondeu, mas saída inesperada" : firstLine)))
                } else {
                    finish(.init(ok: false, message: firstLine.isEmpty ? "nmap falhou (exit=\(state.process.terminationStatus))" : firstLine))
                }
            }

            do {
                try process.run()
            } catch {
                finish(.init(ok: false, message: "Falha ao executar nmap: \(error.localizedDescription)"))
                return
            }

            let timeoutMs = max(0.1, min(timeoutSeconds, 30.0))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutMs) {
                if state.process.isRunning {
                    state.process.terminate()
                    finish(.init(ok: false, message: "nmap timeout após \(Int(timeoutMs * 1000))ms"))
                }
            }
        }
    }

    static func checkAll(
        rows: [AccessRow],
        timeout: TimeInterval = 3.0,
        maxConcurrency: Int = 16,
        urlFallbackPorts: [Int] = [443, 80, 8443, 8080, 9443],
        onResult: (@Sendable (_ accessId: String, _ result: CheckResult) -> Void)? = nil
    ) async -> [String: CheckResult] {
        let limit = max(1, maxConcurrency)

        return await withTaskGroup(of: (String, CheckResult).self) { group in
            var iterator = rows.makeIterator()
            var inFlight = 0

            func submitNext() {
                guard !Task.isCancelled else { return }
                guard inFlight < limit else { return }
                guard let row = iterator.next() else { return }
                inFlight += 1
                group.addTask {
                    let result = await checkDetailed(row: row, timeout: timeout, urlFallbackPorts: urlFallbackPorts)
                    return (row.id, result)
                }
            }

            for _ in 0..<min(limit, rows.count) {
                submitNext()
            }

            var results: [String: CheckResult] = [:]
            while let (id, result) = await group.next() {
                inFlight = max(0, inFlight - 1)
                results[id] = result
                onResult?(id, result)
                submitNext()
            }

            return results
        }
    }

    static func check(row: AccessRow, timeout: TimeInterval = 3.0, urlFallbackPorts: [Int] = [443, 80, 8443, 8080, 9443]) async -> Bool {
        let detailed = await checkDetailed(row: row, timeout: timeout, urlFallbackPorts: urlFallbackPorts)
        return detailed.isOnline
    }

    private static func checkDetailed(
        row: AccessRow,
        timeout: TimeInterval,
        urlFallbackPorts: [Int]
    ) async -> CheckResult {
        let start = Date()
        let end: Date

        if Task.isCancelled {
            end = Date()
            return CheckResult(isOnline: false, method: .tcp, effectivePort: 0, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: .cancelled, failureMessage: nil, toolOutput: nil)
        }

        guard let endpoint = endpoint(for: row) else {
            end = Date()
            return CheckResult(isOnline: false, method: .tcp, effectivePort: 0, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: .invalidTarget, failureMessage: "Destino inválido", toolOutput: nil)
        }

        if row.kind == .ssh || row.kind == .rdp {
            if hasNmap {
                let nmap = await checkWithNmapDetailed(host: endpoint.host, ports: [endpoint.port], timeout: timeout)
                if !nmap.ok {
                    // nmap can return false negatives depending on timing/filters; confirm with a TCP connect probe.
                    let tcp = await checkTCPDetailed(host: endpoint.host, port: endpoint.port, timeout: timeout)
                    if tcp.ok {
                        end = Date()
                        return CheckResult(
                            isOnline: true,
                            method: .tcp,
                            effectivePort: endpoint.port,
                            durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                            checkedAt: end,
                            failureKind: nil,
                            failureMessage: nil,
                            toolOutput: nil
                        )
                    }

                    end = Date()
                    let combinedReason: String
                    if let tcpMsg = tcp.failureMessage, !tcpMsg.isEmpty {
                        let nmapMsg = (nmap.failureMessage ?? "nmap falhou").trimmingCharacters(in: .whitespacesAndNewlines)
                        combinedReason = "TCP: \(tcpMsg) | nmap: \(nmapMsg)"
                    } else {
                        combinedReason = nmap.failureMessage ?? "Offline"
                    }

                    return CheckResult(
                        isOnline: false,
                        method: .tcp,
                        effectivePort: endpoint.port,
                        durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                        checkedAt: end,
                        failureKind: tcp.failureKind ?? nmap.failureKind ?? .unreachable,
                        failureMessage: combinedReason,
                        toolOutput: nmap.output
                    )
                }
                end = Date()
                return CheckResult(
                    isOnline: nmap.ok,
                    method: .nmap,
                    effectivePort: nmap.openPort ?? endpoint.port,
                    durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                    checkedAt: end,
                    failureKind: nmap.ok ? nil : (nmap.failureKind ?? .nmapFailed),
                    failureMessage: nmap.ok ? nil : nmap.failureMessage,
                    toolOutput: nmap.output
                )
            }

            let tcp = await checkTCPDetailed(host: endpoint.host, port: endpoint.port, timeout: timeout)
            end = Date()
            return CheckResult(
                isOnline: tcp.ok,
                method: .tcp,
                effectivePort: endpoint.port,
                durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                checkedAt: end,
                failureKind: tcp.ok ? nil : tcp.failureKind,
                failureMessage: tcp.ok ? nil : tcp.failureMessage,
                toolOutput: nil
            )
        }

        // URL: try TCP first, then (optional) nmap fallback.
        let tcp = await checkTCPDetailed(host: endpoint.host, port: endpoint.port, timeout: timeout)
        if tcp.ok {
            end = Date()
            return CheckResult(isOnline: true, method: .tcp, effectivePort: endpoint.port, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: nil, failureMessage: nil, toolOutput: nil)
        }

        guard row.kind == .url else {
            end = Date()
            return CheckResult(isOnline: false, method: .tcp, effectivePort: endpoint.port, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: tcp.failureKind, failureMessage: tcp.failureMessage, toolOutput: nil)
        }

        let fallbackPorts = fallbackPortsForURL(from: row.url, preferredPort: endpoint.port, extras: urlFallbackPorts)
        if hasNmap {
            let nmap = await checkWithNmapDetailed(host: endpoint.host, ports: fallbackPorts, timeout: timeout)
            end = Date()
            return CheckResult(
                isOnline: nmap.ok,
                method: .nmap,
                effectivePort: nmap.openPort ?? endpoint.port,
                durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                checkedAt: end,
                failureKind: nmap.ok ? nil : (nmap.failureKind ?? .nmapFailed),
                failureMessage: nmap.ok ? nil : nmap.failureMessage,
                toolOutput: nmap.output
            )
        }

        end = Date()
        return CheckResult(isOnline: false, method: .tcp, effectivePort: endpoint.port, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: tcp.failureKind, failureMessage: tcp.failureMessage, toolOutput: nil)
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

    private static func fallbackPortsForURL(from raw: String, preferredPort: Int, extras: [Int]) -> [Int] {
        var ports: [Int] = []
        let normalized = normalizedURLInput(raw)
        if let comps = URLComponents(string: normalized) {
            let scheme = (comps.scheme ?? "http").lowercased()
            ports.append(defaultPort(for: scheme))
        }
        ports.append(preferredPort)
        ports.append(contentsOf: extras)

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

    private struct TCPProbeResult: Sendable {
        let ok: Bool
        let failureKind: FailureKind?
        let failureMessage: String?
    }

    private static func classifyNWError(_ error: NWError) -> TCPProbeResult {
        switch error {
        case .dns(let dnsError):
            return .init(ok: false, failureKind: .dns, failureMessage: "DNS: \(dnsError)")
        case .posix(let code):
            switch code {
            case .ECONNREFUSED:
                return .init(ok: false, failureKind: .refused, failureMessage: "Conexão recusada (porta fechada)")
            case .ETIMEDOUT:
                return .init(ok: false, failureKind: .timeout, failureMessage: "Timeout")
            case .EHOSTUNREACH, .ENETUNREACH:
                return .init(ok: false, failureKind: .unreachable, failureMessage: "Host indisponível")
            default:
                return .init(ok: false, failureKind: .unreachable, failureMessage: "Erro: \(code)")
            }
        default:
            return .init(ok: false, failureKind: .unreachable, failureMessage: "Falha de rede")
        }
    }

    private static func checkTCPDetailed(host: String, port: Int, timeout: TimeInterval) async -> TCPProbeResult {
        if Task.isCancelled {
            return .init(ok: false, failureKind: .cancelled, failureMessage: nil)
        }

        guard (1...65535).contains(port),
              let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return .init(ok: false, failureKind: .invalidTarget, failureMessage: "Porta inválida")
        }

        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "ConnectivityChecker.\(host).\(port)")
            let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
            let state = ProbeState()

            let complete: @Sendable (TCPProbeResult) -> Void = { value in
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
                    complete(.init(ok: true, failureKind: nil, failureMessage: nil))
                case .failed(let error):
                    complete(classifyNWError(error))
                case .cancelled:
                    complete(.init(ok: false, failureKind: .cancelled, failureMessage: nil))
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                complete(.init(ok: false, failureKind: .timeout, failureMessage: "Timeout"))
            }
        }
    }

    private struct NmapProbeResult: Sendable {
        let ok: Bool
        let openPort: Int?
        let failureKind: FailureKind?
        let failureMessage: String?
        let output: String
    }

    private static func truncateToolOutput(_ text: String, limit: Int = 1200) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count <= limit {
            return cleaned
        }
        let idx = cleaned.index(cleaned.startIndex, offsetBy: max(0, limit))
        return String(cleaned[..<idx]) + "…"
    }

    private static func parseOpenPortFromNmapOutput(_ text: String) -> Int? {
        // Example: "443/tcp open  https"
        let lower = text.lowercased()
        for line in lower.split(whereSeparator: \ .isNewline) {
            if line.contains("/tcp") && line.contains(" open") {
                if let slash = line.firstIndex(of: "/") {
                    let prefix = line[..<slash]
                    if let p = Int(prefix.trimmingCharacters(in: .whitespacesAndNewlines)), (1...65535).contains(p) {
                        return p
                    }
                }
            }
        }
        return nil
    }

    private static func checkWithNmapDetailed(host: String, ports: [Int], timeout: TimeInterval) async -> NmapProbeResult {
        if Task.isCancelled {
            return .init(ok: false, openPort: nil, failureKind: .cancelled, failureMessage: nil, output: "")
        }

        guard let nmapPath = resolveNmapPath() else {
            return .init(ok: false, openPort: nil, failureKind: .nmapAbsent, failureMessage: "nmap ausente", output: "")
        }
        guard !ports.isEmpty else {
            return .init(ok: false, openPort: nil, failureKind: .invalidTarget, failureMessage: "Portas inválidas", output: "")
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: nmapPath)
                process.arguments = [
                    "-sT",
                    "-Pn",
                    "-n",
                    "-T4",
                    "--max-retries", "1",
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
                    let rawOut = truncateToolOutput(output + "\n" + errors)

                    if process.terminationStatus != 0 {
                        let firstLine = (errors + "\n" + output).split(whereSeparator: \ .isNewline).map(String.init).first ?? ""
                        let msg = firstLine.isEmpty ? "nmap falhou (exit=\(process.terminationStatus))" : firstLine
                        continuation.resume(returning: .init(ok: false, openPort: nil, failureKind: .nmapFailed, failureMessage: msg, output: rawOut))
                        return
                    }

                    if let openPort = parseOpenPortFromNmapOutput(output + "\n" + errors) {
                        continuation.resume(returning: .init(ok: true, openPort: openPort, failureKind: nil, failureMessage: nil, output: rawOut))
                        return
                    }

                    if combined.contains("failed to resolve") || combined.contains("could not resolve") {
                        continuation.resume(returning: .init(ok: false, openPort: nil, failureKind: .dns, failureMessage: "Erro DNS", output: rawOut))
                        return
                    }
                    if combined.contains("host seems down") || combined.contains("0 hosts up") {
                        continuation.resume(returning: .init(ok: false, openPort: nil, failureKind: .unreachable, failureMessage: "Host indisponível", output: rawOut))
                        return
                    }

                    // With --open, closed ports may be omitted; treat as port closed.
                    continuation.resume(returning: .init(ok: false, openPort: nil, failureKind: .portClosed, failureMessage: "Porta fechada", output: rawOut))
                } catch {
                    continuation.resume(returning: .init(ok: false, openPort: nil, failureKind: .nmapFailed, failureMessage: "Falha ao executar nmap", output: ""))
                }
            }
        }
    }

    private static func resolveNmapPath() -> String? {
        if let fixedPath = fixedNmapCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return fixedPath
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "nmap"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !output.isEmpty, FileManager.default.isExecutableFile(atPath: output) else { return nil }
            return output
        } catch {
            return nil
        }
    }
}
