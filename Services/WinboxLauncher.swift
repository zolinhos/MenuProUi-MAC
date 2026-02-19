import Foundation
import AppKit

/// Abre o WinBox (MikroTik) no macOS com host/porta/usuário.
enum WinboxLauncher {
    private static let appPath = "/Applications/WinBox.app"

    static func open(host: String, port: Int, user: String) {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else { return }
        let safePort = (1...65535).contains(port) ? port : 8291
        let trimmedUser = user.trimmingCharacters(in: .whitespacesAndNewlines)

        let cfg = NSWorkspace.OpenConfiguration()
        // WinBox no macOS interpreta melhor "host:porta" como primeiro argumento.
        // Passar a porta como argumento separado pode ser lido como usuário.
        let endpoint = "\(trimmedHost):\(safePort)"
        let args = [endpoint] + (trimmedUser.isEmpty ? [] : [trimmedUser])
        cfg.arguments = args

        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: appPath), configuration: cfg) { _, _ in }
    }
}
