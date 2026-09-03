import XCTest
@testable import iosApp
import VocableShared

/// Unit tests for database operations
class DatabaseTests: XCTestCase {
    
    var database: VocableDatabase!
    
    override func setUp() {
        super.setUp()
        // Use in-memory database for testing
        database = DatabaseManager.shared.db
    }
    
    override func tearDown() {
        database = nil
        super.tearDown()
    }
    
    func testPresetCategoriesExist() {
        do {
            let categories = try database.presetCategoryQueries.getAllPresetCategories().executeAsList()
            XCTAssertGreaterThan(categories.count, 0, "Should have preset categories")
            
            // Check for specific preset categories
            let categoryIds = categories.map { $0.category_id }
            XCTAssertTrue(categoryIds.contains("preset_routine_activity"))
            XCTAssertTrue(categoryIds.contains("preset_food_drink"))
        } catch {
            XCTFail("Failed to load preset categories: \(error)")
        }
    }
    
    func testPresetPhrasesExist() {
        do {
            let phrases = try database.presetPhraseQueries.getAllPresetPhrases().executeAsList()
            XCTAssertGreaterThan(phrases.count, 0, "Should have preset phrases")
            
            // Should have 70+ preset phrases
            XCTAssertGreaterThanOrEqual(phrases.count, 60, "Should have at least 60 preset phrases")
        } catch {
            XCTFail("Failed to load preset phrases: \(error)")
        }
    }
    
    func testInsertCustomCategory() {
        let categoryId = "test_category_\(UUID().uuidString)"
        
        do {
            try database.categoryQueries.insertCategory(
                category_id: categoryId,
                creation_date: 12345,
                localized_name: "Test Category",
                hidden: false,
                sort_order: 999,
                color_hex: nil,
                symbol_name: nil
            )
            
            let category = try database.categoryQueries.getCategoryById(category_id: categoryId).executeAsOneOrNull()
            XCTAssertNotNil(category, "Category should be inserted")
            XCTAssertEqual(category?.localized_name, "Test Category")
            
            // Cleanup
            try database.categoryQueries.deleteCategory(category_id: categoryId)
        } catch {
            XCTFail("Failed to insert custom category: \(error)")
        }
    }
    
    func testInsertCustomPhrase() {
        let phraseId = "test_phrase_\(UUID().uuidString)"
        
        do {
            try database.phraseQueries.insertPhrase(
                phrase_id: phraseId,
                parent_category_id: "preset_routine_activity",
                creation_date: 12345,
                last_spoken_date: nil,
                localized_utterance: "Test Phrase",
                sort_order: 999,
                style: nil
            )
            
            let phrase = try database.phraseQueries.getPhraseById(phrase_id: phraseId).executeAsOneOrNull()
            XCTAssertNotNil(phrase, "Phrase should be inserted")
            XCTAssertEqual(phrase?.localized_utterance, "Test Phrase")
            
            // Cleanup
            try database.phraseQueries.deletePhrase(phrase_id: phraseId)
        } catch {
            XCTFail("Failed to insert custom phrase: \(error)")
        }
    }
    
    func testUpdatePhraseStyle() {
        let phraseId = "preset_please" // Use existing preset phrase
        let styleJson = "{\"backgroundColor\":4293456181,\"textColor\":4294967295}"
        
        do {
            try database.presetPhraseQueries.updatePresetPhraseStyle(
                style: styleJson,
                phrase_id: phraseId
            )
            
            let phrase = try database.presetPhraseQueries.getPresetPhraseById(phrase_id: phraseId).executeAsOneOrNull()
            XCTAssertEqual(phrase?.style, styleJson)
            
            // Cleanup
            try database.presetPhraseQueries.updatePresetPhraseStyle(
                style: nil,
                phrase_id: phraseId
            )
        } catch {
            XCTFail("Failed to update phrase style: \(error)")
        }
    }
    
