import SwiftUI

/// View for searching and selecting images from Wikimedia Commons,
/// with optional background removal.
struct WikimediaSearchView: View {
    let onImageSelected: (String?) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @State private var results: [WikimediaImageResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var selectedResult: WikimediaImageResult?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if isSearching {
                    Spacer()
                    ProgressView("Searching Wikimedia Commons...")
                        .padding()
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else if results.isEmpty && !searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No images found for \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                } else if results.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 50))
                            .foregroundColor(.blue.opacity(0.5))
                        Text("Search for free images on Wikimedia Commons")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    resultsGrid
                }
            }
            .navigationTitle("Wikimedia Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { onCancel() }
                }
            }
            .sheet(item: $selectedResult) { result in
                WikimediaImageDetailView(
                    result: result,
                    onUseImage: { imageURL in
                        onImageSelected(imageURL)
                    },
                    onCancel: { selectedResult = nil }
                )
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search images...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onSubmit { performSearch() }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    results = []
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding()
    }

    // MARK: - Results Grid

    private var resultsGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(results) { result in
                    WikimediaResultCell(result: result)
                        .onTapGesture {
                            selectedResult = result
                        }
                }
            }
            .padding()
        }
    }

    // MARK: - Search

    private func performSearch() {
        searchTask?.cancel()
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSearching = true
        errorMessage = nil
        results = []

        searchTask = Task {
            do {
                let searchResults = try await WikimediaSearchService.shared.searchImages(query: searchText)
                if !Task.isCancelled {
                    await MainActor.run {
                        results = searchResults
                        isSearching = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isSearching = false
                    }
                }
            }
        }
    }
}

// MARK: - Result Cell

private struct WikimediaResultCell: View {
    let result: WikimediaImageResult

    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: result.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                case .failure:
                    placeholder(icon: "photo.badge.exclamationmark")
                case .empty:
                    ProgressView()
                        .frame(height: 120)
                @unknown default:
                    placeholder(icon: "photo")
                }
            }
            .frame(height: 120)
            .cornerRadius(8)

            Text(result.title)
                .font(.caption2)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(result.license)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.7))
                .cornerRadius(4)
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func placeholder(icon: String) -> some View {
        ZStack {
            Color(UIColor.tertiarySystemBackground)
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.secondary)
        }
        .frame(height: 120)
    }
}

// MARK: - Image Detail View

struct WikimediaImageDetailView: View {
    let result: WikimediaImageResult
    let onUseImage: (String) -> Void
    let onCancel: () -> Void

    @State private var removeBackground = false
    @State private var isProcessing = false
    @State private var processedImage: UIImage?
    @State private var originalImage: UIImage?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    imagePreview

                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.title)
                            .font(.headline)

                        if !result.description.isEmpty {
                            Text(result.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("License: \(result.license)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    Divider()

                    Toggle(isOn: $removeBackground) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.rectangle")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Remove Background")
                                    .font(.headline)
                                Text("Isolate the main subject with a transparent background")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .onChange(of: removeBackground) { _, shouldRemove in
                        if shouldRemove && processedImage == nil {
                            processBackgroundRemoval()
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    Button {
                        saveAndReturn()
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isProcessing ? "Processing..." : "Use This Image")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isProcessing ? Color.gray : Color.blue)
                        .cornerRadius(14)
                    }
                    .disabled(isProcessing || originalImage == nil)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Image Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { onCancel() }
                }
            }
            .task {
                await loadFullImage()
            }
        }
    }

    private var imagePreview: some View {
        Group {
            if isProcessing {
                ZStack {
                    Color(UIColor.secondarySystemBackground)
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Removing background...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 250)
                .cornerRadius(12)
            } else if removeBackground, let processed = processedImage {
                Image(uiImage: processed)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 250)
                    .background(
                        CheckerboardView()
                            .cornerRadius(12)
                    )
                    .cornerRadius(12)
            } else if let original = originalImage {
                Image(uiImage: original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 250)
                    .cornerRadius(12)
            } else {
                AsyncImage(url: result.thumbnailURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 250)
                    } else {
                        ProgressView("Loading image...")
                            .frame(height: 250)
                    }
                }
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    private func loadFullImage() async {
        guard let url = result.fullImageURL else { return }
        do {
            let image = try await WikimediaSearchService.shared.downloadImage(from: url)
            await MainActor.run {
                originalImage = image
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load full image: \(error.localizedDescription)"
            }
        }
    }

    private func processBackgroundRemoval() {
        guard let original = originalImage else { return }
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let result = try await BackgroundRemovalService.shared.removeBackground(from: original)
                await MainActor.run {
                    processedImage = result
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    removeBackground = false
                    isProcessing = false
                }
            }
        }
    }

    private func saveAndReturn() {
        let imageToSave = (removeBackground && processedImage != nil) ? processedImage! : originalImage
        guard let image = imageToSave else { return }

        isProcessing = true

        Task {
            let fileURL = await saveImageToDocuments(image: image, transparent: removeBackground)
            await MainActor.run {
                isProcessing = false
                if let url = fileURL {
                    onUseImage(url.absoluteString)
                } else {
                    errorMessage = "Failed to save image."
                }
            }
        }
    }

    private func saveImageToDocuments(image: UIImage, transparent: Bool) async -> URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "wikimedia_\(UUID().uuidString).\(transparent ? "png" : "jpg")"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)

        print("WikimediaSearchView: Saving image to: \(fileURL.path)")
        print("WikimediaSearchView: Image size: \(image.size)")
        
        let data: Data?
        if transparent {
            data = image.pngData()
            print("WikimediaSearchView: Created PNG data")
        } else {
            data = image.jpegData(compressionQuality: 0.85)
            print("WikimediaSearchView: Created JPEG data")
        }

        guard let imageData = data else {
            print("WikimediaSearchView: Failed to convert image to data")
            return nil
        }
        
        print("WikimediaSearchView: Image data size: \(imageData.count) bytes")

        do {
            try imageData.write(to: fileURL)
            
            // Verify the file was written
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("WikimediaSearchView: File saved successfully, size: \(fileSize) bytes")
                
                // Verify we can read it back
                if let testData = try? Data(contentsOf: fileURL),
                   let _ = UIImage(data: testData) {
                    print("WikimediaSearchView: Verified image can be read back")
                } else {
                    print("WikimediaSearchView: Warning - saved file cannot be read back as image")
                }
            } else {
                print("WikimediaSearchView: Warning - file does not exist after write")
            }
            
            return fileURL
        } catch {
            print("WikimediaSearchView: Error saving image: \(error.localizedDescription)")
            return nil
        }
    }
}

/// Checkerboard pattern to indicate transparency.
struct CheckerboardView: View {
    var body: some View {
        Canvas { context, size in
            let tileSize: CGFloat = 12
            let rows = Int(ceil(size.height / tileSize))
            let cols = Int(ceil(size.width / tileSize))

            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? Color.white : Color.gray.opacity(0.3))
                    )
                }
            }
        }
    }
}

#Preview {
    WikimediaSearchView(
        onImageSelected: { _ in },
        onCancel: {}
    )
}
