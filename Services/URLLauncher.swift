import Foundation
import AppKit

enum URLLauncher {
    static func openHTTPS(host: String, port: Int, path: String) {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = host
        comps.port = (1...65535).contains(port) ? port : 443
        comps.path = path.isEmpty ? "/" : (path.hasPrefix("/") ? path : "/" + path)

        if let url = comps.url {
            NSWorkspace.shared.open(url)
        }
    }
}
