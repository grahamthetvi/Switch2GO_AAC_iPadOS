import Foundation

/// Localization utilities
struct LocalizationHelper {
    /// Get localized string with key
    static func localized(_ key: String, comment: String = "") -> String {
        return NSLocalizedString(key, comment: comment)
    }
    
    /// Get current locale
    static var currentLocale: Locale {
        return Locale.current
    }
    
    /// Get current language code
    static var currentLanguageCode: String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    /// Check if RTL language
    static var isRTL: Bool {
        return Locale.current.language.characterDirection == .rightToLeft
    }
    
    /// Get phrase text by key
    static func phraseText(for key: String) -> String {
        return localized(key)
    }
}
