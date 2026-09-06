import Foundation
import SwiftUI

/// Supported in-app AAC languages. Empty override means follow the iPad language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case arabic = "ar"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case japanese = "ja"
    case vietnamese = "vi"

    var id: String { rawValue }

    /// Folder name for `.lproj` lookups.
    var lprojName: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    var isRTL: Bool { self == .arabic }

    var layoutDirection: LayoutDirection { isRTL ? .rightToLeft : .leftToRight }

    /// Language name written in that language (for the picker).
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .arabic: return "العربية"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .japanese: return "日本語"
        case .vietnamese: return "Tiếng Việt"
        }
    }

    /// BCP-47 codes to try when picking an `AVSpeechSynthesisVoice`.
    var ttsLanguageCodes: [String] {
        switch self {
        case .english: return ["en-US", "en-GB", "en-AU", "en"]
        case .spanish: return ["es-MX", "es-ES", "es-US", "es"]
        case .french: return ["fr-FR", "fr-CA", "fr"]
        case .german: return ["de-DE", "de-AT", "de"]
        case .arabic: return ["ar-SA", "ar-AE", "ar"]
        case .chineseSimplified: return ["zh-CN", "zh-Hans", "zh"]
        case .chineseTraditional: return ["zh-TW", "zh-HK", "zh-Hant"]
        case .japanese: return ["ja-JP", "ja"]
        case .vietnamese: return ["vi-VN", "vi"]
        }
    }

    static func from(id: String?) -> AppLanguage? {
        guard let id, !id.isEmpty else { return nil }
        if let match = AppLanguage(rawValue: id) { return match }
        let lowered = id.lowercased()
        if lowered.hasPrefix("zh-hant") || lowered.hasPrefix("zh-tw") || lowered.hasPrefix("zh-hk") {
            return .chineseTraditional
        }
        if lowered.hasPrefix("zh") { return .chineseSimplified }
        if let prefix = lowered.split(separator: "-").first,
           let match = AppLanguage(rawValue: String(prefix)) {
            return match
        }
        if let prefix = lowered.split(separator: "_").first,
           let match = AppLanguage(rawValue: String(prefix)) {
            return match
        }
        return nil
    }

    /// Best matching supported language for the current iPad preferred languages.
    static func fromSystem() -> AppLanguage {
        for preferred in Locale.preferredLanguages {
            if let match = from(id: preferred) { return match }
        }
        if let code = Locale.current.language.languageCode?.identifier,
           let match = from(id: code) {
            return match
        }
        return .english
    }
}

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}
