import Foundation

/// Stores phrase video/audio files under Documents/Media/.
enum MediaStorage {
    static let maxFileBytes: Int64 = 100 * 1024 * 1024 // 100 MB

    private static var mediaDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = documents.appendingPathComponent("Media", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func saveMedia(from sourceURL: URL, preferredExtension: String) -> URL? {
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
            return dest
        } catch {
            DebugLog.error("Failed to save media: \(error.localizedDescription)", tag: "MediaStorage")
            return nil
        }
    }

    static func saveMedia(data: Data, extension ext: String) -> URL? {
        if Int64(data.count) > maxFileBytes {
            DebugLog.error("Media data too large", tag: "MediaStorage")
            return nil
        }
        let fileName = "phrase_media_\(UUID().uuidString).\(ext)"
        let dest = mediaDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: dest)
            return dest
        } catch {
            DebugLog.error("Failed to write media: \(error.localizedDescription)", tag: "MediaStorage")
            return nil
        }
    }

    static func isLocalMediaRef(_ mediaRef: String?) -> Bool {
        guard let mediaRef, !mediaRef.isEmpty else { return false }
        return !mediaRef.hasPrefix("youtube:")
    }

    static func resolveURL(mediaRef: String?) -> URL? {
        guard isLocalMediaRef(mediaRef) else { return nil }
        guard let ref = mediaRef, !ref.isEmpty else { return nil }

        let candidateURL: URL?
        if ref.hasPrefix("file://") {
            candidateURL = URL(string: ref)
        } else if ref.hasPrefix("/") {
            candidateURL = URL(fileURLWithPath: ref)
        } else {
            candidateURL = mediaDirectory.appendingPathComponent(ref)
        }

        if let url = candidateURL {
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            let fileName = url.lastPathComponent
            if !fileName.isEmpty {
                let mediaFallback = mediaDirectory.appendingPathComponent(fileName)
                if FileManager.default.fileExists(atPath: mediaFallback.path) {
                    return mediaFallback
                }
                if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let docsFallback = documents.appendingPathComponent(fileName)
                    if FileManager.default.fileExists(atPath: docsFallback.path) {
                        return docsFallback
                    }
                }
            }
        }
        return nil
    }

    static func deleteMedia(mediaRef: String?) {
        guard isLocalMediaRef(mediaRef) else { return }
        guard let url = resolveURL(mediaRef: mediaRef) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
