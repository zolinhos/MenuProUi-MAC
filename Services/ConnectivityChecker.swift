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

    private static let fixedNpingCandidates = [
        "/opt/homebrew/bin/nping",
        "/opt/homebrew/sbin/nping",
        "/usr/local/bin/nping",
        "/usr/local/sbin/nping",
        "/opt/local/bin/nping",
        "/usr/bin/nping"
    ]

    private static let fixedPingCandidates = [
        "/sbin/ping",
        "/usr/sbin/ping",
        "/bin/ping",
        "/usr/bin/ping"
    ]

    private static let fixedNcCandidates = [
        "/usr/bin/nc",
        "/bin/nc"
    ]

    private static let fixedCurlCandidates = [
        "/usr/bin/curl",
        "/bin/curl"
    ]

    private static let fixedRouteCandidates = [
        "/sbin/route",
        "/usr/sbin/route"
    ]

    private static let fixedScutilCandidates = [
        "/usr/sbin/scutil"
    ]

    enum ProbeMethod: String {
        case tcp = "TCP"
        case nmap = "nmap"
        case nc = "nc"
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

    static var hasNping: Bool {
        resolveNpingPath() != nil
    }

    static var nmapPathDescription: String {
        resolveNmapPath() ?? "não encontrado"
    }

    static var npingPathDescription: String {
        resolveNpingPath() ?? "não encontrado"
    }

    static var pingPathDescription: String {
        resolvePingPath() ?? "não encontrado"
    }

    static var ncPathDescription: String {
        resolveNcPath() ?? "não encontrado"
    }

    static var curlPathDescription: String {
        resolveCurlPath() ?? "não encontrado"
    }

    static var routePathDescription: String {
        resolveRoutePath() ?? "não encontrado"
    }

    static var scutilPathDescription: String {
        resolveScutilPath() ?? "não encontrado"
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
        var end: Date

        if Task.isCancelled {
            end = Date()
            return CheckResult(isOnline: false, method: .tcp, effectivePort: 0, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: .cancelled, failureMessage: nil, toolOutput: nil)
        }

        guard let endpoint = endpoint(for: row) else {
            end = Date()
            return CheckResult(isOnline: false, method: .tcp, effectivePort: 0, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: .invalidTarget, failureMessage: "Destino inválido", toolOutput: nil)
        }

        // Resolve host -> IP early to keep probes consistent and avoid DNS variability.
        // Aplica para todos os tipos (SSH, RDP, URL), não apenas URL.
        // Hosts locais (.local, mDNS) e link-local se beneficiam da resolução antecipada.
        var probeHost = endpoint.host
        var resolveNote: String? = nil
        if let resolved = await resolveHostIfNeeded(endpoint.host), resolved != endpoint.host {
            probeHost = resolved
            resolveNote = "RESOLVED: host=\(endpoint.host) -> ip=\(resolved)"
        }

        if row.kind == .mtk {
            // MTK/WinBox: prioriza TCP direto na porta 8291 para evitar falso offline
            // quando nmap diverge em alguns ambientes locais.
            let tcp = await checkTCPDetailed(host: probeHost, port: endpoint.port, timeout: timeout)
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

            let ncProbe = await checkWithNcDetailed(host: probeHost, port: endpoint.port)
            if ncProbe.ok {
                end = Date()
                return CheckResult(
                    isOnline: true,
                    method: .nc,
                    effectivePort: endpoint.port,
                    durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                    checkedAt: end,
                    failureKind: nil,
                    failureMessage: nil,
                    toolOutput: ncProbe.output
                )
            }

            end = Date()
            return CheckResult(
                isOnline: false,
                method: .tcp,
                effectivePort: endpoint.port,
                durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                checkedAt: end,
                failureKind: tcp.failureKind,
                failureMessage: tcp.failureMessage,
                toolOutput: ncProbe.output
            )
        }

        if row.kind == .ssh || row.kind == .rdp {
            if hasNmap {
                let nmap = await checkWithNmapDetailed(host: probeHost, ports: [endpoint.port], timeout: timeout)
                let tcp = await checkTCPDetailed(host: probeHost, port: nmap.openPort ?? endpoint.port, timeout: max(1.0, min(timeout, 2.5)))

                if nmap.ok == tcp.ok {
                    end = Date()
                    return CheckResult(
                        isOnline: nmap.ok,
                        method: nmap.ok ? .nmap : .tcp,
                        effectivePort: nmap.openPort ?? endpoint.port,
                        durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                        checkedAt: end,
                        failureKind: nmap.ok ? nil : (tcp.failureKind ?? nmap.failureKind ?? .unreachable),
                        failureMessage: nmap.ok ? nil : "TCP: \(tcpFailureSummary(tcp)) | nmap: \((nmap.failureMessage ?? "falhou").trimmingCharacters(in: .whitespacesAndNewlines))",
                        toolOutput: mergeToolOutputs(resolveNote: resolveNote, primary: nmap.output, attachments: [])
                    )
                }

                // Divergência: terceira via para desempate.
                let nc = await checkWithNcDetailed(host: probeHost, port: endpoint.port)
                let onlineVotes = [nmap.ok, tcp.ok, nc.ok].filter { $0 }.count
                end = Date()

                if onlineVotes >= 2 {
                    return CheckResult(
                        isOnline: true,
                        method: nc.ok ? .nc : (nmap.ok ? .nmap : .tcp),
                        effectivePort: nmap.openPort ?? endpoint.port,
                        durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                        checkedAt: end,
                        failureKind: nil,
                        failureMessage: nil,
                        toolOutput: mergeToolOutputs(resolveNote: resolveNote, primary: nmap.output, attachments: [
                            ("TCP_CONFIRM", tcp.ok ? "TCP_OK" : "TCP_FAIL: \(tcpFailureSummary(tcp))"),
                            ("NC_TIEBREAKER", nc.output)
                        ])
                    )
                }

                return CheckResult(
                    isOnline: false,
                    method: .tcp,
                    effectivePort: endpoint.port,
                    durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                    checkedAt: end,
                    failureKind: tcp.failureKind ?? nmap.failureKind ?? .unreachable,
                    failureMessage: "Divergência resolvida como offline (nmap/tcp/nc)",
                    toolOutput: mergeToolOutputs(resolveNote: resolveNote, primary: nmap.output, attachments: [
                        ("TCP_CONFIRM", tcp.ok ? "TCP_OK" : "TCP_FAIL: \(tcpFailureSummary(tcp))"),
                        ("NC_TIEBREAKER", nc.output)
                    ])
                )
            }

            // Sem nmap: TCP → nc fallback (para hosts locais com bind EINVAL).
            let tcp = await checkTCPDetailed(host: probeHost, port: endpoint.port, timeout: timeout)
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

            // Fallback nc para SSH/RDP quando nmap não está instalado.
            let ncProbe = await checkWithNcDetailed(host: probeHost, port: endpoint.port)
            if ncProbe.ok {
                end = Date()
                return CheckResult(
                    isOnline: true,
                    method: .nc,
                    effectivePort: endpoint.port,
                    durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                    checkedAt: end,
                    failureKind: nil,
                    failureMessage: nil,
                    toolOutput: ncProbe.output
                )
            }

            end = Date()
            return CheckResult(
                isOnline: false,
                method: .tcp,
                effectivePort: endpoint.port,
                durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                checkedAt: end,
                failureKind: tcp.failureKind,
                failureMessage: tcp.failureMessage,
                toolOutput: nil
            )
        }

        // URL: validar "UP" com duas formas (TCP + HTTP/curl).
        let tcp = await checkTCPDetailed(host: probeHost, port: endpoint.port, timeout: timeout)
        let curlOut = await curlDiagnosticsIfAvailable(url: row.url)
        let curlOk = curlLooksOnline(curlOut)
        let curlExit = toolExitCode(curlOut)
        let curlTimedOut = (curlExit == 28)
        if let curlOk {
            if tcp.ok == curlOk {
                end = Date()
                if tcp.ok {
                    return CheckResult(isOnline: true, method: .tcp, effectivePort: endpoint.port, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: nil, failureMessage: nil, toolOutput: nil)
                }
                return CheckResult(isOnline: false, method: .tcp, effectivePort: endpoint.port, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: tcp.failureKind ?? .unreachable, failureMessage: "HTTP/TCP offline", toolOutput: mergeToolOutputs(resolveNote: resolveNote, primary: nil, attachments: [("CURL", curlOut)]))
            }

            // Divergência entre métodos 1 e 2 -> terceira checagem.
            let ncTie = await checkWithNcDetailed(host: probeHost, port: endpoint.port)
            var onlineVotes = (tcp.ok ? 1 : 0) + (curlOk ? 1 : 0) + (ncTie.ok ? 1 : 0)

            if onlineVotes == 1 && hasNmap {
                let nmapTie = await checkWithNmapDetailed(host: probeHost, ports: [endpoint.port], timeout: timeout)
                onlineVotes += nmapTie.ok ? 1 : 0
                end = Date()
                if onlineVotes >= 2 {
                    if curlTimedOut {
                        return CheckResult(
                            isOnline: false,
                            method: .tcp,
                            effectivePort: endpoint.port,
                            durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                            checkedAt: end,
                            failureKind: .timeout,
                            failureMessage: "HTTP timeout (curl exit 28) com porta aberta; resolvido como offline",
                            toolOutput: mergeToolOutputs(resolveNote: resolveNote, primary: nmapTie.output, attachments: [("CURL", curlOut), ("NC_TIEBREAKER", ncTie.output)])
                        )
                    }
                    return CheckResult(
                        isOnline: true,
                        method: nmapTie.ok ? .nmap : (ncTie.ok ? .nc : .tcp),
                        effectivePort: nmapTie.openPort ?? endpoint.port,
                        durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                        checkedAt: end,
                        failureKind: nil,
                        failureMessage: nil,
                        toolOutput: mergeToolOutputs(resolveNote: resolveNote, primary: nmapTie.output, attachments: [("CURL", curlOut), ("NC_TIEBREAKER", ncTie.output)])
                    )
                }
                return CheckResult(
                    isOnline: false,
                    method: .tcp,
                    effectivePort: endpoint.port,
                    durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                    checkedAt: end,
                    failureKind: .unreachable,
                    failureMessage: "Divergência HTTP/TCP resolvida como offline (curl/tcp/nc/nmap)",
                    toolOutput: mergeToolOutputs(resolveNote: resolveNote, primary: nmapTie.output, attachments: [("CURL", curlOut), ("NC_TIEBREAKER", ncTie.output)])
                )
            }

            end = Date()
            if onlineVotes >= 2 {
                if curlTimedOut {
                    return CheckResult(isOnline: false, method: .tcp, effectivePort: endpoint.port, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: .timeout, failureMessage: "HTTP timeout (curl exit 28) com porta aberta; resolvido como offline", toolOutput: mergeToolOutputs(resolveNote: resolveNote, primary: nil, attachments: [("CURL", curlOut), ("NC_TIEBREAKER", ncTie.output)]))
                }
                return CheckResult(isOnline: true, method: ncTie.ok ? .nc : .tcp, effectivePort: endpoint.port, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: nil, failureMessage: nil, toolOutput: mergeToolOutputs(resolveNote: resolveNote, primary: nil, attachments: [("CURL", curlOut), ("NC_TIEBREAKER", ncTie.output)]))
            }
            return CheckResult(isOnline: false, method: .tcp, effectivePort: endpoint.port, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: .unreachable, failureMessage: "Divergência HTTP/TCP resolvida como offline (curl/tcp/nc)", toolOutput: mergeToolOutputs(resolveNote: resolveNote, primary: nil, attachments: [("CURL", curlOut), ("NC_TIEBREAKER", ncTie.output)]))
        }

        guard row.kind == .url else {
            end = Date()
            return CheckResult(isOnline: false, method: .tcp, effectivePort: endpoint.port, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: tcp.failureKind, failureMessage: tcp.failureMessage, toolOutput: nil)
        }

        let fallbackPorts = fallbackPortsForURL(from: row.url, preferredPort: endpoint.port, extras: urlFallbackPorts)
        if hasNmap {
            let nmap = await checkWithNmapDetailed(host: probeHost, ports: fallbackPorts, timeout: timeout)
            end = Date()

            let tcpNote = "TCP_FAIL: \(tcpFailureSummary(tcp))"

            if nmap.ok {
                let confirmedPort = nmap.openPort ?? endpoint.port
                let tcpConfirm = await checkTCPDetailed(host: probeHost, port: confirmedPort, timeout: max(1.0, min(timeout, 2.5)))
                if !tcpConfirm.ok {
                    let reason = "nmap indicou porta aberta, mas TCP falhou: \(tcpFailureSummary(tcpConfirm))"
                    let toolOut = mergeToolOutputs(resolveNote: resolveNote, primary: nmap.output, attachments: [
                        ("TCP", tcpNote),
                        ("TCP_CONFIRM", "TCP_FAIL: \(tcpFailureSummary(tcpConfirm))")
                    ])
                    return CheckResult(
                        isOnline: false,
                        method: .tcp,
                        effectivePort: confirmedPort,
                        durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                        checkedAt: end,
                        failureKind: tcpConfirm.failureKind ?? .unreachable,
                        failureMessage: reason,
                        toolOutput: toolOut
                    )
                }
                let toolOut = mergeToolOutputs(resolveNote: resolveNote, primary: nmap.output, attachments: [("TCP", tcpNote)])
                return CheckResult(
                    isOnline: true,
                    method: .nmap,
                    effectivePort: confirmedPort,
                    durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                    checkedAt: end,
                    failureKind: nil,
                    failureMessage: nil,
                    toolOutput: toolOut
                )
            }

            // Tertiary fallback: nc can succeed where NWConnection and nmap fail (macOS nsock bind issue).
            let ncProbe = await checkWithNcDetailed(host: probeHost, port: endpoint.port)
            if ncProbe.ok {
                end = Date()
                let toolOut = mergeToolOutputs(resolveNote: resolveNote, primary: nmap.output, attachments: [
                    ("TCP", tcpNote),
                    ("NC_FALLBACK", ncProbe.output)
                ])
                return CheckResult(
                    isOnline: true,
                    method: .nc,
                    effectivePort: endpoint.port,
                    durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                    checkedAt: end,
                    failureKind: nil,
                    failureMessage: nil,
                    toolOutput: toolOut
                )
            }

            // All primary methods failed — collect diagnostics for logging.
            let npingOut = await npingDiagnosticsIfAvailable(host: probeHost, port: endpoint.port)
            let pingOut = await pingDiagnosticsIfAvailable(host: probeHost)
            let curlOut = await curlDiagnosticsIfAvailable(url: row.url)
            let routeOut = await routeDiagnosticsIfAvailable(host: probeHost)
            let scutilOut = await scutilDiagnosticsIfAvailable(host: probeHost)

            let attachments: [(String, String?)] = [
                ("TCP", tcpNote), ("NPING", npingOut), ("PING", pingOut),
                ("NC", ncProbe.output), ("CURL", curlOut),
                ("ROUTE", routeOut), ("SCUTIL", scutilOut)
            ]
            let toolOut = mergeToolOutputs(resolveNote: resolveNote, primary: nmap.output, attachments: attachments)

            let nmapMsg = (nmap.failureMessage ?? "nmap falhou").trimmingCharacters(in: .whitespacesAndNewlines)
            let combinedReason = "TCP: \(tcpFailureSummary(tcp)) | nmap: \(nmapMsg)"

            return CheckResult(
                isOnline: false,
                method: .nmap,
                effectivePort: nmap.openPort ?? endpoint.port,
                durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)),
                checkedAt: end,
                failureKind: nmap.failureKind ?? .nmapFailed,
                failureMessage: combinedReason,
                toolOutput: toolOut
            )
        }

        end = Date()
        return CheckResult(isOnline: false, method: .tcp, effectivePort: endpoint.port, durationMs: max(0, Int(end.timeIntervalSince(start) * 1000.0)), checkedAt: end, failureKind: tcp.failureKind, failureMessage: tcp.failureMessage, toolOutput: nil)
    }

    private static func mergeToolOutputs(resolveNote: String?, primary: String?, attachments: [(String, String?)]) -> String? {
        var parts: [String] = []
        if let resolveNote, !resolveNote.isEmpty { parts.append(resolveNote) }
        if let primary, !primary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append(primary) }
        for (label, content) in attachments {
            guard let content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            parts.append("---\n\(label):\n\(content)")
        }
        if parts.isEmpty { return nil }
        return parts.joined(separator: "\n")
    }

    private static func resolveHostIfNeeded(_ host: String) async -> String? {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if isIPv4Address(trimmed) { return trimmed }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var hints = addrinfo(
                    ai_flags: AI_ADDRCONFIG,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: IPPROTO_TCP,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )

                var res: UnsafeMutablePointer<addrinfo>? = nil
                let err = getaddrinfo(trimmed, nil, &hints, &res)
                guard err == 0, let first = res else {
                    if let res { freeaddrinfo(res) }
                    continuation.resume(returning: nil)
                    return
                }

                defer { freeaddrinfo(res) }

                // Prefer IPv4.
                var current: UnsafeMutablePointer<addrinfo>? = first
                var ipv6Fallback: String? = nil
                while let node = current {
                    if let addr = node.pointee.ai_addr {
                        if node.pointee.ai_family == AF_INET {
                            var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                            let sin = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                            var saddr = sin.sin_addr
                            if inet_ntop(AF_INET, &saddr, &buf, socklen_t(INET_ADDRSTRLEN)) != nil {
                                continuation.resume(returning: String(cString: buf))
                                return
                            }
                        } else if node.pointee.ai_family == AF_INET6 {
                            var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                            let sin6 = addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                            var saddr6 = sin6.sin6_addr
                            if inet_ntop(AF_INET6, &saddr6, &buf, socklen_t(INET6_ADDRSTRLEN)) != nil {
                                ipv6Fallback = String(cString: buf)
                            }
                        }
                    }
                    current = node.pointee.ai_next
                }

                continuation.resume(returning: ipv6Fallback)
            }
        }
    }

    private static func isIPv4Address(_ text: String) -> Bool {
        let parts = text.split(separator: ".")
        guard parts.count == 4 else { return false }
        for part in parts {
            guard let n = Int(part), (0...255).contains(n) else { return false }
        }
        return true
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

        let fallback: Int
        switch row.kind {
        case .ssh:
            fallback = 22
        case .rdp:
            fallback = 3389
        case .mtk:
            fallback = 8291
        case .url:
            fallback = 80
        }
        return (host, sanitizePort(rawPort, fallback: fallback))
    }

    private static func fallbackPortsForURL(from raw: String, preferredPort: Int, extras: [Int]) -> [Int] {
        var ports: [Int] = []
        let normalized = normalizedURLInput(raw)
        if let comps = URLComponents(string: normalized) {
            let scheme = (comps.scheme ?? "http").lowercased()
            let schemeDefault = defaultPort(for: scheme)

            // If the URL explicitly specifies a port, respect it and avoid scanning unrelated fallback ports.
            if let explicit = comps.port {
                ports.append(sanitizePort(explicit, fallback: schemeDefault))
            } else {
                ports.append(schemeDefault)
                ports.append(preferredPort)
                ports.append(contentsOf: extras)
            }
        } else {
            ports.append(preferredPort)
            ports.append(contentsOf: extras)
        }

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

    private static func truncateToolOutput(_ text: String, limit: Int = 4000) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count <= limit {
            return cleaned
        }
        let idx = cleaned.index(cleaned.startIndex, offsetBy: max(0, limit))
        return String(cleaned[..<idx]) + "…"
    }

    private static func tcpFailureSummary(_ tcp: TCPProbeResult) -> String {
        if let msg = tcp.failureMessage, !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return msg
        }
        if let kind = tcp.failureKind {
            return kind.rawValue
        }
        return "falha_tcp"
    }

    private static func toolExitCode(_ output: String?) -> Int? {
        guard let output, !output.isEmpty else { return nil }
        var lastExit: Int? = nil
        for line in output.split(whereSeparator: \.isNewline) {
            let text = String(line)
            if text.hasPrefix("EXIT: ") {
                lastExit = Int(text.replacingOccurrences(of: "EXIT: ", with: "").trimmingCharacters(in: .whitespaces))
            }
        }
        return lastExit
    }

    private static func curlLooksOnline(_ output: String?) -> Bool? {
        guard let output, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let exitCode = toolExitCode(output) else { return nil }
        if exitCode != 0 { return false }
        return output.lowercased().contains("http/")
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
                let scanPorts = ports.map(String.init).joined(separator: ",")
                let hostTimeoutMs = max(1000, Int(timeout * 1000))

                func runNmap(extraArgs: [String], label: String) -> NmapProbeResult {
                    let process = Process()
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()

                    process.executableURL = URL(fileURLWithPath: nmapPath)
                    let args: [String] = [
                        "-sT",
                        "-n",
                        "-T4",
                        "--reason",
                        "--max-retries", "1",
                        "--host-timeout", "\(hostTimeoutMs)ms"
                    ] + extraArgs + [
                        "-p", scanPorts,
                        host
                    ]
                    process.arguments = args
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
                        let cmdLine = ([nmapPath] + args).joined(separator: " ")
                        let decorated = "SCAN: \(label)\nCMD: \(cmdLine)\nEXIT: \(process.terminationStatus)\n" + output + "\n" + errors
                        let rawOut = truncateToolOutput(decorated)

                        if process.terminationStatus != 0 {
                            let firstLine = (errors + "\n" + output).split(whereSeparator: \.isNewline).map(String.init).first ?? ""
                            let msg = firstLine.isEmpty ? "nmap falhou (exit=\(process.terminationStatus))" : firstLine
                            return .init(ok: false, openPort: nil, failureKind: .nmapFailed, failureMessage: msg, output: rawOut)
                        }

                        if let openPort = parseOpenPortFromNmapOutput(output + "\n" + errors) {
                            return .init(ok: true, openPort: openPort, failureKind: nil, failureMessage: nil, output: rawOut)
                        }

                        if combined.contains("failed to resolve") || combined.contains("could not resolve") {
                            return .init(ok: false, openPort: nil, failureKind: .dns, failureMessage: "Erro DNS", output: rawOut)
                        }
                        if combined.contains("host seems down") || combined.contains("0 hosts up") {
                            return .init(ok: false, openPort: nil, failureKind: .unreachable, failureMessage: "Host indisponível", output: rawOut)
                        }

                        if combined.contains("filtered") {
                            return .init(ok: false, openPort: nil, failureKind: .timeout, failureMessage: "Filtrado/sem resposta", output: rawOut)
                        }
                        return .init(ok: false, openPort: nil, failureKind: .portClosed, failureMessage: "Porta fechada", output: rawOut)
                    } catch {
                        return .init(ok: false, openPort: nil, failureKind: .nmapFailed, failureMessage: "Falha ao executar nmap", output: "")
                    }
                }

                // Primeiro sem -Pn; se host-discovery bloquear o alvo, repete com -Pn.
                let first = runNmap(extraArgs: [], label: "default")
                if first.ok {
                    continuation.resume(returning: first)
                    return
                }

                let lowerFirst = first.output.lowercased()
                let shouldRetryWithPn = first.failureKind == .unreachable &&
                    (lowerFirst.contains("host seems down") || lowerFirst.contains("0 hosts up"))

                if shouldRetryWithPn {
                    let second = runNmap(extraArgs: ["-Pn"], label: "retry-with-Pn")
                    if second.ok {
                        continuation.resume(returning: second)
                        return
                    }
                    let mergedOutput = truncateToolOutput([first.output, second.output].joined(separator: "\n---\n"))
                    continuation.resume(returning: .init(
                        ok: false,
                        openPort: nil,
                        failureKind: second.failureKind ?? first.failureKind,
                        failureMessage: second.failureMessage ?? first.failureMessage,
                        output: mergedOutput
                    ))
                    return
                }

                continuation.resume(returning: first)
            }
        }
    }

    private enum NpingMode: Sendable {
        case tcpSyn
        case tcpConnect
        case icmp
        case udp53
    }

    private static func npingDiagnosticsIfAvailable(host: String, port: Int) async -> String? {
        guard hasNping else { return nil }
        // Try TCP SYN first (may require sudo), then fallback to TCP connect (no sudo).
        let tcpSyn = await checkWithNping(host: host, port: port, mode: .tcpSyn, timeout: 2.5)
        if tcpSyn.ok {
            return tcpSyn.output
        }
        if tcpSyn.output.lowercased().contains("root") || tcpSyn.output.lowercased().contains("privilege") {
            let tcpConnect = await checkWithNping(host: host, port: port, mode: .tcpConnect, timeout: 2.5)
            return [tcpSyn.output, "---\nFALLBACK: tcp-connect\n" + tcpConnect.output].joined(separator: "\n")
        }

        // Also run ICMP (may require privileges). Append if we got something.
        let icmp = await checkWithNping(host: host, port: nil, mode: .icmp, timeout: 2.5)
        if !icmp.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [tcpSyn.output, "---\nICMP\n" + icmp.output].joined(separator: "\n")
        }

        return tcpSyn.output
    }

    private static func pingDiagnosticsIfAvailable(host: String) async -> String? {
        guard let pingPath = resolvePingPath() else { return nil }
        // macOS: -c 1 (one packet), -o (exit after one reply)
        return await runGenericTool(executablePath: pingPath, args: ["-c", "1", "-o", host], timeout: 2.5)
    }

    private struct NcProbeResult: Sendable {
        let ok: Bool
        let output: String?
    }

    /// Quick TCP probe via /usr/bin/nc. Works even when NWConnection and nmap fail
    /// (macOS nsock bind(0.0.0.0:0) EINVAL issue).
    private static func checkWithNcDetailed(host: String, port: Int) async -> NcProbeResult {
        guard let ncPath = resolveNcPath() else {
            return .init(ok: false, output: nil)
        }
        let safePort = max(1, min(port, 65535))
        let output = await runGenericTool(executablePath: ncPath, args: ["-zv", "-w", "2", host, "\(safePort)"], timeout: 2.8)
        // nc exit 0 = connection succeeded.
        let succeeded = output.contains("EXIT: 0")
        return .init(ok: succeeded, output: output)
    }

    private static func ncDiagnosticsIfAvailable(host: String, port: Int) async -> String? {
        guard let ncPath = resolveNcPath() else { return nil }
        let safePort = max(1, min(port, 65535))
        // macOS netcat: -z (scan), -v (verbose), -w seconds (timeout)
        return await runGenericTool(executablePath: ncPath, args: ["-zv", "-w", "2", host, "\(safePort)"], timeout: 2.8)
    }

    private static func curlDiagnosticsIfAvailable(url: String) async -> String? {
        let raw = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        guard let curlPath = resolveCurlPath() else { return nil }
        let normalized = normalizedURLInput(raw)
        let isHTTPS = normalized.lowercased().hasPrefix("https://")

        // Probe principal: HEAD curto. Para HTTPS usamos -k para não derrubar reachability por cert self-signed.
        let headArgs = ["-I", "--connect-timeout", "2", "--max-time", "3", "-sS"] + (isHTTPS ? ["-k"] : []) + [normalized]
        let head = await runGenericTool(executablePath: curlPath, args: headArgs, timeout: 3.3)

        // Se já ficou claro que está online, retorna direto.
        if curlLooksOnline(head) == true {
            return head
        }

        // Fallback: alguns serviços não respondem bem a HEAD/TLS específico.
        // Tenta GET com headers para preservar detecção de "http/" no parser.
        let getArgs = ["-i", "--connect-timeout", "2", "--max-time", "3", "-sS"] + (isHTTPS ? ["-k"] : []) + [normalized]
        let get = await runGenericTool(executablePath: curlPath, args: getArgs, timeout: 3.3)
        return [head, "---\nCURL_FALLBACK_GET\n" + get].joined(separator: "\n")
    }

    private static func routeDiagnosticsIfAvailable(host: String) async -> String? {
        guard let routePath = resolveRoutePath() else { return nil }
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // macOS: route -n get <host>
        return await runGenericTool(executablePath: routePath, args: ["-n", "get", trimmed], timeout: 2.0)
    }

    private static func scutilDiagnosticsIfAvailable(host: String) async -> String? {
        guard let scutilPath = resolveScutilPath() else { return nil }
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // macOS: scutil -r <host>
        return await runGenericTool(executablePath: scutilPath, args: ["-r", trimmed], timeout: 2.0)
    }

    private static func runGenericTool(executablePath: String, args: [String], timeout: TimeInterval) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = args
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()

                    let deadline = Date().addingTimeInterval(max(0.2, min(timeout, 30.0)))
                    while process.isRunning, Date() < deadline {
                        Thread.sleep(forTimeInterval: 0.03)
                    }
                    if process.isRunning {
                        process.terminate()
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                    process.waitUntilExit()

                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let stdout = String(data: outData, encoding: .utf8) ?? ""
                    let stderr = String(data: errData, encoding: .utf8) ?? ""
                    let cmdLine = ([executablePath] + args).joined(separator: " ")
                    let decorated = "CMD: \(cmdLine)\nEXIT: \(process.terminationStatus)\n" + stdout + "\n" + stderr
                    continuation.resume(returning: truncateToolOutput(decorated))
                } catch {
                    continuation.resume(returning: truncateToolOutput("CMD: \(executablePath) \(args.joined(separator: " "))\nEXIT: -1\nFalha ao executar: \(error.localizedDescription)"))
                }
            }
        }
    }

    private struct NpingProbeResult: Sendable {
        let ok: Bool
        let output: String
    }

    private static func checkWithNping(host: String, port: Int?, mode: NpingMode, timeout: TimeInterval) async -> NpingProbeResult {
        guard let npingPath = resolveNpingPath() else {
            return .init(ok: false, output: "nping não encontrado")
        }

        let args: [String]
        switch mode {
        case .tcpSyn:
            let p = max(1, min(port ?? 80, 65535))
            args = ["--tcp", "-p", "\(p)", "--flags", "syn", host]
        case .tcpConnect:
            let p = max(1, min(port ?? 80, 65535))
            args = ["--tcp-connect", "-p", "\(p)", host]
        case .icmp:
            args = ["--icmp", host]
        case .udp53:
            args = ["--udp", "-p", "53", host]
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                let outPipe = Pipe()
                let errPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: npingPath)
                process.arguments = args
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()

                    let deadline = Date().addingTimeInterval(max(0.2, min(timeout, 30.0)))
                    while process.isRunning, Date() < deadline {
                        Thread.sleep(forTimeInterval: 0.03)
                    }
                    if process.isRunning {
                        process.terminate()
                        // brief grace period
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                    process.waitUntilExit()

                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let stdout = String(data: outData, encoding: .utf8) ?? ""
                    let stderr = String(data: errData, encoding: .utf8) ?? ""

                    let cmdLine = ([npingPath] + args).joined(separator: " ")
                    let decorated = "CMD: \(cmdLine)\nEXIT: \(process.terminationStatus)\n" + stdout + "\n" + stderr
                    let trimmed = truncateToolOutput(decorated)

                    let lower = (stdout + "\n" + stderr).lowercased()
                    let ok = lower.contains("rcvd") || lower.contains("replies received: 1") || lower.contains("received: 1") || lower.contains("syn,ack")
                    continuation.resume(returning: .init(ok: ok, output: trimmed))
                } catch {
                    continuation.resume(returning: .init(ok: false, output: "Falha ao executar nping: \(error.localizedDescription)"))
                }
            }
        }
    }

    private static func resolveNpingPath() -> String? {
        if let fixedPath = fixedNpingCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return fixedPath
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "nping"]
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

    private static func resolvePingPath() -> String? {
        if let fixedPath = fixedPingCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return fixedPath
        }
        return resolveViaWhich("ping")
    }

    private static func resolveNcPath() -> String? {
        if let fixedPath = fixedNcCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return fixedPath
        }
        return resolveViaWhich("nc")
    }

    private static func resolveCurlPath() -> String? {
        if let fixedPath = fixedCurlCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return fixedPath
        }
        return resolveViaWhich("curl")
    }

    private static func resolveRoutePath() -> String? {
        if let fixedPath = fixedRouteCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return fixedPath
        }
        return resolveViaWhich("route")
    }

    private static func resolveScutilPath() -> String? {
        if let fixedPath = fixedScutilCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return fixedPath
        }
        return resolveViaWhich("scutil")
    }

    private static func resolveViaWhich(_ tool: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", tool]
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
