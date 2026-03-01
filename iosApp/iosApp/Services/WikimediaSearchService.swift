import Foundation
import UIKit

/// Result model for a Wikimedia Commons image search result.
struct WikimediaImageResult: Identifiable, Equatable {
    let id: String
    let title: String
    let thumbnailURL: URL?
    let fullImageURL: URL?
    let license: String
    let description: String

    static func == (lhs: WikimediaImageResult, rhs: WikimediaImageResult) -> Bool {
        lhs.id == rhs.id
    }
}

/// Service for searching and downloading images from Wikimedia Commons.
class WikimediaSearchService {
    static let shared = WikimediaSearchService()

    private let session: URLSession
    private let baseURL = "https://commons.wikimedia.org/w/api.php"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    /// Search Wikimedia Commons for images matching a query.
    func searchImages(query: String, limit: Int = 20) async throws -> [WikimediaImageResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srsearch", value: query),
            URLQueryItem(name: "srnamespace", value: "6"),
            URLQueryItem(name: "srlimit", value: "\(limit)"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "origin", value: "*")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Switch2GO AAC App/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)

        let searchResponse = try JSONDecoder().decode(WikimediaSearchResponse.self, from: data)
        let titles = searchResponse.query.search.map { $0.title }

        guard !titles.isEmpty else { return [] }

        return try await fetchImageInfo(titles: titles)
    }

    /// Fetch image info (URLs, license) for a list of file titles.
    private func fetchImageInfo(titles: [String]) async throws -> [WikimediaImageResult] {
        let joinedTitles = titles.joined(separator: "|")

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "titles", value: joinedTitles),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url|extmetadata|mime"),
            URLQueryItem(name: "iiurlwidth", value: "300"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "origin", value: "*")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Switch2GO AAC App/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)

        let infoResponse = try JSONDecoder().decode(WikimediaImageInfoResponse.self, from: data)

        var results: [WikimediaImageResult] = []
        for (pageId, page) in infoResponse.query.pages {
            guard let imageInfo = page.imageinfo?.first else { continue }

            let mime = imageInfo.mime ?? ""
            guard mime.hasPrefix("image/") else { continue }

            let license = imageInfo.extmetadata?["LicenseShortName"]?.value ?? "Unknown"
            let description = imageInfo.extmetadata?["ImageDescription"]?.value ?? ""
            let cleanDescription = description.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

            let thumbURL = imageInfo.thumburl.flatMap { URL(string: $0) }
            let fullURL = imageInfo.url.flatMap { URL(string: $0) }

            let displayTitle = page.title
                .replacingOccurrences(of: "File:", with: "")
                .replacingOccurrences(of: "_", with: " ")

            results.append(WikimediaImageResult(
                id: pageId,
                title: displayTitle,
                thumbnailURL: thumbURL,
                fullImageURL: fullURL,
                license: license,
                description: String(cleanDescription.prefix(200))
            ))
        }

        return results
    }

    /// Download a full-resolution image from a URL.
    func downloadImage(from url: URL) async throws -> UIImage {
        var request = URLRequest(url: url)
        request.setValue("Switch2GO AAC App/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        
        // Validate response
        if let httpResponse = response as? HTTPURLResponse {
            print("WikimediaSearchService: HTTP Status: \(httpResponse.statusCode)")
            guard (200...299).contains(httpResponse.statusCode) else {
                throw WikimediaError.searchFailed("HTTP \(httpResponse.statusCode)")
            }
        }
        
        // Validate data size
        print("WikimediaSearchService: Downloaded \(data.count) bytes")
        guard data.count > 0 else {
            throw WikimediaError.invalidImageData
        }
        
        // Try to create UIImage
        guard let image = UIImage(data: data) else {
            print("WikimediaSearchService: Failed to create UIImage from \(data.count) bytes")
            throw WikimediaError.invalidImageData
        }
        
        print("WikimediaSearchService: Successfully created UIImage with size \(image.size)")
        return image
    }
}

// MARK: - Error

enum WikimediaError: LocalizedError {
    case invalidImageData
    case searchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Could not decode the downloaded image."
        case .searchFailed(let reason):
            return "Search failed: \(reason)"
        }
    }
}

// MARK: - API Response Models

private struct WikimediaSearchResponse: Decodable {
    let query: SearchQuery

    struct SearchQuery: Decodable {
        let search: [SearchResult]
    }

    struct SearchResult: Decodable {
        let title: String
    }
}

private struct WikimediaImageInfoResponse: Decodable {
    let query: ImageInfoQuery

    struct ImageInfoQuery: Decodable {
        let pages: [String: Page]
    }

    struct Page: Decodable {
        let title: String
        let imageinfo: [ImageInfo]?
    }

    struct ImageInfo: Decodable {
        let url: String?
        let thumburl: String?
        let mime: String?
        let extmetadata: [String: ExtMetadataValue]?
    }

    struct ExtMetadataValue: Decodable {
        let value: String
    }
}
