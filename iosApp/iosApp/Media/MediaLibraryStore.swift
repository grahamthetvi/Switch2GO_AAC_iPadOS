import Foundation
import UIKit
import VocableShared

enum MediaLibraryAttachResult: Equatable {
    case attached
    case alreadyAttached
    case missingPhrase
}

enum MediaLibraryImportError: LocalizedError {
    case tooLarge
    case videoTooLong(seconds: Int)
    case unreadableVideo
    case invalidImage
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .tooLarge:
            return L("Could not save file (max 100 MB).")
        case .videoTooLong(let seconds):
            return L("Videos must be 20 seconds or shorter. This video is %@ seconds.", "\(seconds)")
        case .unreadableVideo:
            return L("Could not read this video.")
        case .invalidImage:
            return L("Could not read this picture.")
        case .saveFailed:
            return L("Could not save this file.")
        }
    }
}

struct MediaLibraryDestinationPhrase: Identifiable, Equatable {
    let phraseId: String
    let phraseText: String
    let isPreset: Bool
    let alreadyUsesFile: Bool

    var id: String { "\(isPreset ? "preset" : "custom")|\(phraseId)" }
}

struct MediaLibraryDestination: Identifiable, Equatable {
    let categoryId: String
    let categoryName: String
    let isHidden: Bool
    let phrases: [MediaLibraryDestinationPhrase]

    var id: String { categoryId }
}

enum MediaLibraryStore {
    static func loadItems(database: VocableDatabase = DatabaseManager.shared.db) -> [MediaLibraryItem] {
        DatabaseManager.shared.syncWrite {
            let files = MediaStorage.listStoredFiles().map {
                MediaLibraryFileSnapshot(
                    relativePath: $0.relativePath,
                    byteSize: $0.byteSize,
                    modifiedAt: $0.modifiedAt
                )
            }
            let phrases = phraseRecords(database: database).map { record in
                MediaLibraryPhraseSnapshot(
                    phraseId: record.phraseId,
                    phraseText: record.phraseText,
                    categoryId: record.categoryId,
                    categoryName: record.categoryName,
                    isPreset: record.isPreset,
                    imageRef: libraryRelativePath(for: record.imageRef),
                    mediaRef: libraryRelativePath(for: record.mediaRef)
                )
            }
            return MediaLibraryCatalog.build(files: files, phrases: phrases)
        }
    }

