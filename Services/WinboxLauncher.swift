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
        let args = [trimmedHost, "\(safePort)"] + (trimmedUser.isEmpty ? [] : [trimmedUser])
        cfg.arguments = args

        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: appPath), configuration: cfg) { _, _ in }
    }
}
