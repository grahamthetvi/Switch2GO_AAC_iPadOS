import Foundation

enum MediaLibraryKind: String, Equatable, Identifiable {
    case picture
    case video
    case audio

    var id: String { rawValue }
}

enum MediaLibraryRole: Equatable {
    case picture
    case playback
}

struct MediaLibraryUsage: Equatable, Identifiable {
    let phraseId: String
    let phraseText: String
    let categoryId: String
    let categoryName: String
    let isPreset: Bool
    let role: MediaLibraryRole

    var id: String {
        switch role {
        case .picture:
            return "\(phraseId)|picture"
        case .playback:
            return "\(phraseId)|playback"
        }
    }
}

struct MediaLibraryPhraseSnapshot: Equatable {
    let phraseId: String
    let phraseText: String
    let categoryId: String
    let categoryName: String
    let isPreset: Bool
    /// Library-relative path (`Images/…` or `Media/…`), or nil when the phrase has no library file.
    let imageRef: String?
    let mediaRef: String?
}

struct MediaLibraryFileSnapshot: Equatable {
    let relativePath: String
    let byteSize: Int64
    let modifiedAt: Date
}

struct MediaLibraryItem: Equatable, Identifiable {
    let relativePath: String
    let kind: MediaLibraryKind
    let byteSize: Int64
    let modifiedAt: Date
    let usages: [MediaLibraryUsage]

    var id: String { relativePath }

    var fileExtension: String {
        (relativePath as NSString).pathExtension
    }
}

struct MediaLibraryPhraseStyleState: Equatable {
    var imageRef: String?
    var mediaRef: String?
    var mediaType: String?
    var gameType: String?
}

struct MediaLibraryEdit: Equatable {
    var style: MediaLibraryPhraseStyleState
    /// Generated stills to delete immediately. Library pictures, video, and audio are never listed here.
    var deletePosterPaths: [String]
    /// Previous generated still to delete only after a replacement still is saved.
    var posterPathReplacedByGeneratedStill: String?
    var generateVideoPoster: Bool
}

enum MediaLibraryCatalog {
    static let videoMediaType = "video"
    static let audioMediaType = "audio"

