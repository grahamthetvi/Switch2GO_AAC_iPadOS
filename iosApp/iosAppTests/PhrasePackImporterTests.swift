import XCTest
@testable import iosApp
import VocableShared

final class PhrasePackArchiveTests: XCTestCase {
    func testRoundTripManifest() throws {
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("s2g-stage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        let manifest = PhrasePackManifest(
            formatVersion: 1,
            packId: "pack-1",
            displayName: "Lesson",
            createdAt: 1,
            source: "ios",
            category: PhrasePackCategory(id: "pack_category_1", name: "Lesson", colorHex: 0xFF00ACC1, symbolName: "folder.fill"),
            phrases: [
                PhrasePackPhrase(id: "pack_phrase_01", text: "Hello", sortOrder: 0, style: nil)
            ]
        )
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: staging.appendingPathComponent("manifest.json"))

        let packURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).switch2go")
        try PhrasePackArchive.create(fromStagingDirectory: staging, to: packURL)
        defer { try? FileManager.default.removeItem(at: packURL) }

        let extract = FileManager.default.temporaryDirectory.appendingPathComponent("s2g-out-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: extract) }
        try PhrasePackArchive.extract(packURL: packURL, to: extract)
        let loaded = try PhrasePackArchive.loadManifest(fromExtractRoot: extract)
        XCTAssertEqual(loaded.displayName, "Lesson")
        XCTAssertEqual(loaded.phrases.first?.text, "Hello")
    }

    func testManifestVersionCheck() throws {
        let extract = FileManager.default.temporaryDirectory.appendingPathComponent("s2g-version-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extract, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: extract) }

        // Future version should throw unsupportedVersion
        let futureManifest = PhrasePackManifest(
            formatVersion: 99,
            packId: "pack-future",
            displayName: "Future",
            createdAt: 1,
            source: "future",
            category: PhrasePackCategory(id: "c1", name: "Future", colorHex: nil, symbolName: nil),
            phrases: []
        )
        let futureData = try JSONEncoder().encode(futureManifest)
        try futureData.write(to: extract.appendingPathComponent("manifest.json"))

        XCTAssertThrowsError(try PhrasePackArchive.loadManifest(fromExtractRoot: extract)) { error in
            guard case PhrasePackError.unsupportedVersion(let version) = error as! PhrasePackError else {
                XCTFail("Expected unsupportedVersion, got \(error)")
                return
            }
            XCTAssertEqual(version, 99)
        }
    }

    func testCorruptZipFailsWithoutExtractRootLeftovers() {
        let packURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).switch2go")
        try? Data("not a zip".utf8).write(to: packURL)
        defer { try? FileManager.default.removeItem(at: packURL) }

        let extract = FileManager.default.temporaryDirectory.appendingPathComponent("s2g-corrupt-\(UUID().uuidString)")
        XCTAssertThrowsError(try PhrasePackArchive.extract(packURL: packURL, to: extract))
        let leftover = try? FileManager.default.contentsOfDirectory(atPath: extract.path)
        XCTAssertTrue(leftover == nil || leftover?.isEmpty == true || leftover == ["."])
    }

    func testZipSlipRejected() throws {
        XCTAssertThrowsError(try PhrasePackPath.validatedRelativePath("../evil.txt")) { error in
            guard case PhrasePackError.zipSlip = error as? PhrasePackError else {
                return XCTFail("expected zipSlip, got \(error)")
            }
        }
    }
}

final class PhrasePackImporterTests: XCTestCase {
    private var createdCategoryIds: [String] = []
    private var createdPhraseIds: [String] = []

    override func tearDown() {
        let db = DatabaseManager.shared.db
        for phraseId in createdPhraseIds {
            databaseDeletePhrase(db, phraseId)
        }
        for categoryId in createdCategoryIds {
            db.categoryQueries.deleteCategory(category_id: categoryId)
        }
        createdCategoryIds.removeAll()
        createdPhraseIds.removeAll()
        super.tearDown()
    }