    func testRecentPhrases() {
        let phraseId = "preset_hello"
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        
        do {
            // Mark phrase as spoken
            try database.presetPhraseQueries.updatePresetPhraseLastSpoken(
                last_spoken_date: timestamp,
                phrase_id: phraseId
            )
            
            // Query recent phrases
            let recentPhrases = try database.presetPhraseQueries
                .getAllPresetPhrases()
                .executeAsList()
                .filter { $0.last_spoken_date != nil }
            
            XCTAssertGreaterThan(recentPhrases.count, 0, "Should have recent phrases")
            
            // Cleanup
            try database.presetPhraseQueries.updatePresetPhraseLastSpoken(
                last_spoken_date: nil,
                phrase_id: phraseId
            )
        } catch {
            XCTFail("Failed to test recent phrases: \(error)")
        }
    }

    func testCustomPhraseLastSpokenUpdate() {
        let phraseId = "test_custom_phrase_\(UUID().uuidString)"
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        do {
            try database.phraseQueries.insertPhrase(
                phrase_id: phraseId,
                parent_category_id: "preset_routine_activity",
                creation_date: 12345,
                last_spoken_date: nil,
                localized_utterance: "Custom Recents Test",
                sort_order: 999,
                style: nil
            )

            // Update spoken date
            try database.phraseQueries.updatePhraseLastSpoken(
                last_spoken_date: timestamp,
                phrase_id: phraseId
            )

            let retrieved = try database.phraseQueries.getPhraseById(phrase_id: phraseId).executeAsOneOrNull()
            XCTAssertNotNil(retrieved)
            XCTAssertEqual(retrieved?.last_spoken_date?.int64Value, timestamp)

            // Cleanup
            try database.phraseQueries.deletePhrase(phrase_id: phraseId)
        } catch {
            XCTFail("Failed custom phrase last spoken test: \(error)")
        }
    }

    func testMergedRecentsQueries() {
        let customPhraseId = "test_recent_custom_\(UUID().uuidString)"
        let presetPhraseId = "preset_yes"
        let olderTimestamp = Int64(10000)
        let newerTimestamp = Int64(20000)

        do {
            try database.phraseQueries.insertPhrase(
                phrase_id: customPhraseId,
                parent_category_id: "preset_routine_activity",
                creation_date: 12345,
                last_spoken_date: newerTimestamp,
                localized_utterance: "Custom Most Recent",
                sort_order: 1,
                style: nil
            )

            try database.presetPhraseQueries.updatePresetPhraseLastSpoken(
                last_spoken_date: olderTimestamp,
                phrase_id: presetPhraseId
            )

            // Query both
            let spokenPresets = try database.presetPhraseQueries.getAllPresetPhrases().executeAsList()
                .filter { $0.last_spoken_date != nil && $0.deleted == 0 }
            let spokenCustoms = try database.phraseQueries.getAllPhrases().executeAsList()
                .filter { $0.last_spoken_date != nil }

            var merged: [(id: String, lastSpoken: Int64)] = []
            for p in spokenPresets {
                if let s = p.last_spoken_date?.int64Value {
                    merged.append((id: p.phrase_id, lastSpoken: s))
                }
            }
            for c in spokenCustoms {
                if let s = c.last_spoken_date?.int64Value {
                    merged.append((id: c.phrase_id, lastSpoken: s))
                }
            }

            merged.sort { $0.lastSpoken > $1.lastSpoken }

            // Custom phrase with newer timestamp should appear before preset with older timestamp
            let customIndex = merged.firstIndex { $0.id == customPhraseId }
            let presetIndex = merged.firstIndex { $0.id == presetPhraseId }
            XCTAssertNotNil(customIndex)
            XCTAssertNotNil(presetIndex)
            XCTAssertTrue(customIndex! < presetIndex!)

            // Cleanup
            try database.phraseQueries.deletePhrase(phrase_id: customPhraseId)
            try database.presetPhraseQueries.updatePresetPhraseLastSpoken(
                last_spoken_date: nil,
                phrase_id: presetPhraseId
            )
        } catch {
            XCTFail("Failed merged recents test: \(error)")
        }
    }
}
