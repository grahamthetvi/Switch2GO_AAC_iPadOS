import Foundation
import Combine
import VocableShared

/// Manages the SQLDelight database for iOS
class DatabaseManager: ObservableObject {
    private let database: VocableDatabase
    private let driverFactory: DatabaseDriverFactory
    
    /// Singleton instance
    static let shared = DatabaseManager()
    
    private init() {
        self.driverFactory = DatabaseDriverFactory()
        self.database = DatabaseKt.createDatabase(driverFactory: driverFactory)
        
        // Initialize preset data on first launch
        initializePresetsIfNeeded()
    }
    
    /// Access to the database instance
    var db: VocableDatabase {
        return database
    }
    
    /// Initialize preset categories and phrases if database is empty
    private func initializePresetsIfNeeded() {
        let presetCount = database.presetCategoryQueries.getPresetCategoryCount().executeAsOne()
        
        if presetCount == 0 {
            print("DatabaseManager: First launch detected, initializing preset data...")
            initializePresetData()
        } else {
            print("DatabaseManager: Preset data already exists (\(presetCount) categories)")
        }
    }
    
    /// Populate database with preset categories and phrases
    private func initializePresetData() {
        let presetData = PresetData()
        
        // Insert preset categories
        for category in presetData.categories {
            database.presetCategoryQueries.insertPresetCategory(
                category_id: category.id,
                hidden: 0,
                sort_order: Int64(category.initialSortOrder),
                deleted: 0
            )
            print("DatabaseManager: Inserted preset category: \(category.id)")
        }
        
        // Insert preset phrases
        let allPhrases = presetData.getAllPresetPhrases()
        for phrase in allPhrases {
            // Serialize phrase style to JSON if present
            var styleJson: String? = nil
            if let style = phrase.style {
                styleJson = style.toJSONString()
            }
            
            database.presetPhraseQueries.insertPresetPhrase(
                phrase_id: phrase.phraseId,
                parent_category_id: phrase.parentCategoryId ?? "",
                creation_date: phrase.creationDate,
                last_spoken_date: phrase.lastSpokenDate,
                sort_order: Int64(phrase.sortOrder),
                deleted: 0,
                style: styleJson
            )
        }
        
        print("DatabaseManager: Initialized \(presetData.categories.count) categories and \(allPhrases.count) phrases")
    }
    
    /// Reset database to defaults (clear custom data, keep presets)
    func resetToDefaults() {
        // Clear all custom categories
        let customCategories = database.categoryQueries.getAllCategories().executeAsList()
        for category in customCategories {
            database.categoryQueries.deleteCategory(category_id: category.category_id)
        }
        
        // Clear all custom phrases
        let customPhrases = database.phraseQueries.getAllPhrases().executeAsList()
        for phrase in customPhrases {
            database.phraseQueries.deletePhrase(phrase_id: phrase.phrase_id)
        }
        
        // Reset preset categories to defaults (unhide all)
        let presetCategories = database.presetCategoryQueries.getAllPresetCategories().executeAsList()
        for category in presetCategories {
            database.presetCategoryQueries.updatePresetCategoryHidden(
                hidden: 0,
                category_id: category.category_id
            )
            database.presetCategoryQueries.updatePresetCategoryDeleted(
                deleted: 0,
                category_id: category.category_id
            )
        }
        
        // Clear last spoken dates from preset phrases
        let presetPhrases = database.presetPhraseQueries.getAllPresetPhrases().executeAsList()
        for phrase in presetPhrases {
            database.presetPhraseQueries.updatePresetPhraseLastSpoken(
                last_spoken_date: nil,
                phrase_id: phrase.phrase_id
            )
        }
        
        print("DatabaseManager: Database reset to defaults")
    }
}
