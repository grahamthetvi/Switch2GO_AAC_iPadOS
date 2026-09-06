import Foundation
import ZIPFoundation

enum PhrasePackArchive {
    static func create(fromStagingDirectory stagingURL: URL, to destinationURL: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }
        try fm.zipItem(at: stagingURL, to: destinationURL, shouldKeepParent: false)
    }

    static func extract(packURL: URL, to extractRoot: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: extractRoot, withIntermediateDirectories: true)

        guard let archive = Archive(url: packURL, accessMode: .read) else {
            throw PhrasePackError.invalidArchive
        }

        var entryCount = 0
        var uncompressedTotal: Int64 = 0

        for entry in archive {
            if entry.type == .symlink {
                throw PhrasePackError.zipSlip(entry.path)
            }
            if entry.type == .directory {
                let relative = try PhrasePackPath.validatedRelativePath(entry.path)
                _ = try PhrasePackPath.destinationURL(extractRoot: extractRoot, relativePath: relative)
                continue
            }

            entryCount += 1
            if entryCount > PhrasePackFormat.maxZipEntries {
                throw PhrasePackError.tooManyEntries
            }

            let uncompressed = Int64(entry.uncompressedSize)
            let compressed = Int64(entry.compressedSize)
            uncompressedTotal += uncompressed
            if uncompressedTotal > PhrasePackFormat.maxUncompressedBytes {
                throw PhrasePackError.uncompressedTooLarge
            }
            if uncompressed > 1_000_000 && compressed > 0 {
                if uncompressed / compressed > PhrasePackFormat.maxCompressionRatio {
                    throw PhrasePackError.compressionBomb
                }
            }

            let relative = try PhrasePackPath.validatedRelativePath(entry.path)
            if !PhrasePackPath.isAllowedPackPath(relative) {
                continue
            }
            if uncompressed > PhrasePackFormat.maxMediaBytes && relative.hasPrefix("assets/media/") {
                throw PhrasePackError.mediaTooLarge
            }

            let dest = try PhrasePackPath.destinationURL(extractRoot: extractRoot, relativePath: relative)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            _ = try archive.extract(entry, to: dest)
        }
    }

    static func loadManifest(fromExtractRoot extractRoot: URL) throws -> PhrasePackManifest {
        let manifestURL = extractRoot.appendingPathComponent(PhrasePackFormat.manifestFileName)
        guard fmExists(manifestURL) else {
            throw PhrasePackError.missingManifest
        }
        let data = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(PhrasePackManifest.self, from: data)
        if manifest.formatVersion > PhrasePackFormat.currentVersion {
            throw PhrasePackError.unsupportedVersion(manifest.formatVersion)
        }
        return manifest
    }

    private static func fmExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}
