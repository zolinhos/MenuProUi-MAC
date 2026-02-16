import Foundation
import AppKit

enum SSHLauncher {
    static func openSSH(host: String, port: Int, user: String) {
        let p = (1...65535).contains(port) ? port : 22
        let u = user.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? user
        let h = host.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? host

        if let url = URL(string: "ssh://\(u)@\(h):\(p)") {
            NSWorkspace.shared.open(url)
        }
    }
}
