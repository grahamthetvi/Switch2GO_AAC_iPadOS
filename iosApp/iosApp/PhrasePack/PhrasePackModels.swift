import Foundation
import UniformTypeIdentifiers

enum PhrasePackFormat {
    static let currentVersion = 1
    static let fileExtension = "switch2go"
    static let utiIdentifier = "org.switch2go.phrasepack"
    static let manifestFileName = "manifest.json"
    static let emailMaxBytes: Int64 = 25_952_256 // 24.75 MiB
    static let maxMediaBytes: Int64 = 100 * 1024 * 1024
    static let maxVideoDurationSeconds: Double = 20
    static let maxZipEntries = 500
    static let maxUncompressedBytes: Int64 = 512 * 1024 * 1024
    static let maxCompressionRatio: Int64 = 100

    static let knownMediaTypes: Set<String> = ["video", "audio", "youtube"]
    static let knownGameTypes: Set<String> = ["cursor_rocket", "blocs", "pie_crazy"]
}

extension UTType {
    static var switch2goPhrasePack: UTType {
        UTType(exportedAs: PhrasePackFormat.utiIdentifier)
    }
}

enum CoreVocabulary {
    static let recentsId = "preset_recents"

    static let presetCategoryIds: Set<String> = [
        "preset_routine_activity",
        "preset_food_drink",
        "preset_comfort_state",
        "preset_play_leisure",
        "preset_positioning",
        "preset_recents"
    ]

    static let presetCategoryNames: [String: String] = [
        "preset_routine_activity": "Daily Activities",
        "preset_food_drink": "Food & Drinks",
        "preset_comfort_state": "How I Feel",
        "preset_play_leisure": "Fun & Games",
        "preset_positioning": "Move Me",
        "preset_recents": "Recently Said"
    ]

    static let presetPhraseTexts: [String: String] = [
        "preset_need_help": "I need help",
        "preset_all_done": "I'm all done",
        "preset_want_more": "I want more",
        "preset_take_break": "I need a break",
        "preset_eat_food": "I want to eat",
        "preset_drink_water": "I want a drink",
        "preset_more_please": "More please",
        "preset_no_more": "No more",
        "preset_it_hurts": "It hurts",
        "preset_feel_good": "I feel good",
        "preset_i_am_hot": "I'm hot",
        "preset_i_am_cold": "I'm cold",
        "preset_go_now": "Let's go",
        "preset_stop_now": "Stop",
        "preset_my_turn": "My turn",
        "preset_your_turn": "Your turn",
        "preset_move_me": "Move me",
        "preset_stay_here": "Stay here",
        "preset_sit_up": "Sit me up",
        "preset_lay_back": "Lay me back"
    ]

    static let defaultCategoryColors: [String: UInt32] = [
        "preset_routine_activity": 0xFFE53935,
        "preset_food_drink": 0xFF1E88E5,
        "preset_comfort_state": 0xFF43A047,
        "preset_play_leisure": 0xFFFB8C00,
        "preset_positioning": 0xFF8E24AA,
        "preset_recents": 0xFFF06292
    ]

    static let defaultCategorySymbols: [String: String] = [
        "preset_routine_activity": "checklist",
        "preset_food_drink": "fork.knife",
        "preset_comfort_state": "heart.fill",
        "preset_play_leisure": "gamecontroller.fill",
        "preset_positioning": "figure.stand",
        "preset_recents": "clock.arrow.circlepath"
    ]

    static func isProtectedCategoryId(_ id: String) -> Bool {
        id.hasPrefix("preset_")
    }

    static func isRecents(_ id: String) -> Bool {
        id == recentsId
    }

    static func presetDisplayName(matching name: String) -> String? {
        let key = normalizeName(name)
        return presetCategoryNames.first { normalizeName($0.value) == key }?.value
    }

    static func normalizeName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func phraseText(for phraseId: String, fallback: String) -> String {
        presetPhraseTexts[phraseId] ?? fallback
    }
}

struct PhrasePackManifest: Codable, Equatable {
    var formatVersion: Int
    var packId: String
    var displayName: String
    var createdAt: Int64
    var source: String
    var category: PhrasePackCategory
    var phrases: [PhrasePackPhrase]
}

struct PhrasePackCategory: Codable, Equatable {
    var id: String
    var name: String
    var colorHex: UInt32?
    var symbolName: String?
}

struct PhrasePackPhrase: Codable, Equatable {
    var id: String
    var text: String
    var sortOrder: Int
    var style: PhrasePackStyle?
}

