import Foundation
import VocableShared

/// iOS backup/restore (format aligned with web `BACKUP_FORMAT_VERSION = 1`).
enum DataBackupManager {
    static let formatVersion = 1

    struct BackupImageEntry: Codable {
        let id: String
        let created_at: Int64
        let mime: String
        let data: String
    }

    struct BackupMediaEntry: Codable {
        let id: String
        let created_at: Int64
        let mime: String
        let data: String
    }

    struct PresetCategoryRow: Codable {
        let category_id: String
        let hidden: Int64
        let sort_order: Int64
        let deleted: Int64
        let color_hex: Int64?
        let symbol_name: String?
    }

    struct PresetPhraseRow: Codable {
        let phrase_id: String
        let parent_category_id: String
        let creation_date: Int64
        let last_spoken_date: Int64?
        let sort_order: Int64
        let deleted: Int64
        let style: String?
    }

    struct CategoryRow: Codable {
        let category_id: String
        let creation_date: Int64
        let localized_name: String
        let hidden: Bool
        let sort_order: Int64
        let color_hex: Int64?
        let symbol_name: String?
    }

    struct PhraseRow: Codable {
        let phrase_id: String
        let parent_category_id: String?
        let creation_date: Int64
        let last_spoken_date: Int64?
        let localized_utterance: String?
        let sort_order: Int64
        let style: String?
    }

    struct BackupPayload: Codable {
        let version: Int
        let exportedAt: String
        let platform: String
        let settings: [String: AnyCodableValue]?
        let presetCategory: [PresetCategoryRow]
        let presetPhrase: [PresetPhraseRow]
        let category: [CategoryRow]
        let phrase: [PhraseRow]
        let images: [BackupImageEntry]
        let media: [BackupMediaEntry]
    }

