import Foundation
import AppKit

enum RDPFileWriter {
    static func rdpDir() -> URL {
        CSVStore.dataDirectoryURL.appendingPathComponent("rdpfiles", isDirectory: true)
    }

    static func ensureDir() {
        try? FileManager.default.createDirectory(at: rdpDir(), withIntermediateDirectories: true)
    }

    static func fileURL(alias: String) -> URL {
        rdpDir().appendingPathComponent("\(alias).rdp")
    }

    static func writeAndOpen(server: RDPServer) {
        ensureDir()
        let url = fileURL(alias: server.alias)
        let port = (1...65535).contains(server.port) ? server.port : 3389
        let authenticationLevel = server.ignoreCert ? 0 : 2
        let screenModeId = server.fullScreen ? 2 : 1
        let smartSizing = server.dynamicResolution ? 1 : 0
        let desktopWidth = server.width ?? 1280
        let desktopHeight = server.height ?? 720

        let content =
"""
full address:s:\(server.host)
server port:i:\(port)

username:s:\(server.user)
domain:s:\(server.domain)

prompt for credentials on client:i:1
authentication level:i:\(authenticationLevel)
redirectclipboard:i:1
compression:i:1
screen mode id:i:\(screenModeId)
use multimon:i:0
smart sizing:i:\(smartSizing)
desktopwidth:i:\(desktopWidth)
desktopheight:i:\(desktopHeight)
"""

        try? content.data(using: .utf8)?.write(to: url, options: .atomic)
        NSWorkspace.shared.open(url)
    }
}
