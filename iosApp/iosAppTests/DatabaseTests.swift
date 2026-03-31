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
}
