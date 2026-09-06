import Foundation
import SwiftUI

/// Looks up strings in the in-app language, not the process language.
func L(_ key: String, default defaultValue: String? = nil) -> String {
    LocalizationHelper.localized(key, default: defaultValue)
}

func L(_ key: String, _ args: CVarArg...) -> String {
    LocalizationHelper.format(key, arguments: args)
}

/// Localization utilities that honor the in-app language override.
enum LocalizationHelper {
    private static let cacheLock = NSLock()
    private static var cachedLanguageId: String?
    private static var cachedBundle: Bundle = .main

    static var currentLanguage: AppLanguage {
        AppSettings.shared.resolvedLanguage
    }

    static var currentLocale: Locale { currentLanguage.locale }

    static var isRTL: Bool { currentLanguage.isRTL }

    static func invalidateCache() {
        cacheLock.lock()
        cachedLanguageId = nil
        cachedBundle = .main
        cacheLock.unlock()
    }

    /// Bundle for the resolved AAC language (`ar.lproj`, `zh-Hans.lproj`, …).
    static var bundle: Bundle {
        let language = currentLanguage
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if cachedLanguageId == language.id {
            return cachedBundle
        }
        cachedLanguageId = language.id
        cachedBundle = bundle(for: language)
        return cachedBundle
    }

    static func bundle(for language: AppLanguage) -> Bundle {
        let candidates = [language.lprojName] + language.ttsLanguageCodes
        for name in candidates {
            if let path = Bundle.main.path(forResource: name, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return .main
    }

    static func localized(_ key: String, default defaultValue: String? = nil) -> String {
        let fallback = defaultValue ?? key
        let language = currentLanguage

        // Prefer the compiled lproj when the in-app language is not the process language.
        let langBundle = bundle(for: language)
        if langBundle != .main {
            return langBundle.localizedString(forKey: key, value: fallback, table: nil)
        }

        var resource = LocalizedStringResource(
            key,
            defaultValue: String.LocalizationValue(stringLiteral: fallback)
        )
        resource.locale = language.locale
        return String(localized: resource)
    }

    static func format(_ key: String, arguments: [CVarArg]) -> String {
        let template = localized(key)
        return String(format: template, locale: currentLocale, arguments: arguments)
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        format(key, arguments: args)
    }

    static func localizedURL(forResource name: String, withExtension ext: String) -> URL? {
        if let url = bundle.url(forResource: name, withExtension: ext) {
            return url
        }
        return Bundle.main.url(forResource: name, withExtension: ext)
    }
}

extension Text {
    /// Text that always reads from the in-app language bundle.
    init(l10n key: String) {
        self.init(verbatim: L(key))
    }
}