    static func destinations(
        for relativePath: String,
        kind: MediaLibraryKind,
        database: VocableDatabase = DatabaseManager.shared.db
    ) -> [MediaLibraryDestination] {
        DatabaseManager.shared.syncWrite {
            var buckets: [String: DestinationBucket] = [:]
            for record in phraseRecords(database: database) {
                let usesFile: Bool
                switch kind {
                case .picture:
                    usesFile = libraryRelativePath(for: record.imageRef) == relativePath
                case .video, .audio:
                    usesFile = libraryRelativePath(for: record.mediaRef) == relativePath
                }
                var bucket = buckets[record.categoryId] ?? DestinationBucket(
                    categoryId: record.categoryId,
                    categoryName: record.categoryName,
                    isHidden: record.categoryIsHidden,
                    sortOrder: record.categorySortOrder,
                    phrases: []
                )
                bucket.phrases.append(OrderedDestinationPhrase(
                    sortOrder: record.phraseSortOrder,
                    phraseId: record.phraseId,
                    phraseText: record.phraseText,
                    isPreset: record.isPreset,
                    alreadyUsesFile: usesFile
                ))
                buckets[record.categoryId] = bucket
            }

            return buckets.values
                .sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                    return lhs.categoryId < rhs.categoryId
                }
                .map { bucket in
                    let phrases = bucket.phrases.sorted { $0.sortOrder < $1.sortOrder }
                    return MediaLibraryDestination(
                        categoryId: bucket.categoryId,
                        categoryName: bucket.categoryName,
                        isHidden: bucket.isHidden,
                        phrases: phrases.map {
                            MediaLibraryDestinationPhrase(
                                phraseId: $0.phraseId,
                                phraseText: $0.phraseText,
                                isPreset: $0.isPreset,
                                alreadyUsesFile: $0.alreadyUsesFile
                            )
                        }
                    )
                }
        }
    }

    @discardableResult
    static func attach(
        relativePath: String,
        kind: MediaLibraryKind,
        phraseId: String,
        isPreset: Bool,
        database: VocableDatabase = DatabaseManager.shared.db
    ) -> MediaLibraryAttachResult {
        let result: MediaLibraryAttachResult = DatabaseManager.shared.syncWrite {
            guard let record = phraseRecords(database: database).first(where: {
                $0.phraseId == phraseId && $0.isPreset == isPreset
            }) else {
                return .missingPhrase
            }

            switch kind {
            case .picture:
                if libraryRelativePath(for: record.imageRef) == relativePath { return .alreadyAttached }
            case .video, .audio:
                if libraryRelativePath(for: record.mediaRef) == relativePath { return .alreadyAttached }
            }

            let state = styleState(from: record)
            var edit = MediaLibraryCatalog.attach(path: relativePath, kind: kind, to: state)
            if edit.generateVideoPoster,
               let url = MediaStorage.resolveURL(mediaRef: relativePath),
               let data = VideoPosterGenerator.jpegPoster(from: url),
               let saved = MediaStorage.savePosterImage(data: data) {
                edit.style.imageRef = saved
                if let oldPoster = edit.posterPathReplacedByGeneratedStill, oldPoster != saved {
                    MediaStorage.deleteMedia(mediaRef: oldPoster)
                }
            } else if edit.generateVideoPoster {
                edit.style.imageRef = record.imageRef
            }

            for poster in edit.deletePosterPaths where poster != edit.style.imageRef {
                MediaStorage.deleteMedia(mediaRef: poster)
            }

            guard let json = merged(base: record.style, media: edit.style).toJSONString() else {
                return .missingPhrase
            }
            writeStyle(json, phraseId: phraseId, isPreset: isPreset, database: database)
            return .attached
        }
        if result == .attached {
            postPhrasesUpdated()
        }
        return result
    }

    static func remove(
        relativePath: String,
        database: VocableDatabase = DatabaseManager.shared.db
    ) {
        DatabaseManager.shared.syncWrite {
            var posters: [String] = []
            for record in phraseRecords(database: database) {
                let imagePath = libraryRelativePath(for: record.imageRef)
                let mediaPath = libraryRelativePath(for: record.mediaRef)
                guard imagePath == relativePath || mediaPath == relativePath else { continue }
                let edit = MediaLibraryCatalog.unlink(
                    path: relativePath,
                    imageLibraryPath: imagePath,
                    mediaLibraryPath: mediaPath,
                    from: styleState(from: record)
                )
                posters.append(contentsOf: edit.deletePosterPaths)
                guard let json = merged(base: record.style, media: edit.style).toJSONString() else { continue }
                writeStyle(json, phraseId: record.phraseId, isPreset: record.isPreset, database: database)
            }
            for poster in posters {
                MediaStorage.deleteMedia(mediaRef: poster)
            }
            MediaStorage.deleteMedia(mediaRef: relativePath)
        }
        postPhrasesUpdated()
    }

    static func importPicture(data: Data) throws -> String {
        guard let image = UIImage(data: data) else {
            throw MediaLibraryImportError.invalidImage
        }
        let imageData: Data?
        let ext: String
        if image.hasAlpha(), let png = image.pngData() {
            imageData = png
            ext = "png"
        } else if let jpeg = image.jpegData(compressionQuality: 0.85) {
            imageData = jpeg
            ext = "jpg"
        } else {
            imageData = nil
            ext = "jpg"
        }
        guard let imageData else { throw MediaLibraryImportError.invalidImage }
        if Int64(imageData.count) > MediaStorage.maxFileBytes {
            throw MediaLibraryImportError.tooLarge
        }
        guard let ref = MediaStorage.saveImage(data: imageData, preferredExtension: ext) else {
            throw MediaLibraryImportError.saveFailed
        }
        return ref
    }

    static func importFile(from url: URL, kind: MediaLibraryKind) async throws -> String {
        switch kind {
        case .picture:
            throw MediaLibraryImportError.invalidImage
        case .video:
            let seconds: Double
            do {
                seconds = try await VideoDurationLimiter.durationSeconds(url: url)
            } catch {
                throw MediaLibraryImportError.unreadableVideo
            }
            if !VideoDurationLimiter.isWithinLimit(seconds) {
                throw MediaLibraryImportError.videoTooLong(seconds: Int(seconds.rounded()))
            }
            return try await copyImportedFileOffMain(from: url, fallbackExtension: "mp4")
        case .audio:
            return try await copyImportedFileOffMain(from: url, fallbackExtension: "m4a")
        }
    }

    private static func copyImportedFileOffMain(from url: URL, fallbackExtension: String) async throws -> String {
        try await Task.detached(priority: .userInitiated) { () throws -> String in
            try copyImportedFile(from: url, fallbackExtension: fallbackExtension)
        }.value
    }

    /// Relative library path for a stored ref, or nil for emoji, YouTube, generated stills, and missing files that are not already relative.
    static func libraryRelativePath(for ref: String?) -> String? {
        guard let ref, !ref.isEmpty else { return nil }
        if ref.hasPrefix("emoji:") || ref.hasPrefix("youtube:") { return nil }
        if MediaStorage.isVideoPosterRef(ref) { return nil }

        let relative: String
        if MediaStorage.isRelativeFileRef(ref) {
            relative = ref
        } else if let url = MediaStorage.resolveURL(mediaRef: ref),
                  let resolved = relativePathInDocuments(url) {
            relative = resolved
        } else {
            return nil
        }

        guard MediaStorage.isRelativeFileRef(relative) else { return nil }
        return MediaLibraryCatalog.kind(forRelativePath: relative) == nil ? nil : relative
    }

    private static func copyImportedFile(from url: URL, fallbackExtension: String) throws -> String {
        let ext = (url.pathExtension.isEmpty ? fallbackExtension : url.pathExtension).lowercased()
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs[.size] as? Int64 ?? 0
        if size > MediaStorage.maxFileBytes {
            throw MediaLibraryImportError.tooLarge
        }
        guard let ref = MediaStorage.saveMedia(from: url, preferredExtension: ext) else {
            throw MediaLibraryImportError.saveFailed
        }
        return ref
    }

    private static func relativePathInDocuments(_ url: URL) -> String? {
        let docs = MediaStorage.documentsDirectory.standardizedFileURL.path
        let file = url.standardizedFileURL.path
        let prefix = docs.hasSuffix("/") ? docs : docs + "/"
        guard file.hasPrefix(prefix) else { return nil }
        return String(file.dropFirst(prefix.count))
    }

    private static func styleState(from record: PhraseRecord) -> MediaLibraryPhraseStyleState {
        MediaLibraryPhraseStyleState(
            imageRef: record.imageRef,
            mediaRef: record.mediaRef,
            mediaType: record.mediaType,
            gameType: record.gameType
        )
    }

    private static func merged(base: PhraseStyle?, media: MediaLibraryPhraseStyleState) -> PhraseStyle {
        let style = PhraseStyle(
            backgroundColor: base?.backgroundColor,
            textColor: base?.textColor,
            textSizeSp: base?.textSizeSp,
            isBold: base?.isBold ?? false,
            borderColor: base?.borderColor,
            borderWidthDp: base?.borderWidthDp,
            imageRef: media.imageRef,
            mediaRef: media.mediaRef,
            mediaType: media.mediaType,
            gameType: media.gameType
        )
        style.sendSwitchOutput = base?.sendSwitchOutput ?? false
        return style
    }

    private static func writeStyle(
        _ json: String,
        phraseId: String,
        isPreset: Bool,
        database: VocableDatabase
    ) {
        if isPreset {
            database.presetPhraseQueries.updatePresetPhraseStyle(style: json, phrase_id: phraseId)
        } else {
            database.phraseQueries.updatePhraseStyle(style: json, phrase_id: phraseId)
        }
    }

    private static func postPhrasesUpdated() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("PhrasesUpdated"), object: nil)
        }
    }

    private struct OrderedDestinationPhrase {
        let sortOrder: Int
        let phraseId: String
        let phraseText: String
        let isPreset: Bool
        let alreadyUsesFile: Bool
    }

    private struct DestinationBucket {
        var categoryId: String
        var categoryName: String
        var isHidden: Bool
        var sortOrder: Int
        var phrases: [OrderedDestinationPhrase]
    }

    private struct PhraseRecord {
        let phraseId: String
        let phraseText: String
        let categoryId: String
        let categoryName: String
        let categorySortOrder: Int
        let categoryIsHidden: Bool
        let phraseSortOrder: Int
        let isPreset: Bool
        let imageRef: String?
        let mediaRef: String?
        let mediaType: String?
        let gameType: String?
        let style: PhraseStyle?
    }

    private struct CategoryMeta {
        let name: String
        let sortOrder: Int
        let isHidden: Bool
        let isDeleted: Bool
    }

    private static func phraseRecords(database: VocableDatabase) -> [PhraseRecord] {
        var categories: [String: CategoryMeta] = [:]
        for category in database.presetCategoryQueries.getAllPresetCategories().executeAsList() {
            categories[category.category_id] = CategoryMeta(
                name: CoreVocabulary.categoryName(for: category.category_id),
                sortOrder: Int(category.sort_order),
                isHidden: category.hidden == 1,
                isDeleted: category.deleted != 0
            )
        }
        for category in database.categoryQueries.getAllCategories().executeAsList() {
            categories[category.category_id] = CategoryMeta(
                name: category.localized_name,
                sortOrder: Int(category.sort_order),
                isHidden: category.hidden == 1,
                isDeleted: false
            )
        }

        var records: [PhraseRecord] = []
        for phrase in database.presetPhraseQueries.getAllPresetPhrases().executeAsList() {
            if phrase.deleted != 0 { continue }
            let categoryId = phrase.parent_category_id
            if CoreVocabulary.isRecents(categoryId) { continue }
            if categories[categoryId]?.isDeleted == true { continue }
            let style = PhraseStyle.fromJSONString(phrase.style)
            let text = CoreVocabulary.phraseText(for: phrase.phrase_id, fallback: phrase.phrase_id)
            records.append(makeRecord(
                phraseId: phrase.phrase_id,
                phraseText: text.isEmpty ? phrase.phrase_id : text,
                categoryId: categoryId,
                categories: categories,
                phraseSortOrder: Int(phrase.sort_order),
                isPreset: true,
                style: style
            ))
        }

        for phrase in database.phraseQueries.getAllPhrases().executeAsList() {
            let categoryId = phrase.parent_category_id ?? ""
            if categoryId.isEmpty || CoreVocabulary.isRecents(categoryId) { continue }
            if categories[categoryId]?.isDeleted == true { continue }
            let style = PhraseStyle.fromJSONString(phrase.style)
            let text = phrase.localized_utterance ?? ""
            records.append(makeRecord(
                phraseId: phrase.phrase_id,
                phraseText: text.isEmpty ? phrase.phrase_id : text,
                categoryId: categoryId,
                categories: categories,
                phraseSortOrder: Int(phrase.sort_order),
                isPreset: false,
                style: style
            ))
        }
        return records
    }

    private static func makeRecord(
        phraseId: String,
        phraseText: String,
        categoryId: String,
        categories: [String: CategoryMeta],
        phraseSortOrder: Int,
        isPreset: Bool,
        style: PhraseStyle?
    ) -> PhraseRecord {
        let meta = categories[categoryId]
        return PhraseRecord(
            phraseId: phraseId,
            phraseText: phraseText,
            categoryId: categoryId,
            categoryName: meta?.name ?? categoryId,
            categorySortOrder: meta?.sortOrder ?? 0,
            categoryIsHidden: meta?.isHidden ?? false,
            phraseSortOrder: phraseSortOrder,
            isPreset: isPreset,
            imageRef: style?.imageRef,
            mediaRef: style?.mediaRef,
            mediaType: style?.mediaType,
            gameType: style?.gameType,
            style: style
        )
    }
}