struct PhrasePackStyle: Codable, Equatable {
    var backgroundColor: UInt?
    var textColor: UInt?
    var textSizeSp: Float?
    var isBold: Bool
    var borderColor: UInt?
    var borderWidthDp: Float?
    var image: String?
    var media: String?
    var mediaType: String?
    var thumb: String?
    var gameType: String?
    var sendSwitchOutput: Bool? = nil
}

enum PhrasePackError: LocalizedError, Equatable {
    case recentsCannotExport
    case invalidArchive
    case missingManifest
    case unsupportedVersion(Int)
    case zipSlip(String)
    case tooManyEntries
    case uncompressedTooLarge
    case compressionBomb
    case mediaTooLarge
    case missingAsset(String)
    case invalidImage
    case diskFull
    case protectedCategory
    case cancelled
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .recentsCannotExport:
            return "Recently Said cannot be exported as a phrase pack."
        case .invalidArchive:
            return "This does not look like a Switch2GO phrase pack."
        case .missingManifest:
            return "The phrase pack is missing manifest.json."
        case .unsupportedVersion(let version):
            return "This phrase pack uses format version \(version), which this app cannot read."
        case .zipSlip:
            return "The phrase pack contains an unsafe file path and was not imported."
        case .tooManyEntries:
            return "The phrase pack contains too many files."
        case .uncompressedTooLarge:
            return "The phrase pack is too large to unpack on this device."
        case .compressionBomb:
            return "The phrase pack is compressed in an unsafe way and was not imported."
        case .mediaTooLarge:
            return "A media file in the pack is larger than 100 MB."
        case .missingAsset:
            return "The phrase pack is missing a referenced image or media file."
        case .invalidImage:
            return "The phrase pack contains an image that could not be read."
        case .diskFull:
            return "There is not enough storage to import this phrase pack."
        case .protectedCategory:
            return "Built-in boards cannot be changed by a phrase pack."
        case .cancelled:
            return "Import cancelled."
        case .importFailed(let message):
            return message
        }
    }
}

enum PhrasePackNameCollision: Equatable {
    case none
    case custom(id: String, name: String)
    case preset(displayName: String)
}

enum PhrasePackDestination: Equatable {
    case createNew(name: String)
    case merge(categoryId: String)
}

struct PhrasePackPreview: Equatable {
    let fileURL: URL
    let fileSize: Int64
    let manifest: PhrasePackManifest
    let exceedsEmailLimit: Bool
    let videoCount: Int
    let unknownInteractiveCount: Int
}

struct PhrasePackImportResult: Equatable {
    let categoryId: String
    let categoryName: String
    let phraseCount: Int
    let droppedInteractive: Bool
}

enum PhrasePackPath {
    /// Returns a sanitized relative path or throws if the entry is unsafe (zip-slip).
    static func validatedRelativePath(_ rawPath: String) throws -> String {
        var path = rawPath.replacingOccurrences(of: "\\", with: "/")
        if path.hasPrefix("./") {
            path.removeFirst(2)
        }
        while path.hasSuffix("/") {
            path.removeLast()
        }
        if path.isEmpty || path == "." {
            throw PhrasePackError.zipSlip(rawPath)
        }
        if path.hasPrefix("/") || path.hasPrefix("~") || path.contains(":") {
            throw PhrasePackError.zipSlip(rawPath)
        }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if parts.contains("..") || parts.contains("") || parts.contains(".") {
            throw PhrasePackError.zipSlip(rawPath)
        }
        if path.hasPrefix("../") || path.contains("/../") || path.hasSuffix("/..") {
            throw PhrasePackError.zipSlip(rawPath)
        }
        return path
    }

    static func isAllowedPackPath(_ relativePath: String) -> Bool {
        if relativePath == PhrasePackFormat.manifestFileName {
            return true
        }
        let allowedPrefixes = ["assets/images/", "assets/thumbs/", "assets/media/"]
        return allowedPrefixes.contains { relativePath.hasPrefix($0) } && relativePath != "assets/images/"
            && relativePath != "assets/thumbs/" && relativePath != "assets/media/"
    }

    static func destinationURL(extractRoot: URL, relativePath: String) throws -> URL {
        let relative = try validatedRelativePath(relativePath)
        let root = extractRoot.standardizedFileURL
        let dest = root.appendingPathComponent(relative, isDirectory: false).standardizedFileURL
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        if dest.path == root.path || !dest.path.hasPrefix(rootPath) {
            throw PhrasePackError.zipSlip(relativePath)
        }
        return dest
    }

    static func sanitizedExportFileName(_ displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let base = cleaned.isEmpty ? "PhrasePack" : cleaned
        return "\(base).\(PhrasePackFormat.fileExtension)"
    }
}
