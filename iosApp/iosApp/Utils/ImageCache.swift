import SwiftUI
import UIKit
import VocableShared

/// Image caching for better performance
class ImageCache {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB

        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clear()
        }
    }
    
    /// Get cached image
    func get(key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    /// Set cached image
    func set(key: String, image: UIImage) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    /// Clear cache
    func clear() {
        cache.removeAllObjects()
    }
    
    /// Load image with caching
    func loadImage(named name: String) -> UIImage? {
        // Check cache first
        if let cached = get(key: name) {
            return cached
        }
        
        // Load from bundle
        if let image = UIImage(named: name) {
            set(key: name, image: image)
            return image
        }
        
        return nil
    }
    
    /// Load image from file URL with caching
    func loadImage(from url: URL) -> UIImage? {
        let key = url.absoluteString
        
        // Check cache
        if let cached = get(key: key) {
            return cached
        }
        
        // Validate the URL is a file URL and the file exists
        guard url.isFileURL else {
            DebugLog.error("URL is not a file URL: \(url)", tag: "ImageCache")
            return nil
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            DebugLog.warn("File does not exist at path: \(url.path)", tag: "ImageCache")
            return nil
        }
        
        // Load from file with error handling
        do {
            let data = try Data(contentsOf: url)
            guard let image = UIImage(data: data) else {
                DebugLog.error("Failed to create UIImage from data at: \(url.path)", tag: "ImageCache")
                // Check file size and format
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                DebugLog.debug("File size: \(fileSize) bytes", tag: "ImageCache")
                return nil
            }
            set(key: key, image: image)
            return image
        } catch {
            DebugLog.error("Error loading image from \(url.path): \(error.localizedDescription)", tag: "ImageCache")
            return nil
        }
    }
}

/// Cached async image view
struct CachedAsyncImage: View {
    let imageRef: String?
    let renderSize: CGFloat?
    
    @State private var loadedImage: UIImage?
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: imageRef) { _, _ in
            loadImage()
        }
        .onChange(of: renderSize ?? 0) { _, _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let ref = imageRef, !ref.isEmpty else {
            DebugLog.debug("No image reference provided", tag: "CachedAsyncImage")
            return
        }
        
        // Check if it's an emoji
        if let emoji = PhraseStyle.extractEmoji(ref: ref) {
            // Render emoji as image
            loadedImage = renderEmoji(emoji)
            return
        }
        
        // Check if it's a file URL
        if ref.hasPrefix("file://") {
            // Try to create URL from string
            if let url = URL(string: ref) {
                DebugLog.debug("Loading file URL: \(url.path)", tag: "CachedAsyncImage")
                loadedImage = ImageCache.shared.loadImage(from: url)
                if loadedImage == nil {
                    DebugLog.error("Failed to load image from file URL", tag: "CachedAsyncImage")
                }
            } else {
                DebugLog.error("Invalid file URL string: \(ref)", tag: "CachedAsyncImage")
            }
            return
        }
        
        // Check for absolute path without file:// prefix
        if ref.hasPrefix("/") {
            let url = URL(fileURLWithPath: ref)
            DebugLog.debug("Loading absolute path: \(ref)", tag: "CachedAsyncImage")
            loadedImage = ImageCache.shared.loadImage(from: url)
            if loadedImage == nil {
                DebugLog.error("Failed to load image from absolute path", tag: "CachedAsyncImage")
            }
            return
        }
        
        // Load as named resource
        DebugLog.debug("Loading named resource: \(ref)", tag: "CachedAsyncImage")
        loadedImage = ImageCache.shared.loadImage(named: ref)
        if loadedImage == nil {
            DebugLog.error("Failed to load named resource", tag: "CachedAsyncImage")
        }
    }
    
    private func renderEmoji(_ emoji: String) -> UIImage? {
        let side = max(60, min(renderSize ?? 100, 256))
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: side * 0.8),
                .paragraphStyle: paragraphStyle
            ]
            
            let rect = CGRect(origin: .zero, size: size)
            emoji.draw(in: rect, withAttributes: attributes)
        }
    }
}
