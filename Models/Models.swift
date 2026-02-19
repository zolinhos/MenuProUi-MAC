import Foundation

// MARK: - Cliente
/// Representa um cliente cadastrado no sistema.
/// Cada cliente pode ter múltiplos acessos (SSH, RDP, URL, MTK) vinculados.
struct Client: Identifiable, Hashable, Sendable {
    /// Identificador único do cliente (UUID ou definido pelo usuário).
    let id: String
    /// Nome de exibição do cliente.
    var name: String
    /// Tags para facilitar busca e organização.
    var tags: String
    /// Observações livres.
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
/// Representa um servidor SSH cadastrado, vinculado a um cliente.
struct SSHServer: Identifiable, Hashable, Sendable {
    let id: String
    /// Apelido curto para identificação rápida na lista.
    var alias: String
    /// ID do cliente ao qual este acesso pertence.
    let clientId: String
    /// Nome descritivo do servidor.
    var name: String
    /// Host ou IP do servidor SSH.
    var host: String
    /// Porta SSH (padrão: 22).
    var port: Int
    /// Nome de usuário para conexão.
    var user: String
    var tags: String
    var notes: String
    /// Indica se este acesso está marcado como favorito.
    var isFavorite: Bool
    /// Contador de vezes que o acesso foi aberto.
    var openCount: Int
    /// Data/hora da última abertura.
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
/// Representa um servidor RDP cadastrado, vinculado a um cliente.
/// Inclui opções específicas de RDP como certificado, tela cheia e resolução.
struct RDPServer: Identifiable, Hashable, Sendable {
    let id: String
    var alias: String
    let clientId: String
    var name: String
    var host: String
    /// Porta RDP (padrão: 3389).
    var port: Int
    /// Domínio Windows (opcional).
    var domain: String
    var user: String
    var tags: String
    /// Se true, ignora erros de certificado na conexão RDP.
    var ignoreCert: Bool
    /// Se true, abre a conexão em tela cheia.
    var fullScreen: Bool
    /// Se true, usa resolução dinâmica (smart sizing).
    var dynamicResolution: Bool
    /// Largura fixa da janela RDP (usado quando dynamicResolution == false).
    var width: Int?
    /// Altura fixa da janela RDP (usado quando dynamicResolution == false).
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
/// Representa um acesso URL (HTTP/HTTPS/FTP) cadastrado, vinculado a um cliente.
/// A URL é decomposta em scheme, host, porta e path para persistência.
struct URLAccess: Identifiable, Hashable, Sendable {
    let id: String
    var alias: String
    let clientId: String
    var name: String
    /// Esquema da URL (http, https, ftp, etc.).
    var scheme: String
    var host: String
    /// Porta explícita (padrão conforme esquema: 80, 443, 21).
    var port: Int
    /// Caminho (path) da URL incluindo query e fragment.
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

// MARK: - MTK (MikroTik / WinBox)
/// Representa um acesso WinBox para dispositivos MikroTik.
struct MTKAccess: Identifiable, Hashable, Sendable {
    let id: String
    var alias: String
    let clientId: String
    var name: String
    var host: String
    /// Porta WinBox (padrão: 8291).
    var port: Int
    /// Usuário de login no RouterOS.
    var user: String
    var tags: String
    var notes: String
    var isFavorite: Bool
    var openCount: Int
    var lastOpenedAt: String
    init(id: String? = nil, alias: String, clientId: String, name: String, host: String, port: Int = 8291, user: String, tags: String = "", notes: String = "", isFavorite: Bool = false, openCount: Int = 0, lastOpenedAt: String = "") {
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

// MARK: - Enum Tipos
/// Tipo de conexão usado no LogParser para contagem de acessos por dia.
enum ConnType: String, Codable, CaseIterable, Sendable {
    case ssh = "SSH"
    case rdp = "RDP"
    case url = "URL"
    case mtk = "MTK"
}

/// Tipo de acesso usado no restante do app (CRUD, checagem, UI).
enum AccessKind: String, Codable, CaseIterable, Sendable {
    case ssh = "SSH"
    case rdp = "RDP"
    case url = "URL"
    case mtk = "MTK"
}

// MARK: - Log e Row
/// Ponto de dados para o gráfico de conexões por dia (usado pelo LogParser).
struct ConnLogPoint: Identifiable, Hashable, Sendable {
    let id: UUID = UUID()
    /// Dia ao qual essa contagem se refere.
    let day: Date
    /// Tipo de conexão (SSH, RDP ou URL).
    let type: ConnType
    /// Quantidade de aberturas nesse dia.
    let count: Int
}

/// Representa uma linha unificada de acesso na UI (combina SSH, RDP, URL e MTK numa única struct).
/// Usada para exibição na lista de acessos e para checagem de conectividade.
struct AccessRow: Identifiable, Sendable {
    let id: String
    let clientId: String
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
