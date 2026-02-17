import Foundation
import AppKit

// MARK: - Lançador de SSH
/// Abre conexões SSH via URL scheme `ssh://` usando o handler padrão do macOS
/// (Terminal, iTerm ou outro cliente SSH configurado).
enum SSHLauncher {

    /// Abre uma conexão SSH com o host, porta e usuário informados.
    /// Porta fora do range válido (1-65535) é substituída por 22.
    static func openSSH(host: String, port: Int, user: String) {
        let p = (1...65535).contains(port) ? port : 22
        let u = user.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? user
        let h = host.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? host

        if let url = URL(string: "ssh://\(u)@\(h):\(p)") {
            NSWorkspace.shared.open(url)
        }
    }
}
