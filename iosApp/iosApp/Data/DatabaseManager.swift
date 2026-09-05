import Foundation
import Combine
import VocableShared

/// Manages the SQLDelight database for iOS
class DatabaseManager: ObservableObject {
    private let database: VocableDatabase
    private let driverFactory: DatabaseDriverFactory

    /// Bumps when preset category set changes (e.g. away from legacy `preset_general`).
    static let presetSchemaVersionKey = "presetSchemaVersion"
    static let currentPresetSchemaVersion = 2

    /// Singleton instance
    static let shared = DatabaseManager()

    /// Exposed for tests; defaults to standard UserDefaults.
    var defaults: UserDefaults = .standard

    private init() {
        self.driverFactory = DatabaseDriverFactory()
        self.database = DatabaseKt.createDatabase(driverFactory: driverFactory)

        // Initialize preset data on first launch
        initializePresetsIfNeeded()
        migrateAbsoluteMediaRefsIfNeeded()
    }

    /// Access to the database instance
    var db: VocableDatabase {
        return database
    }

    /// Current persisted schema version for presets.
    var presetSchemaVersion: Int {
        get { defaults.integer(forKey: Self.presetSchemaVersionKey) }
        set { defaults.set(newValue, forKey: Self.presetSchemaVersionKey) }
    }

    /// Initialize preset categories and phrases if database is empty or needs a one-shot migration.
    func initializePresetsIfNeeded() {
        let schemaVersion = presetSchemaVersion
        let presetCount = database.presetCategoryQueries.getPresetCategoryCount().executeAsOne()

        // Already on current schema: never wipe/re-seed (even if soft-deleted legacy rows remain).
        if schemaVersion >= Self.currentPresetSchemaVersion {
            if presetCount == 0 {
                DebugLog.info("Schema current but empty; seeding presets...", tag: "DatabaseManager")
                initializePresetData()
            } else {
                DebugLog.info("Preset data already exists (\(presetCount) categories)", tag: "DatabaseManager")
            }
            return
        }

        // Legacy: soft-deleted or live `preset_general` means an old category set.
        let hasLegacyGeneral =
            database.presetCategoryQueries.getPresetCategoryById(category_id: "preset_general").executeAsOneOrNull() != nil

        if hasLegacyGeneral {
            DebugLog.info("Old preset data detected, clearing and re-initializing once...", tag: "DatabaseManager")
            softDeleteAllPresets()
            initializePresetData()
        } else if presetCount == 0 {
            DebugLog.info("First launch detected, initializing preset data...", tag: "DatabaseManager")
            initializePresetData()
        } else {
            DebugLog.info("Marking existing presets as schema v\(Self.currentPresetSchemaVersion)", tag: "DatabaseManager")
        }

        presetSchemaVersion = Self.currentPresetSchemaVersion
    }

    private func softDeleteAllPresets() {
        let oldCategories = database.presetCategoryQueries.getAllPresetCategories().executeAsList()
        for cat in oldCategories {
            database.presetCategoryQueries.updatePresetCategoryDeleted(deleted: 1, category_id: cat.category_id)
        }
        let oldPhrases = database.presetPhraseQueries.getAllPresetPhrases().executeAsList()
        for phrase in oldPhrases {
            database.presetPhraseQueries.updatePresetPhraseDeleted(deleted: 1, phrase_id: phrase.phrase_id)
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

    /// Rewrites absolute / file:// image and media refs in phrase styles to relative Documents paths.
    func migrateAbsoluteMediaRefsIfNeeded() {
        var updated = 0

        let presetPhrases = database.presetPhraseQueries.getAllPresetPhrases().executeAsList()
        for phrase in presetPhrases {
            guard let styleJson = phrase.style,
                  let style = PhraseStyle.fromJSONString(styleJson) else { continue }
            let newImage = MediaStorage.relativizeIfNeeded(style.imageRef)
            let newMedia = MediaStorage.relativizeIfNeeded(style.mediaRef)
            if newImage != style.imageRef || newMedia != style.mediaRef {
                let updatedStyle = PhraseStyle(
                    backgroundColor: style.backgroundColor,
                    textColor: style.textColor,
                    textSizeSp: style.textSizeSp,
                    isBold: style.isBold,
                    borderColor: style.borderColor,
                    borderWidthDp: style.borderWidthDp,
                    imageRef: newImage,
                    mediaRef: newMedia,
                    mediaType: style.mediaType,
                    gameType: style.gameType
                )
                updatedStyle.sendSwitchOutput = style.sendSwitchOutput
                if let json = updatedStyle.toJSONString() {
                    database.presetPhraseQueries.updatePresetPhraseStyle(style: json, phrase_id: phrase.phrase_id)
                    updated += 1
                }
            }
        }

        let customPhrases = database.phraseQueries.getAllPhrases().executeAsList()
        for phrase in customPhrases {
            guard let styleJson = phrase.style,
                  let style = PhraseStyle.fromJSONString(styleJson) else { continue }
            let newImage = MediaStorage.relativizeIfNeeded(style.imageRef)
            let newMedia = MediaStorage.relativizeIfNeeded(style.mediaRef)
            if newImage != style.imageRef || newMedia != style.mediaRef {
                let updatedStyle = PhraseStyle(
                    backgroundColor: style.backgroundColor,
                    textColor: style.textColor,
                    textSizeSp: style.textSizeSp,
                    isBold: style.isBold,
                    borderColor: style.borderColor,
                    borderWidthDp: style.borderWidthDp,
                    imageRef: newImage,
                    mediaRef: newMedia,
                    mediaType: style.mediaType,
                    gameType: style.gameType
                )
                updatedStyle.sendSwitchOutput = style.sendSwitchOutput
                if let json = updatedStyle.toJSONString() {
                    database.phraseQueries.updatePhraseStyle(style: json, phrase_id: phrase.phrase_id)
                    updated += 1
                }
            }
        }

        if updated > 0 {
            DebugLog.info("Relativized media refs on \(updated) phrases", tag: "DatabaseManager")
        }
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

        // Reset preset categories to defaults (unhide all non-legacy)
        let presetCategories = database.presetCategoryQueries.getAllPresetCategories().executeAsList()
        for category in presetCategories {
            // Keep legacy soft-deleted rows deleted so they never resurface.
            if category.category_id == "preset_general" {
                database.presetCategoryQueries.updatePresetCategoryDeleted(
                    deleted: 1,
                    category_id: category.category_id
                )
                continue
            }
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

        MediaStorage.deleteAllStoredMedia()
        ImageCache.shared.clear()

        presetSchemaVersion = Self.currentPresetSchemaVersion

        DebugLog.info("Database reset to defaults", tag: "DatabaseManager")
    }

    /// Runs work in a SQLite transaction. Throws and rolls back if [work] throws.
    func transaction(_ work: @escaping () throws -> Void) throws {
        var captured: Error?
        DatabaseKt.runInTransaction(database) {
            do {
                try work()
                return 1
            } catch {
                captured = error
                return 0
            }
        }
        if let captured {
            throw captured
        }
    }
}
