import Foundation
import UIKit
import VocableShared

enum PhrasePackImporter {
    static func copyIncomingFileToSandbox(_ url: URL) throws -> URL {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IncomingPacks", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("import-\(UUID().uuidString).\(PhrasePackFormat.fileExtension)")
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: url, to: dest)
        return dest
    }

    static func preview(fileURL: URL) throws -> PhrasePackPreview {
        let fm = FileManager.default
        let extractRoot = fm.temporaryDirectory.appendingPathComponent("s2g-preview-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: extractRoot) }
        try PhrasePackArchive.extract(packURL: fileURL, to: extractRoot)
        let manifest = try PhrasePackArchive.loadManifest(fromExtractRoot: extractRoot)
        let attrs = try fm.attributesOfItem(atPath: fileURL.path)
        let size = attrs[.size] as? Int64 ?? 0
        let videoCount = manifest.phrases.filter { $0.style?.mediaType == "video" }.count
        let unknown = manifest.phrases.filter { phrase in
            let style = phrase.style
            let unknownMedia = style?.mediaType.map { !PhrasePackFormat.knownMediaTypes.contains($0) } ?? false
            let unknownGame = style?.gameType.map { !$0.isEmpty && !PhrasePackFormat.knownGameTypes.contains($0) } ?? false
            return unknownMedia || unknownGame
        }.count
        return PhrasePackPreview(
            fileURL: fileURL,
            fileSize: size,
            manifest: manifest,
            exceedsEmailLimit: size > PhrasePackFormat.emailMaxBytes,
            videoCount: videoCount,
            unknownInteractiveCount: unknown
        )
    }

    static func collision(
        for incomingName: String,
        database: VocableDatabase = DatabaseManager.shared.db
    ) -> PhrasePackNameCollision {
        let key = CoreVocabulary.normalizeName(incomingName)
        if let preset = CoreVocabulary.presetDisplayName(matching: incomingName) {
            return .preset(displayName: preset)
        }
        let customs = database.categoryQueries.getAllCategories().executeAsList()
        if let match = customs.first(where: { CoreVocabulary.normalizeName($0.localized_name) == key }) {
            return .custom(id: match.category_id, name: match.localized_name)
        }
        return .none
    }

    static func importPack(
        fileURL: URL,
        destination: PhrasePackDestination,
        database: VocableDatabase = DatabaseManager.shared.db
    ) throws -> PhrasePackImportResult {
        let fm = FileManager.default
        let extractRoot = fm.temporaryDirectory.appendingPathComponent("s2g-import-\(UUID().uuidString)", isDirectory: true)
        var createdFiles: [URL] = []
        defer {
            try? fm.removeItem(at: extractRoot)
        }

        do {
            try PhrasePackArchive.extract(packURL: fileURL, to: extractRoot)
            let manifest = try PhrasePackArchive.loadManifest(fromExtractRoot: extractRoot)

            let (categoryId, categoryName, startingSort) = try resolveDestination(
                destination,
                manifest: manifest,
                database: database
            )

            let prepared = try preparePhrases(
                manifest: manifest,
                extractRoot: extractRoot,
                startingSort: startingSort,
                createdFiles: &createdFiles
            )

            try DatabaseManager.shared.transaction {
                if case .createNew(let name) = destination {
                    let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
                    let color = manifest.category.colorHex.map { KotlinLong(value: Int64($0)) }
                    database.categoryQueries.insertCategoryExclusive(
                        category_id: categoryId,
                        creation_date: timestamp,
                        localized_name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? manifest.category.name : name,
                        hidden: 0,
                        sort_order: -timestamp,
                        color_hex: color,
                        symbol_name: manifest.category.symbolName ?? "folder.fill"
                    )
                } else if case .merge = destination {
                    database.categoryQueries.updateCategoryHidden(hidden: 0, category_id: categoryId)
                }
                for phrase in prepared.phrases {
                    database.phraseQueries.insertPhraseExclusive(
                        phrase_id: phrase.id,
                        parent_category_id: categoryId,
                        creation_date: phrase.creationDate,
                        last_spoken_date: nil,
                        localized_utterance: phrase.text,
                        sort_order: Int64(phrase.sortOrder),
                        style: phrase.styleJSON
                    )
                }
            }

            return PhrasePackImportResult(
                categoryId: categoryId,
                categoryName: categoryName,
                phraseCount: prepared.phrases.count,
                droppedInteractive: prepared.droppedInteractive
            )
        } catch {
            for url in createdFiles {
                try? fm.removeItem(at: url)
            }
            if isDiskFull(error) {
                throw PhrasePackError.diskFull
            }
            throw error
        }
    }

    private struct PreparedPhrase {
        let id: String
        let text: String
        let sortOrder: Int
        let creationDate: Int64
        let styleJSON: String?
    }

    private struct PreparedPack {
        let phrases: [PreparedPhrase]
        let droppedInteractive: Bool
    }

    private static func resolveDestination(
        _ destination: PhrasePackDestination,
        manifest: PhrasePackManifest,
        database: VocableDatabase
    ) throws -> (id: String, name: String, startingSort: Int) {
        switch destination {
        case .createNew(let name):
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalName = trimmed.isEmpty ? manifest.category.name : trimmed
            if CoreVocabulary.presetDisplayName(matching: finalName) != nil {
                throw PhrasePackError.protectedCategory
            }
            return ("custom_\(UUID().uuidString)", finalName, 0)
        case .merge(let categoryId):
            if CoreVocabulary.isProtectedCategoryId(categoryId) {
                throw PhrasePackError.protectedCategory
            }
            guard let existing = database.categoryQueries.getCategoryById(category_id: categoryId).executeAsOneOrNull() else {
                throw PhrasePackError.importFailed("The selected category no longer exists.")
            }
            let existingPhrases = database.phraseQueries
                .getPhrasesForCategory(parent_category_id: categoryId)
                .executeAsList()
            let maxSort = existingPhrases.map { Int($0.sort_order) }.max() ?? -1
            return (categoryId, existing.localized_name, maxSort + 1)
        }
    }

    private static func preparePhrases(
        manifest: PhrasePackManifest,
        extractRoot: URL,
        startingSort: Int,
        createdFiles: inout [URL]
    ) throws -> PreparedPack {
        var dropped = false
        var prepared: [PreparedPhrase] = []
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        for (index, phrase) in manifest.phrases.enumerated() {
            var style = phrase.style
            if let mediaType = style?.mediaType, !PhrasePackFormat.knownMediaTypes.contains(mediaType) {
                style?.media = nil
                style?.mediaType = nil
                dropped = true
            }
            if let gameType = style?.gameType, !gameType.isEmpty, !PhrasePackFormat.knownGameTypes.contains(gameType) {
                style?.gameType = nil
                dropped = true
            }

            let rewritten = try materializeStyle(style, extractRoot: extractRoot, createdFiles: &createdFiles)
            let styleJSON: String?
            if let rewritten {
                styleJSON = rewritten.toJSONString()
            } else {
                styleJSON = nil
            }

            prepared.append(PreparedPhrase(
                id: "custom_\(UUID().uuidString)",
                text: phrase.text,
                sortOrder: startingSort + index,
                creationDate: now,
                styleJSON: styleJSON
            ))
        }
        return PreparedPack(phrases: prepared, droppedInteractive: dropped)
    }

    private static func materializeStyle(
        _ packStyle: PhrasePackStyle?,
        extractRoot: URL,
        createdFiles: inout [URL]
    ) throws -> PhraseStyle? {
        guard let packStyle else { return nil }

        var imageRef: String?
        if let image = packStyle.image, !image.isEmpty {
            if image.hasPrefix("emoji:") {
                imageRef = image
            } else if image.hasPrefix("assets/") {
                imageRef = try copyPackImage(relativePath: image, extractRoot: extractRoot, createdFiles: &createdFiles)
            }
        }

        if imageRef == nil, let thumb = packStyle.thumb, thumb.hasPrefix("assets/") {
            imageRef = try copyPackImage(relativePath: thumb, extractRoot: extractRoot, createdFiles: &createdFiles)
        }

        var mediaRef: String?
        var mediaType: String?
        if let media = packStyle.media, let type = packStyle.mediaType {
            if type == "youtube" || media.hasPrefix("youtube:") {
                mediaRef = media.hasPrefix("youtube:") ? media : "youtube:\(media)"
                mediaType = "youtube"
            } else if media.hasPrefix("assets/") {
                let fileURL = try requireAsset(relativePath: media, extractRoot: extractRoot)
                let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let size = attrs[.size] as? Int64 ?? 0
                if size > PhrasePackFormat.maxMediaBytes {
                    throw PhrasePackError.mediaTooLarge
                }
                let ext = fileURL.pathExtension.isEmpty ? "bin" : fileURL.pathExtension
                guard let saved = MediaStorage.saveMedia(from: fileURL, preferredExtension: ext) else {
                    throw PhrasePackError.mediaTooLarge
                }
                createdFiles.append(saved)
                mediaRef = saved.absoluteString
                mediaType = type
            }
        }

        let style = PhraseStyle(
            backgroundColor: packStyle.backgroundColor.map { KotlinUInt(value: UInt32($0)) },
            textColor: packStyle.textColor.map { KotlinUInt(value: UInt32($0)) },
            textSizeSp: packStyle.textSizeSp.map { KotlinFloat(value: $0) },
            isBold: packStyle.isBold,
            borderColor: packStyle.borderColor.map { KotlinUInt(value: UInt32($0)) },
            borderWidthDp: packStyle.borderWidthDp.map { KotlinFloat(value: $0) },
            imageRef: imageRef,
            mediaRef: mediaRef,
            mediaType: mediaType,
            gameType: packStyle.gameType
        )
        return style
    }

    private static func copyPackImage(
        relativePath: String,
        extractRoot: URL,
        createdFiles: inout [URL]
    ) throws -> String {
        let source = try requireAsset(relativePath: relativePath, extractRoot: extractRoot)
        guard let data = try? Data(contentsOf: source), let image = UIImage(data: data) else {
            throw PhrasePackError.invalidImage
        }
        let saved: URL?
        if image.hasAlpha(), let png = image.pngData() {
            saved = PhraseImageStore.savePNG(png)
        } else if let jpeg = image.jpegData(compressionQuality: 0.85) {
            saved = PhraseImageStore.saveJPEG(jpeg)
        } else {
            saved = nil
        }
        guard let saved else { throw PhrasePackError.invalidImage }
        createdFiles.append(saved)
        return saved.absoluteString
    }

    private static func requireAsset(relativePath: String, extractRoot: URL) throws -> URL {
        let relative = try PhrasePackPath.validatedRelativePath(relativePath)
        if !PhrasePackPath.isAllowedPackPath(relative) {
            throw PhrasePackError.zipSlip(relativePath)
        }
        let url = try PhrasePackPath.destinationURL(extractRoot: extractRoot, relativePath: relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PhrasePackError.missingAsset(relativePath)
        }
        return url
    }

    private static func isDiskFull(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError
    }
}
