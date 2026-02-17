import Foundation

// MARK: - Cliente
struct Client: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var tags: String
    var notes: String
    init(id: String? = nil, name: String, tags: String = "", notes: String = "") {
        if let rawId = id, !rawId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.id = rawId
        } else {
            self.id = UUID().uuidString
        }
        self.name = name
        self.tags = tags
        self.notes = notes
    }
}

// MARK: - SSH
struct SSHServer: Identifiable, Hashable, Sendable {
    let id: String
    var alias: String
    let clientId: String
    var name: String
    var host: String
    var port: Int
    var user: String
    var tags: String
    var notes: String
    var isFavorite: Bool
    var openCount: Int
    var lastOpenedAt: String
    init(id: String? = nil, alias: String, clientId: String, name: String, host: String, port: Int = 22, user: String, tags: String = "", notes: String = "", isFavorite: Bool = false, openCount: Int = 0, lastOpenedAt: String = "") {
        if let rawId = id, !rawId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.id = rawId
        } else {
            self.id = UUID().uuidString
        }
        self.alias = alias
        self.clientId = clientId
        self.name = name
        self.host = host
        self.port = port
        self.user = user
        self.tags = tags
        self.notes = notes
        self.isFavorite = isFavorite
        self.openCount = openCount
        self.lastOpenedAt = lastOpenedAt
    }
}

// MARK: - RDP
struct RDPServer: Identifiable, Hashable, Sendable {
    let id: String
    var alias: String
    let clientId: String
    var name: String
    var host: String
    var port: Int
    var domain: String
    var user: String
    var tags: String
    var ignoreCert: Bool
    var fullScreen: Bool
    var dynamicResolution: Bool
    var width: Int?
    var height: Int?
    var notes: String
    var isFavorite: Bool
    var openCount: Int
    var lastOpenedAt: String
    init(id: String? = nil, alias: String, clientId: String, name: String, host: String, port: Int = 3389, domain: String = "", user: String, tags: String = "", ignoreCert: Bool = false, fullScreen: Bool = false, dynamicResolution: Bool = false, width: Int? = nil, height: Int? = nil, notes: String = "", isFavorite: Bool = false, openCount: Int = 0, lastOpenedAt: String = "") {
        if let rawId = id, !rawId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.id = rawId
        } else {
            self.id = UUID().uuidString
        }
        self.alias = alias
        self.clientId = clientId
        self.name = name
        self.host = host
        self.port = port
        self.domain = domain
        self.user = user
        self.tags = tags
        self.ignoreCert = ignoreCert
        self.fullScreen = fullScreen
        self.dynamicResolution = dynamicResolution
        self.width = width
        self.height = height
        self.notes = notes
        self.isFavorite = isFavorite
        self.openCount = openCount
        self.lastOpenedAt = lastOpenedAt
    }
}

// MARK: - URL Access
struct URLAccess: Identifiable, Hashable, Sendable {
    let id: String
    var alias: String
    let clientId: String
    var name: String
    var scheme: String
    var host: String
    var port: Int
    var path: String
    var tags: String
    var notes: String
    var isFavorite: Bool
    var openCount: Int
    var lastOpenedAt: String
    init(id: String? = nil, alias: String, clientId: String, name: String, scheme: String = "https", host: String, port: Int = 443, path: String = "", tags: String = "", notes: String = "", isFavorite: Bool = false, openCount: Int = 0, lastOpenedAt: String = "") {
        if let rawId = id, !rawId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.id = rawId
        } else {
            self.id = UUID().uuidString
        }
        self.alias = alias
        self.clientId = clientId
        self.name = name
        self.scheme = scheme
        self.host = host
        self.port = port
        self.path = path
        self.tags = tags
        self.notes = notes
        self.isFavorite = isFavorite
        self.openCount = openCount
        self.lastOpenedAt = lastOpenedAt
    }
}

// MARK: - Enum Tipos
enum ConnType: String, Codable, CaseIterable, Sendable {
    case ssh = "SSH"
    case rdp = "RDP"
    case url = "URL"
}

enum AccessKind: String, Codable, CaseIterable, Sendable {
    case ssh = "SSH"
    case rdp = "RDP"
    case url = "URL"
}

// MARK: - Log e Row
struct ConnLogPoint: Identifiable, Hashable, Sendable {
    let id: UUID = UUID()
    let day: Date
    let type: ConnType
    let count: Int
}

struct AccessRow: Identifiable, Sendable {
    let id: String
    let clientName: String
    let kind: AccessKind
    let alias: String
    let name: String
    let host: String
    let port: String
    let user: String
    let url: String
    let tags: String
    let notes: String
    let isFavorite: Bool
    let openCount: Int
    let lastOpenedAt: String
}