    private static let pictureExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif"]
    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]
    private static let audioExtensions: Set<String> = ["m4a", "mp3", "wav", "aac", "caf", "aiff", "aif"]

    /// Pictures, videos, and audio that belong in the library. Generated video stills return nil.
    static func kind(forRelativePath path: String) -> MediaLibraryKind? {
        if MediaStorage.isVideoPosterRef(path) { return nil }
        let ext = (path as NSString).pathExtension.lowercased()
        if pictureExtensions.contains(ext) { return .picture }
        if videoExtensions.contains(ext) { return .video }
        if audioExtensions.contains(ext) { return .audio }
        return nil
    }

    static func build(
        files: [MediaLibraryFileSnapshot],
        phrases: [MediaLibraryPhraseSnapshot]
    ) -> [MediaLibraryItem] {
        var usagesByPath: [String: [MediaLibraryUsage]] = [:]
        var seenUsages = Set<String>()

        for phrase in phrases {
            appendUsage(
                path: phrase.imageRef,
                phrase: phrase,
                role: .picture,
                into: &usagesByPath,
                seen: &seenUsages
            )
            appendUsage(
                path: phrase.mediaRef,
                phrase: phrase,
                role: .playback,
                into: &usagesByPath,
                seen: &seenUsages
            )
        }

        var items: [MediaLibraryItem] = []
        var seenPaths = Set<String>()
        for file in files {
            guard seenPaths.insert(file.relativePath).inserted else { continue }
            guard let kind = kind(forRelativePath: file.relativePath) else { continue }
            let usages = (usagesByPath[file.relativePath] ?? []).sorted { lhs, rhs in
                let byText = lhs.phraseText.localizedCaseInsensitiveCompare(rhs.phraseText)
                if byText != .orderedSame { return byText == .orderedAscending }
                return lhs.phraseId < rhs.phraseId
            }
            items.append(MediaLibraryItem(
                relativePath: file.relativePath,
                kind: kind,
                byteSize: file.byteSize,
                modifiedAt: file.modifiedAt,
                usages: usages
            ))
        }

        items.sort { lhs, rhs in
            if lhs.modifiedAt != rhs.modifiedAt { return lhs.modifiedAt > rhs.modifiedAt }
            return lhs.relativePath < rhs.relativePath
        }
        return items
    }

    static func attach(
        path: String,
        kind: MediaLibraryKind,
        to style: MediaLibraryPhraseStyleState
    ) -> MediaLibraryEdit {
        var style = style
        switch kind {
        case .picture:
            var posters: [String] = []
            if let image = style.imageRef, image != path, MediaStorage.isVideoPosterRef(image) {
                posters.append(image)
            }
            style.imageRef = path
            return MediaLibraryEdit(
                style: style,
                deletePosterPaths: posters,
                posterPathReplacedByGeneratedStill: nil,
                generateVideoPoster: false
            )
        case .video:
            let generate = shouldGenerateVideoPoster(imageRef: style.imageRef)
            var replaced: String?
            if generate, let image = style.imageRef, MediaStorage.isVideoPosterRef(image) {
                replaced = image
                style.imageRef = nil
            }
            style.mediaRef = path
            style.mediaType = videoMediaType
            style.gameType = nil
            return MediaLibraryEdit(
                style: style,
                deletePosterPaths: [],
                posterPathReplacedByGeneratedStill: replaced,
                generateVideoPoster: generate
            )
        case .audio:
            var posters: [String] = []
            if let image = style.imageRef, MediaStorage.isVideoPosterRef(image) {
                posters.append(image)
                style.imageRef = nil
            }
            style.mediaRef = path
            style.mediaType = audioMediaType
            style.gameType = nil
            return MediaLibraryEdit(
                style: style,
                deletePosterPaths: posters,
                posterPathReplacedByGeneratedStill: nil,
                generateVideoPoster: false
            )
        }
    }

    static func unlink(
        path: String,
        imageLibraryPath: String?,
        mediaLibraryPath: String?,
        from style: MediaLibraryPhraseStyleState
    ) -> MediaLibraryEdit {
        var style = style
        var posters: [String] = []
        if imageLibraryPath == path {
            style.imageRef = nil
        }
        if mediaLibraryPath == path {
            style.mediaRef = nil
            style.mediaType = nil
            if let image = style.imageRef, MediaStorage.isVideoPosterRef(image) {
                posters.append(image)
                style.imageRef = nil
            }
        }
        return MediaLibraryEdit(
            style: style,
            deletePosterPaths: posters,
            posterPathReplacedByGeneratedStill: nil,
            generateVideoPoster: false
        )
    }

    static func shouldGenerateVideoPoster(imageRef: String?) -> Bool {
        guard let imageRef, !imageRef.isEmpty else { return true }
        return MediaStorage.isVideoPosterRef(imageRef)
    }

    private static func appendUsage(
        path: String?,
        phrase: MediaLibraryPhraseSnapshot,
        role: MediaLibraryRole,
        into usagesByPath: inout [String: [MediaLibraryUsage]],
        seen: inout Set<String>
    ) {
        guard let path, kind(forRelativePath: path) != nil else { return }
        let roleKey: String
        switch role {
        case .picture:
            roleKey = "picture"
        case .playback:
            roleKey = "playback"
        }
        guard seen.insert("\(path)|\(phrase.phraseId)|\(roleKey)").inserted else { return }
        usagesByPath[path, default: []].append(MediaLibraryUsage(
            phraseId: phrase.phraseId,
            phraseText: phrase.phraseText,
            categoryId: phrase.categoryId,
            categoryName: phrase.categoryName,
            isPreset: phrase.isPreset,
            role: role
        ))
    }
}
