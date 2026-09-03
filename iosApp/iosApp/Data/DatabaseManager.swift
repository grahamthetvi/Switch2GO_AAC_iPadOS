import Foundation
import Combine
import VocableShared

/// Manages the SQLDelight database for iOS
class DatabaseManager: ObservableObject {
    private let database: VocableDatabase
    private let driverFactory: DatabaseDriverFactory
    private let writeQueue = DispatchQueue(label: "com.switch2go.database.write", qos: .userInitiated)
    private static let writeQueueKey = DispatchSpecificKey<UInt8>()
    private let writeQueueContext: UInt8 = 1

    /// Singleton instance
    static let shared = DatabaseManager()
    
    private init() {
        self.driverFactory = DatabaseDriverFactory()
        self.database = DatabaseKt.createDatabase(driverFactory: driverFactory)
        writeQueue.setSpecific(key: Self.writeQueueKey, value: writeQueueContext)
        
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
        
        // Check if we have the old categories. If so, we need to migrate to the new ones.
        let hasOldCategories = database.presetCategoryQueries.getPresetCategoryById(category_id: "preset_general").executeAsOneOrNull() != nil
        
        if presetCount == 0 || hasOldCategories {
            if hasOldCategories {
                DebugLog.info("Old preset data detected, clearing and re-initializing...", tag: "DatabaseManager")
                // Clear old presets
                let oldCategories = database.presetCategoryQueries.getAllPresetCategories().executeAsList()
                for cat in oldCategories {
                    database.presetCategoryQueries.updatePresetCategoryDeleted(deleted: 1, category_id: cat.category_id)
                }
                let oldPhrases = database.presetPhraseQueries.getAllPresetPhrases().executeAsList()
                for phrase in oldPhrases {
                    database.presetPhraseQueries.updatePresetPhraseDeleted(deleted: 1, phrase_id: phrase.phrase_id)
                }
            } else {
                DebugLog.info("First launch detected, initializing preset data...", tag: "DatabaseManager")
            }
            initializePresetData()
        } else {
            DebugLog.info("Preset data already exists (\(presetCount) categories)", tag: "DatabaseManager")
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
                deleted: 0,
                color_hex: nil,
                symbol_name: nil
            )
            DebugLog.debug("Inserted preset category: \(category.id)", tag: "DatabaseManager")
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
        
        DebugLog.info("Initialized \(presetData.categories.count) categories and \(allPhrases.count) phrases", tag: "DatabaseManager")
    }
    
    /// Perform database write operations asynchronously on the dedicated serial write queue.
    func asyncWrite(_ block: @escaping () -> Void) {
        writeQueue.async {
            block()
        }
    }

    /// Perform database write operations synchronously on the dedicated serial write queue.
    func syncWrite<T>(_ block: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: Self.writeQueueKey) != nil {
            return try block()
        }
        return try writeQueue.sync {
            try block()
        }
    }

    /// Reset database to defaults (clear custom data, keep presets)
    func resetToDefaults() {
        syncWrite {
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
            
            DebugLog.info("Database reset to defaults", tag: "DatabaseManager")
        }
    }

    /// Runs work in a SQLite transaction on the serial write queue. Throws and rolls back if [work] throws.
    func transaction(_ work: () throws -> Void) throws {
        try syncWrite {
            var captured: Error?
            do {
                DatabaseKt.runInTransaction(database) {
                    do {
                        try work()
                        return KotlinInt(value: 1)
                    } catch {
                        captured = error
                        return KotlinInt(value: 0)
                    }
                }
            } catch {
                throw captured ?? error
            }
            if let captured {
                throw captured
            }
        }
    }
}
