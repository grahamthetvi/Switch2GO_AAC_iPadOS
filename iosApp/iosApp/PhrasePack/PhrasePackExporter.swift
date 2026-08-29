import Foundation
import UIKit
import VocableShared

struct PhrasePackExportResult {
    let fileURL: URL
    let fileSize: Int64
    let exceedsEmailLimit: Bool
    let phraseCount: Int
}

enum PhrasePackExporter {
    static func exportCategory(
        category: CategoryDisplayModel,
        database: VocableDatabase = DatabaseManager.shared.db
    ) throws -> PhrasePackExportResult {
        if CoreVocabulary.isRecents(category.id) {
            throw PhrasePackError.recentsCannotExport
        }

        let fm = FileManager.default
        let staging = fm.temporaryDirectory.appendingPathComponent("s2g-export-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }

        try fm.createDirectory(at: staging.appendingPathComponent("assets/images", isDirectory: true), withIntermediateDirectories: true)
        try fm.createDirectory(at: staging.appendingPathComponent("assets/thumbs", isDirectory: true), withIntermediateDirectories: true)
        try fm.createDirectory(at: staging.appendingPathComponent("assets/media", isDirectory: true), withIntermediateDirectories: true)

        let packPhrases = try buildPhrases(categoryId: category.id, database: database, staging: staging)
        let categoryName = category.isPreset
            ? (CoreVocabulary.presetCategoryNames[category.id] ?? category.name)
            : category.name
        let color = category.colorHex ?? CoreVocabulary.defaultCategoryColors[category.id]
        let symbol = category.symbolName ?? CoreVocabulary.defaultCategorySymbols[category.id] ?? "folder.fill"

        let manifest = PhrasePackManifest(
            formatVersion: PhrasePackFormat.currentVersion,
            packId: UUID().uuidString,
            displayName: categoryName,
            createdAt: Int64(Date().timeIntervalSince1970 * 1000),
            source: "ios",
            category: PhrasePackCategory(
                id: "pack_category_1",
                name: categoryName,
                colorHex: color,
                symbolName: symbol
            ),
            phrases: packPhrases
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: staging.appendingPathComponent(PhrasePackFormat.manifestFileName), options: .atomic)

        let exportDir = fm.temporaryDirectory.appendingPathComponent("s2g-packs", isDirectory: true)
        try fm.createDirectory(at: exportDir, withIntermediateDirectories: true)
        let dest = exportDir.appendingPathComponent(PhrasePackPath.sanitizedExportFileName(categoryName))
        try PhrasePackArchive.create(fromStagingDirectory: staging, to: dest)

        let attrs = try fm.attributesOfItem(atPath: dest.path)
        let size = attrs[.size] as? Int64 ?? 0
        return PhrasePackExportResult(
            fileURL: dest,
            fileSize: size,
            exceedsEmailLimit: size > PhrasePackFormat.emailMaxBytes,
            phraseCount: packPhrases.count
        )
    }

    private static func buildPhrases(
        categoryId: String,
        database: VocableDatabase,
        staging: URL
    ) throws -> [PhrasePackPhrase] {
        var items: [(sort: Int, text: String, style: PhraseStyle?)] = []

        let presets = database.presetPhraseQueries
            .getPresetPhrasesForCategory(parent_category_id: categoryId)
            .executeAsList()
        for phrase in presets {
            let text = CoreVocabulary.phraseText(for: phrase.phrase_id, fallback: phrase.phrase_id)
            let style = PhraseStyle.fromJSONString(phrase.style)
            items.append((sort: Int(phrase.sort_order), text: text, style: style))
        }

        let customs = database.phraseQueries
            .getPhrasesForCategory(parent_category_id: categoryId)
            .executeAsList()
        for phrase in customs {
            let style = PhraseStyle.fromJSONString(phrase.style)
            items.append((sort: Int(phrase.sort_order), text: phrase.localized_utterance ?? "", style: style))
        }

        items.sort { $0.sort < $1.sort }

        var packPhrases: [PhrasePackPhrase] = []
        for (index, item) in items.enumerated() {
            let packId = String(format: "pack_phrase_%02d", index + 1)
            let packStyle = try rewriteStyle(item.style, index: index, staging: staging)
            packPhrases.append(PhrasePackPhrase(
                id: packId,
                text: item.text,
                sortOrder: index,
                style: packStyle
            ))
        }
        return packPhrases
    }

    private static func rewriteStyle(_ style: PhraseStyle?, index: Int, staging: URL) throws -> PhrasePackStyle? {
        guard let style else { return nil }
        var pack = PhrasePackStyle(
            backgroundColor: style.backgroundColor.map { UInt($0.uint32Value) },
            textColor: style.textColor.map { UInt($0.uint32Value) },
            textSizeSp: style.textSizeSp?.floatValue,
            isBold: style.isBold,
            borderColor: style.borderColor.map { UInt($0.uint32Value) },
            borderWidthDp: style.borderWidthDp?.floatValue,
            image: nil,
            media: nil,
            mediaType: nil,
            thumb: nil,
            gameType: style.gameType
        )

        if let imageRef = style.imageRef, !imageRef.isEmpty {
            if imageRef.hasPrefix(PhraseStyle.EMOJI_PREFIX) {
                pack.image = imageRef
            } else if let fileURL = PhraseImageStore.resolveLocalFile(imageRef) {
                pack.image = try copyNormalizedImage(fileURL, into: staging, name: "p\(index + 1)")
            }
        }

        if let mediaType = style.mediaType, let mediaRef = style.mediaRef, !mediaRef.isEmpty {
            if mediaType == PhraseStyle.companion.MEDIA_TYPE_YOUTUBE || mediaRef.hasPrefix("youtube:") {
                pack.media = mediaRef.hasPrefix("youtube:") ? mediaRef : "youtube:\(mediaRef)"
                pack.mediaType = "youtube"
            } else if MediaStorage.isLocalMediaRef(mediaRef), let fileURL = MediaStorage.resolveURL(mediaRef: mediaRef) {
                let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let size = attrs[.size] as? Int64 ?? 0
                if size > PhrasePackFormat.maxMediaBytes {
                    throw PhrasePackError.mediaTooLarge
                }
                pack.media = try copyAsset(fileURL, into: staging, folder: "assets/media", name: "p\(index + 1)")
                pack.mediaType = mediaType
                if mediaType == PhraseStyle.companion.MEDIA_TYPE_VIDEO {
                    if let poster = VideoPosterGenerator.jpegPoster(from: fileURL) {
                        let thumbRel = "assets/thumbs/p\(index + 1).jpg"
                        try poster.write(to: staging.appendingPathComponent(thumbRel), options: .atomic)
                        pack.thumb = thumbRel
                    }
                }
            }
        }

        if pack.backgroundColor == nil && pack.textColor == nil && pack.textSizeSp == nil
            && !pack.isBold && pack.borderColor == nil && pack.borderWidthDp == nil
            && pack.image == nil && pack.media == nil && pack.gameType == nil && pack.thumb == nil {
            return nil
        }
        return pack
    }

    private static func copyAsset(_ source: URL, into staging: URL, folder: String, name: String) throws -> String {
        let ext = source.pathExtension.isEmpty ? "bin" : source.pathExtension.lowercased()
        let relative = "\(folder)/\(name).\(ext)"
        let dest = staging.appendingPathComponent(relative)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: source, to: dest)
        return relative
    }

    private static func copyNormalizedImage(_ source: URL, into staging: URL, name: String) throws -> String {
        guard let data = try? Data(contentsOf: source), let image = UIImage(data: data) else {
            throw PhrasePackError.invalidImage
        }
        let relative: String
        let dest: URL
        if image.hasAlpha(), let png = image.pngData() {
            relative = "assets/images/\(name).png"
            dest = staging.appendingPathComponent(relative)
            try png.write(to: dest, options: .atomic)
        } else if let jpeg = image.jpegData(compressionQuality: 0.85) {
            relative = "assets/images/\(name).jpg"
            dest = staging.appendingPathComponent(relative)
            try jpeg.write(to: dest, options: .atomic)
        } else {
            throw PhrasePackError.invalidImage
        }
        return relative
    }
}
