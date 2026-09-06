import XCTest
import SwiftUI
@testable import iosApp

final class LocalizationHelperTests: XCTestCase {
    private var originalOverride: String = ""

    override func setUp() {
        super.setUp()
        originalOverride = AppSettings.shared.appLanguageOverride
    }

    override func tearDown() {
        AppSettings.shared.appLanguageOverride = originalOverride
        super.tearDown()
    }

    func testEnglishPresetLookup() {
        AppSettings.shared.appLanguageOverride = AppLanguage.english.rawValue
        XCTAssertEqual(L("preset_need_help"), "I need help")
        XCTAssertEqual(L("Settings"), "Settings")
        XCTAssertFalse(L("language.follow_system.footer").isEmpty)
        XCTAssertNotEqual(L("language.follow_system.footer"), "language.follow_system.footer")
    }

    func testSpanishPresetLookup() {
        AppSettings.shared.appLanguageOverride = AppLanguage.spanish.rawValue
        let help = L("preset_need_help")
        XCTAssertNotEqual(help, "preset_need_help")
        XCTAssertNotEqual(help, "I need help")
        XCTAssertEqual(L("Settings"), "Ajustes")
    }

    func testArabicIsRTL() {
        XCTAssertTrue(AppLanguage.arabic.isRTL)
        XCTAssertEqual(AppLanguage.arabic.layoutDirection, .rightToLeft)
        XCTAssertFalse(AppLanguage.english.isRTL)
    }

    func testSystemLanguageFallback() {
        XCTAssertNotNil(AppLanguage.from(id: "es-MX"))
        XCTAssertEqual(AppLanguage.from(id: "zh-TW"), .chineseTraditional)
        XCTAssertEqual(AppLanguage.from(id: "zh-CN"), .chineseSimplified)
        XCTAssertEqual(AppLanguage.from(id: "vi-VN"), .vietnamese)
        XCTAssertEqual(AppLanguage.from(id: "ja-JP"), .japanese)
        XCTAssertEqual(AppLanguage.from(id: "de-DE"), .german)
        XCTAssertEqual(AppLanguage.from(id: "ar-SA"), .arabic)
    }

    func testFormatStringKeepsValues() {
        AppSettings.shared.appLanguageOverride = AppLanguage.english.rawValue
        XCTAssertEqual(L("Page %d of %d", 2, 5), "Page 2 of 5")
    }

    func testAllLocalesReturnTranslatedPresetAndSettings() {
        for language in AppLanguage.allCases {
            AppSettings.shared.appLanguageOverride = language.rawValue
            let help = L("preset_need_help")
            let settings = L("Settings")
            XCTAssertNotEqual(help, "preset_need_help", "Missing preset translation for \(language.rawValue)")
            XCTAssertNotEqual(settings, "settings.title", "Settings key leaked for \(language.rawValue)")
            XCTAssertFalse(help.isEmpty)
            XCTAssertFalse(settings.isEmpty)
        }
    }

    func testCoreVocabularyUsesLocalization() {
        AppSettings.shared.appLanguageOverride = AppLanguage.english.rawValue
        XCTAssertEqual(CoreVocabulary.categoryName(for: "preset_recents"), "Recently Said")
        XCTAssertEqual(CoreVocabulary.phraseText(for: "preset_need_help", fallback: "x"), "I need help")
    }
}
