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
        guard !row.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let port = Int(row.port) else {
            return false
        }
        return await checkTCP(host: row.host, port: port, timeout: timeout)
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
