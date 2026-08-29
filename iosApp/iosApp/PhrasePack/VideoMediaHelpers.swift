import AVFoundation
import UIKit

enum VideoDurationLimiter {
    static let maxSeconds = PhrasePackFormat.maxVideoDurationSeconds

    static func isWithinLimit(_ seconds: Double) -> Bool {
        seconds.isFinite && seconds >= 0 && seconds <= maxSeconds + 0.05
    }

    static func durationSeconds(url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite else {
            throw PhrasePackError.importFailed("Could not read video duration.")
        }
        return seconds
    }

    static func durationSecondsSync(url: URL) -> Double? {
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        return seconds.isFinite ? seconds : nil
    }
}

enum PhraseImageStore {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func saveJPEG(_ data: Data) -> URL? {
        guard UIImage(data: data) != nil else { return nil }
        let dest = documentsDirectory.appendingPathComponent("custom_image_\(UUID().uuidString).jpg")
        do {
            try data.write(to: dest, options: .atomic)
            return dest
        } catch {
            DebugLog.error("Failed to save JPEG: \(error.localizedDescription)", tag: "PhraseImageStore")
            return nil
        }
    }

    static func savePNG(_ data: Data) -> URL? {
        guard UIImage(data: data) != nil else { return nil }
        let dest = documentsDirectory.appendingPathComponent("custom_image_\(UUID().uuidString).png")
        do {
            try data.write(to: dest, options: .atomic)
            return dest
        } catch {
            DebugLog.error("Failed to save PNG: \(error.localizedDescription)", tag: "PhraseImageStore")
            return nil
        }
    }

    static func saveNormalizedImage(from source: URL) -> URL? {
        guard let data = try? Data(contentsOf: source), let image = UIImage(data: data) else {
            return nil
        }
        if let jpeg = image.jpegData(compressionQuality: 0.85) {
            return saveJPEG(jpeg)
        }
        return nil
    }

    static func resolveLocalFile(_ ref: String?) -> URL? {
        guard let ref, !ref.isEmpty, !ref.hasPrefix("emoji:"), !ref.hasPrefix("youtube:") else {
            return nil
        }
        if ref.hasPrefix("file://"), let url = URL(string: ref) {
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        if ref.hasPrefix("/") {
            let url = URL(fileURLWithPath: ref)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        return nil
    }
}

enum VideoPosterGenerator {
    static func jpegPoster(from videoURL: URL, maxDimension: CGFloat = 320) -> Data? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            return image.jpegData(compressionQuality: 0.7)
        } catch {
            DebugLog.error("Poster generation failed: \(error.localizedDescription)", tag: "VideoPoster")
            return nil
        }
    }

    static func savePosterImage(from videoURL: URL) -> URL? {
        guard let data = jpegPoster(from: videoURL) else { return nil }
        return PhraseImageStore.saveJPEG(data)
    }
}
