import XCTest
@testable import iosApp

final class PhrasePackExporterTests: XCTestCase {
    func testRecentsCannotExport() {
        let recents = CategoryDisplayModel(
            id: "preset_recents",
            name: "Recently Said",
            sortOrder: 0,
            isPreset: true,
            hidden: false,
            colorHex: nil,
            symbolName: nil
        )
        XCTAssertThrowsError(try PhrasePackExporter.exportCategory(category: recents)) { error in
            XCTAssertEqual(error as? PhrasePackError, .recentsCannotExport)
        }
    }
}