    func testImportCreatesCustomIdsAndLeavesPresetsAlone() throws {
        let db = DatabaseManager.shared.db
        let presetCatsBefore = db.presetCategoryQueries.getAllPresetCategories().executeAsList().map { $0.category_id }
        let presetPhrasesBefore = db.presetPhraseQueries.getAllPresetPhrases().executeAsList().map { $0.phrase_id }

        let packURL = try writePack(
            categoryName: "Importer Test \(UUID().uuidString.prefix(8))",
            phrases: [
                PhrasePackPhrase(
                    id: "pack_phrase_01",
                    text: "Hello from pack",
                    sortOrder: 0,
                    style: PhrasePackStyle(
                        backgroundColor: 0xFFE53935,
                        textColor: 0xFFFFFFFF,
                        textSizeSp: nil,
                        isBold: true,
                        borderColor: nil,
                        borderWidthDp: nil,
                        image: nil,
                        media: nil,
                        mediaType: nil,
                        thumb: nil,
                        gameType: nil
                    )
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: packURL) }

        let result = try PhrasePackImporter.importPack(
            fileURL: packURL,
            destination: .createNew(name: "Importer Test \(UUID().uuidString.prefix(8))")
        )
        createdCategoryIds.append(result.categoryId)

        XCTAssertTrue(result.categoryId.hasPrefix("custom_"))
        XCTAssertFalse(result.categoryId.hasPrefix("preset_"))
        let phrases = db.phraseQueries.getPhrasesForCategory(parent_category_id: result.categoryId).executeAsList()
        createdPhraseIds.append(contentsOf: phrases.map { $0.phrase_id })
        XCTAssertEqual(phrases.count, 1)
        XCTAssertTrue(phrases[0].phrase_id.hasPrefix("custom_"))
        XCTAssertEqual(phrases[0].localized_utterance, "Hello from pack")
        XCTAssertFalse(phrases[0].phrase_id.contains("pack_phrase"))

        let presetCatsAfter = db.presetCategoryQueries.getAllPresetCategories().executeAsList().map { $0.category_id }
        let presetPhrasesAfter = db.presetPhraseQueries.getAllPresetPhrases().executeAsList().map { $0.phrase_id }
        XCTAssertEqual(presetCatsBefore, presetCatsAfter)
        XCTAssertEqual(presetPhrasesBefore, presetPhrasesAfter)
    }

    func testMergeAppendsDuplicateText() throws {
        let db = DatabaseManager.shared.db
        let categoryId = "custom_\(UUID().uuidString)"
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        db.categoryQueries.insertCategory(
            category_id: categoryId,
            creation_date: timestamp,
            localized_name: "Water Board \(UUID().uuidString.prefix(6))",
            hidden: 0,
            sort_order: -timestamp,
            color_hex: nil,
            symbol_name: "folder.fill"
        )
        createdCategoryIds.append(categoryId)
        let existingPhraseId = "custom_\(UUID().uuidString)"
        db.phraseQueries.insertPhrase(
            phrase_id: existingPhraseId,
            parent_category_id: categoryId,
            creation_date: timestamp,
            last_spoken_date: nil,
            localized_utterance: "Water",
            sort_order: 0,
            style: nil
        )
        createdPhraseIds.append(existingPhraseId)

        let packURL = try writePack(
            categoryName: "Incoming Water",
            phrases: [
                PhrasePackPhrase(id: "pack_phrase_01", text: "Water", sortOrder: 0, style: nil)
            ]
        )
        defer { try? FileManager.default.removeItem(at: packURL) }

        let result = try PhrasePackImporter.importPack(
            fileURL: packURL,
            destination: .merge(categoryId: categoryId)
        )
        XCTAssertEqual(result.categoryId, categoryId)
        let phrases = db.phraseQueries.getPhrasesForCategory(parent_category_id: categoryId).executeAsList()
        createdPhraseIds.append(contentsOf: phrases.map { $0.phrase_id }.filter { $0 != existingPhraseId })
        let water = phrases.filter { $0.localized_utterance == "Water" }
        XCTAssertEqual(water.count, 2)
        XCTAssertEqual(phrases.map { Int($0.sort_order) }.sorted(), [0, 1])
    }

    func testUnknownGameTypeStillInsertsPhrase() throws {
        let name = "Game Pack \(UUID().uuidString.prefix(8))"
        let packURL = try writePack(
            categoryName: name,
            phrases: [
                PhrasePackPhrase(
                    id: "pack_phrase_01",
                    text: "Play",
                    sortOrder: 0,
                    style: PhrasePackStyle(
                        backgroundColor: nil,
                        textColor: nil,
                        textSizeSp: nil,
                        isBold: false,
                        borderColor: nil,
                        borderWidthDp: nil,
                        image: nil,
                        media: nil,
                        mediaType: nil,
                        thumb: nil,
                        gameType: "future_game"
                    )
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: packURL) }

        let result = try PhrasePackImporter.importPack(
            fileURL: packURL,
            destination: .createNew(name: name)
        )
        createdCategoryIds.append(result.categoryId)
        XCTAssertTrue(result.droppedInteractive)
        let phrases = DatabaseManager.shared.db.phraseQueries
            .getPhrasesForCategory(parent_category_id: result.categoryId)
            .executeAsList()
        createdPhraseIds.append(contentsOf: phrases.map { $0.phrase_id })
        XCTAssertEqual(phrases.count, 1)
        let style = PhraseStyle.fromJSONString(phrases[0].style)
        XCTAssertNil(style?.gameType)
        XCTAssertEqual(phrases[0].localized_utterance, "Play")
    }

    func testMissingAssetFailsWithoutLeavingCategory() throws {
        let name = "Broken Pack \(UUID().uuidString.prefix(8))"
        let packURL = try writePack(
            categoryName: name,
            phrases: [
                PhrasePackPhrase(
                    id: "pack_phrase_01",
                    text: "Photo",
                    sortOrder: 0,
                    style: PhrasePackStyle(
                        backgroundColor: nil,
                        textColor: nil,
                        textSizeSp: nil,
                        isBold: false,
                        borderColor: nil,
                        borderWidthDp: nil,
                        image: "assets/images/missing.jpg",
                        media: nil,
                        mediaType: nil,
                        thumb: nil,
                        gameType: nil
                    )
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: packURL) }

        XCTAssertThrowsError(try PhrasePackImporter.importPack(
            fileURL: packURL,
            destination: .createNew(name: name)
        ))
        let cats = DatabaseManager.shared.db.categoryQueries.getAllCategories().executeAsList()
        XCTAssertFalse(cats.contains { $0.localized_name == name })
    }

    func testCannotMergeIntoPreset() throws {
        let packURL = try writePack(
            categoryName: "Food Clone",
            phrases: [PhrasePackPhrase(id: "pack_phrase_01", text: "Water", sortOrder: 0, style: nil)]
        )
        defer { try? FileManager.default.removeItem(at: packURL) }
        XCTAssertThrowsError(try PhrasePackImporter.importPack(
            fileURL: packURL,
            destination: .merge(categoryId: "preset_food_drink")
        )) { error in
            XCTAssertEqual(error as? PhrasePackError, .protectedCategory)
        }
        let collision = PhrasePackImporter.collision(for: "Food & Drinks")
        if case .preset(let name) = collision {
            XCTAssertEqual(name, "Food & Drinks")
        } else {
            XCTFail("expected preset collision")
        }
    }

    func testCannotCreateCategoryNamedLikePreset() throws {
        let packURL = try writePack(
            categoryName: "Food & Drinks",
            phrases: [PhrasePackPhrase(id: "pack_phrase_01", text: "Water", sortOrder: 0, style: nil)]
        )
        defer { try? FileManager.default.removeItem(at: packURL) }
        XCTAssertThrowsError(try PhrasePackImporter.importPack(
            fileURL: packURL,
            destination: .createNew(name: "Food & Drinks")
        )) { error in
            XCTAssertEqual(error as? PhrasePackError, .protectedCategory)
        }
    }

    private func writePack(categoryName: String, phrases: [PhrasePackPhrase]) throws -> URL {
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("s2g-write-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        let manifest = PhrasePackManifest(
            formatVersion: 1,
            packId: UUID().uuidString,
            displayName: categoryName,
            createdAt: 1,
            source: "ios",
            category: PhrasePackCategory(id: "pack_category_1", name: categoryName, colorHex: nil, symbolName: "folder.fill"),
            phrases: phrases
        )
        try JSONEncoder().encode(manifest).write(to: staging.appendingPathComponent("manifest.json"))
        let packURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).switch2go")
        try PhrasePackArchive.create(fromStagingDirectory: staging, to: packURL)
        return packURL
    }

    private func databaseDeletePhrase(_ db: VocableDatabase, _ phraseId: String) {
        db.phraseQueries.deletePhrase(phrase_id: phraseId)
    }
}
