import Foundation

/// Stores phrase images under Documents/Images/ and video/audio under Documents/Media/.
/// Persisted refs are relative paths (`Images/….jpg`, `Media/….mp4`).
enum MediaStorage {
    static let maxFileBytes: Int64 = 100 * 1024 * 1024 // 100 MB
    static let imagesFolderName = "Images"
    static let mediaFolderName = "Media"

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private static var imagesDirectory: URL {
        ensureDirectory(named: imagesFolderName)
    }

    private static var mediaDirectory: URL {
        ensureDirectory(named: mediaFolderName)
    }

    private static func ensureDirectory(named name: String) -> URL {
        let dir = documentsDirectory.appendingPathComponent(name, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Relative path stored in phrase style JSON.
    static func relativeRef(folder: String, fileName: String) -> String {
        "\(folder)/\(fileName)"
    }

    // MARK: - Save

    /// Saves a custom tile image; returns a relative ref (`Images/…`).
    static func saveImage(data: Data, preferredExtension: String) -> String? {
        let fileName = "custom_image_\(UUID().uuidString).\(preferredExtension)"
        let dest = imagesDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: dest)
            return relativeRef(folder: imagesFolderName, fileName: fileName)
        } catch {
            DebugLog.error("Failed to save image: \(error.localizedDescription)", tag: "MediaStorage")
            return nil
        }
    }

    /// Saves phrase video/audio from a file URL; returns a relative ref (`Media/…`).
    static func saveMedia(from sourceURL: URL, preferredExtension: String) -> String? {
        let ext = preferredExtension.isEmpty ? sourceURL.pathExtension : preferredExtension
        let fileName = "phrase_media_\(UUID().uuidString).\(ext)"
        let dest = mediaDirectory.appendingPathComponent(fileName)

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
            let size = attrs[.size] as? Int64 ?? 0
            if size > maxFileBytes {
                DebugLog.error("Media file too large: \(size) bytes", tag: "MediaStorage")
                return nil
            }
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            return relativeRef(folder: mediaFolderName, fileName: fileName)
        } catch {
            DebugLog.error("Failed to save media: \(error.localizedDescription)", tag: "MediaStorage")
            return nil
        }
    }

    /// Saves phrase video/audio from data; returns a relative ref (`Media/…`).
    static func saveMedia(data: Data, extension ext: String) -> String? {
        if Int64(data.count) > maxFileBytes {
            DebugLog.error("Media data too large", tag: "MediaStorage")
            return nil
        }
        let fileName = "phrase_media_\(UUID().uuidString).\(ext)"
        let dest = mediaDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: dest)
            return relativeRef(folder: mediaFolderName, fileName: fileName)
        } catch {
            DebugLog.error("Failed to write media: \(error.localizedDescription)", tag: "MediaStorage")
            return nil
        }
    }

    /// Writes backup payload bytes into Images/ or Media/ using the given relative id.
    @discardableResult
    static func writeRelativeFile(relativePath: String, data: Data) -> Bool {
        let url = documentsDirectory.appendingPathComponent(relativePath)
        let parent = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try data.write(to: url)
            return true
        } catch {
            DebugLog.error("Failed to write \(relativePath): \(error.localizedDescription)", tag: "MediaStorage")
            return false
        }
    }

    // MARK: - Resolve / delete

    static func isLocalMediaRef(_ mediaRef: String?) -> Bool {
        guard let mediaRef, !mediaRef.isEmpty else { return false }
        return !mediaRef.hasPrefix("youtube:")
            && !mediaRef.hasPrefix("emoji:")
    }

    static func isRelativeFileRef(_ ref: String) -> Bool {
        ref.hasPrefix("\(imagesFolderName)/") || ref.hasPrefix("\(mediaFolderName)/")
    }

    /// Resolves a stored ref (relative, absolute path, or file://) to a file URL if it exists.
    static func resolveURL(mediaRef: String?) -> URL? {
        guard isLocalMediaRef(mediaRef), let ref = mediaRef, !ref.isEmpty else { return nil }

        if ref.hasPrefix("file://"), let url = URL(string: ref) {
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        if ref.hasPrefix("/") {
            let url = URL(fileURLWithPath: ref)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        // Relative path under Documents
        let url = documentsDirectory.appendingPathComponent(ref)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Alias for image refs (same resolution rules).
    static func resolveImageURL(imageRef: String?) -> URL? {
        resolveURL(mediaRef: imageRef)
    }

    static func deleteMedia(mediaRef: String?) {
        guard isLocalMediaRef(mediaRef) else { return }
        guard let url = resolveURL(mediaRef: mediaRef) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Deletes all files under Documents/Images and Documents/Media.
    static func deleteAllStoredMedia() {
        for folder in [imagesFolderName, mediaFolderName] {
            let dir = documentsDirectory.appendingPathComponent(folder, isDirectory: true)
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }
            if let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for url in contents {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        // Also remove legacy images saved directly under Documents/
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: nil
        ) {
            for url in contents where url.lastPathComponent.hasPrefix("custom_image_") {
                try? FileManager.default.removeItem(at: url)
            }
        }
        DebugLog.info("Cleared Images/ and Media/ folders", tag: "MediaStorage")
    }

    /// Converts an absolute/file URL under Documents into a relative ref, moving into Images/ or Media/ if needed.
    static func relativizeIfNeeded(_ ref: String?) -> String? {
        guard let ref, !ref.isEmpty, isLocalMediaRef(ref) else { return ref }
        if isRelativeFileRef(ref) { return ref }
        if ref.hasPrefix("emoji:") || ref.hasPrefix("youtube:") { return ref }

        guard let url = resolveURL(mediaRef: ref) else { return ref }
        let docsPath = documentsDirectory.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(docsPath) else { return ref }

        let relative = String(filePath.dropFirst(docsPath.count).drop(while: { $0 == "/" }))
        if isRelativeFileRef(relative) {
            return relative
        }

        // Legacy file sitting directly in Documents/ — move into Images/ or Media/
        let isImage = ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(url.pathExtension.lowercased())
        let folder = isImage ? imagesFolderName : mediaFolderName
        let destDir = ensureDirectory(named: folder)
        let dest = destDir.appendingPathComponent(url.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: url, to: dest)
            return relativeRef(folder: folder, fileName: dest.lastPathComponent)
        } catch {
            DebugLog.warn("Could not relocate \(url.lastPathComponent): \(error)", tag: "MediaStorage")
            return relative.isEmpty ? ref : relative
        }
    }

    /// Lists relative paths of all files currently under Images/ and Media/.
    static func listStoredRelativePaths() -> [String] {
        var paths: [String] = []
        for folder in [imagesFolderName, mediaFolderName] {
            let dir = documentsDirectory.appendingPathComponent(folder, isDirectory: true)
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil
            ) else { continue }
            for url in contents where !url.hasDirectoryPath {
                paths.append(relativeRef(folder: folder, fileName: url.lastPathComponent))
            }
        }
        return paths
    }

    static func mimeType(forRelativePath path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "m4a": return "audio/mp4"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        default: return "application/octet-stream"
        }
    }
}
