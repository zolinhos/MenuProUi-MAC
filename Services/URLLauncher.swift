import Foundation
import AppKit

enum URLLauncher {
    static func openURL(raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        let candidate = value.contains("://") ? value : "http://\(value)"
        if let url = URL(string: candidate) {
            NSWorkspace.shared.open(url)
        }
    }

    static func openURL(scheme: String, host: String, port: Int, path: String) {
        var comps = URLComponents()
        let normalizedScheme = scheme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        comps.scheme = normalizedScheme
        comps.host = host
        let fallbackPort = defaultPort(for: normalizedScheme)
        comps.port = (1...65535).contains(port) ? port : fallbackPort
        comps.path = path.isEmpty ? "/" : (path.hasPrefix("/") ? path : "/" + path)

        if let url = comps.url {
            NSWorkspace.shared.open(url)
        }
    }

    static func openHTTPS(host: String, port: Int, path: String) {
        openURL(scheme: "https", host: host, port: port, path: path)
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
}
