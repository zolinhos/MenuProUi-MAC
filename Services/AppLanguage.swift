import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case pt
    case en

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pt: return "Português"
        case .en: return "English"
        }
    }

    static func from(_ raw: String) -> AppLanguage {
        AppLanguage(rawValue: raw) ?? .pt
    }
}

enum I18n {
    static func text(_ pt: String, _ en: String, language: AppLanguage) -> String {
        language == .en ? en : pt
    }
}
