import Foundation
import AppKit

// MARK: - Lançador de URLs
/// Abre URLs no navegador padrão do macOS via NSWorkspace.
/// Suporta esquemas configuráveis (http, https, ftp, etc.) com porta customizada.
enum URLLauncher {

    /// Abre uma URL com esquema, host, porta e path específicos.
    /// Se a porta estiver fora do range válido (1-65535), usa a porta padrão do esquema.
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

    /// Retorna a porta padrão para um esquema conhecido.
    private static func defaultPort(for scheme: String) -> Int {
        switch scheme {
        case "http":  return 80
        case "https": return 443
        case "ftp":   return 21
        default:      return 80
        }
    }
}