    enum BackupError: LocalizedError {
        case invalidJSON
        case unsupportedVersion
        case encodeFailed
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .invalidJSON: return "Invalid backup file: not valid JSON"
            case .unsupportedVersion: return "Invalid backup file: unsupported format or version"
            case .encodeFailed: return "Could not create backup file"
            case .writeFailed: return "Could not write backup file"
            }
        }
    }

    static func backupFilename() -> String {
        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        return "switch2go-backup-\(stamp).json"
    }

    static func buildPayload(
        database: VocableDatabase = DatabaseManager.shared.db,
        settings: AppSettings = .shared
    ) throws -> BackupPayload {
        let presetCategories = database.presetCategoryQueries.getAllPresetCategories().executeAsList().map {
            PresetCategoryRow(
                category_id: $0.category_id,
                hidden: $0.hidden,
                sort_order: $0.sort_order,
                deleted: $0.deleted,
                color_hex: $0.color_hex.map { Int64(truncating: $0) },
                symbol_name: $0.symbol_name
            )
        }
        let presetPhrases = database.presetPhraseQueries.getAllPresetPhrases().executeAsList().map {
            PresetPhraseRow(
                phrase_id: $0.phrase_id,
                parent_category_id: $0.parent_category_id,
                creation_date: $0.creation_date,
                last_spoken_date: $0.last_spoken_date.map { Int64(truncating: $0) },
                sort_order: $0.sort_order,
                deleted: $0.deleted,
                style: $0.style
            )
        }
        let categories = database.categoryQueries.getAllCategories().executeAsList().map {
            CategoryRow(
                category_id: $0.category_id,
                creation_date: $0.creation_date,
                localized_name: $0.localized_name,
                hidden: $0.hidden != 0,
                sort_order: $0.sort_order,
                color_hex: $0.color_hex.map { Int64(truncating: $0) },
                symbol_name: $0.symbol_name
            )
        }
        let phrases = database.phraseQueries.getAllPhrases().executeAsList().map {
            PhraseRow(
                phrase_id: $0.phrase_id,
                parent_category_id: $0.parent_category_id,
                creation_date: $0.creation_date,
                last_spoken_date: $0.last_spoken_date.map { Int64(truncating: $0) },
                localized_utterance: $0.localized_utterance,
                sort_order: $0.sort_order,
                style: $0.style
            )
        }

        var images: [BackupImageEntry] = []
        var media: [BackupMediaEntry] = []
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        for relativePath in MediaStorage.listStoredRelativePaths() {
            guard let url = MediaStorage.resolveURL(mediaRef: relativePath),
                  let data = try? Data(contentsOf: url) else { continue }
            let entry = BackupImageEntry(
                id: relativePath,
                created_at: now,
                mime: MediaStorage.mimeType(forRelativePath: relativePath),
                data: data.base64EncodedString()
            )
            if relativePath.hasPrefix("\(MediaStorage.imagesFolderName)/") {
                images.append(entry)
            } else {
                media.append(BackupMediaEntry(
                    id: entry.id,
                    created_at: entry.created_at,
                    mime: entry.mime,
                    data: entry.data
                ))
            }
        }

        return BackupPayload(
            version: formatVersion,
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            platform: "ios",
            settings: settings.exportSnapshot(),
            presetCategory: presetCategories,
            presetPhrase: presetPhrases,
            category: categories,
            phrase: phrases,
            images: images,
            media: media
        )
    }

    static func exportJSONData() throws -> Data {
        let payload = try buildPayload()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else { throw BackupError.encodeFailed }
        return data
    }

    /// Writes backup JSON to a temporary file and returns its URL for sharing.
    static func writeExportFile() throws -> URL {
        let data = try exportJSONData()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(backupFilename())
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw BackupError.writeFailed
        }
    }

    static func importFromFile(url: URL) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BackupError.invalidJSON
        }
        try importFromData(data)
    }

    static func importFromData(_ data: Data) throws {
        let decoder = JSONDecoder()
        let payload: BackupPayload
        do {
            payload = try decoder.decode(BackupPayload.self, from: data)
        } catch {
            throw BackupError.invalidJSON
        }
        guard payload.version == formatVersion else {
            throw BackupError.unsupportedVersion
        }
        applyPayload(payload)
    }

    private static func applyPayload(_ payload: BackupPayload) {
        let database = DatabaseManager.shared.db

        // Clear existing rows
        for row in database.phraseQueries.getAllPhrases().executeAsList() {
            database.phraseQueries.deletePhrase(phrase_id: row.phrase_id)
        }
        for row in database.categoryQueries.getAllCategories().executeAsList() {
            database.categoryQueries.deleteCategory(category_id: row.category_id)
        }
        for row in database.presetPhraseQueries.getAllPresetPhrases().executeAsList() {
            database.presetPhraseQueries.updatePresetPhraseDeleted(deleted: 1, phrase_id: row.phrase_id)
        }
        for row in database.presetCategoryQueries.getAllPresetCategories().executeAsList() {
            database.presetCategoryQueries.updatePresetCategoryDeleted(deleted: 1, category_id: row.category_id)
        }

        MediaStorage.deleteAllStoredMedia()

        for cat in payload.presetCategory {
            database.presetCategoryQueries.insertPresetCategory(
                category_id: cat.category_id,
                hidden: cat.hidden,
                sort_order: cat.sort_order,
                deleted: cat.deleted,
                color_hex: cat.color_hex.map { KotlinLong(value: $0) },
                symbol_name: cat.symbol_name
            )
        }
        for phrase in payload.presetPhrase {
            database.presetPhraseQueries.insertPresetPhrase(
                phrase_id: phrase.phrase_id,
                parent_category_id: phrase.parent_category_id,
                creation_date: phrase.creation_date,
                last_spoken_date: phrase.last_spoken_date.map { KotlinLong(value: $0) },
                sort_order: phrase.sort_order,
                deleted: phrase.deleted,
                style: phrase.style
            )
        }
        for cat in payload.category {
            database.categoryQueries.insertCategory(
                category_id: cat.category_id,
                creation_date: cat.creation_date,
                localized_name: cat.localized_name,
                hidden: cat.hidden ? 1 : 0,
                sort_order: cat.sort_order,
                color_hex: cat.color_hex.map { KotlinLong(value: $0) },
                symbol_name: cat.symbol_name
            )
        }
        for phrase in payload.phrase {
            database.phraseQueries.insertPhrase(
                phrase_id: phrase.phrase_id,
                parent_category_id: phrase.parent_category_id,
                creation_date: phrase.creation_date,
                last_spoken_date: phrase.last_spoken_date.map { KotlinLong(value: $0) },
                localized_utterance: phrase.localized_utterance,
                sort_order: phrase.sort_order,
                style: phrase.style
            )
        }

        for img in payload.images {
            if let data = Data(base64Encoded: img.data) {
                _ = MediaStorage.writeRelativeFile(relativePath: img.id, data: data)
            }
        }
        for m in payload.media {
            if let data = Data(base64Encoded: m.data) {
                _ = MediaStorage.writeRelativeFile(relativePath: m.id, data: data)
            }
        }

        if let settings = payload.settings {
            AppSettings.shared.importSnapshot(settings)
        }

        DatabaseManager.shared.presetSchemaVersion = DatabaseManager.currentPresetSchemaVersion
        ImageCache.shared.clear()
        NotificationCenter.default.post(name: .switch2goDataDidRestore, object: nil)
        DebugLog.info("Backup import complete", tag: "DataBackup")
    }
}

extension Notification.Name {
    static let switch2goDataDidRestore = Notification.Name("Switch2GoDataDidRestore")
}

/// JSON-friendly Any values for settings snapshots.
enum AnyCodableValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int(d)
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i): return Double(i)
        default: return nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}
