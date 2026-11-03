import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Choose an existing library file for a phrase, or add one of the same kind.
struct MediaLibraryPickerView: View {
    let kind: MediaLibraryKind
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    @StateObject private var model = MediaLibraryModel()
    @State private var errorMessage: String?

    private var items: [MediaLibraryItem] {
        model.items.filter { $0.kind == kind }
    }

    var body: some View {
        NavigationStack {
            List {
                if model.isLoading && model.items.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if items.isEmpty {
                    Text(emptyMessage)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(items) { item in
                        Button {
                            onSelect(item.relativePath)
                        } label: {
                            MediaLibraryRow(item: item)
                        }
                        .accessibilityLabel("\(itemTitle(item)), \(usageSummary(item))")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    MediaLibraryAddControl(kinds: [kind]) {
                        model.reload()
                    } onError: { message in
                        errorMessage = message
                    }
                }
            }
            .alert(L("Could not add file"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(L("OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear { model.reload() }
        }
    }

    private var title: String {
        switch kind {
        case .picture:
            return L("Picture Library")
        case .video:
            return L("Video Library")
        case .audio:
            return L("Audio Library")
        }
    }

    private var emptyMessage: String {
        switch kind {
        case .picture:
            return L("No pictures yet. Add one, or attach a photo to any phrase.")
        case .video:
            return L("No videos yet. Add one, or attach a video to any phrase.")
        case .audio:
            return L("No audio yet. Add one, or attach audio to any phrase.")
        }
    }
}

struct MediaLibraryAddControl: View {
    let kinds: [MediaLibraryKind]
    let onImported: () -> Void
    let onError: (String) -> Void

    @State private var showingPhotos = false
    @State private var photoItem: PhotosPickerItem?
    @State private var documentKind: MediaLibraryKind?
    @State private var showingDocument = false

    var body: some View {
        Group {
            if kinds.count == 1, let kind = kinds.first {
                Button(addTitle(kind)) {
                    beginAdd(kind)
                }
            } else {
                Menu {
                    ForEach(kinds) { kind in
                        Button {
                            beginAdd(kind)
                        } label: {
                            Label(addTitle(kind), systemImage: kindSymbol(kind))
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L("Add to Library"))
            }
        }
        .photosPicker(isPresented: $showingPhotos, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                defer { photoItem = nil }
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self) else {
                        throw MediaLibraryImportError.invalidImage
                    }
                    _ = try await Task.detached(priority: .userInitiated) { () throws -> String in
                        try MediaLibraryStore.importPicture(data: data)
                    }.value
                    onImported()
                } catch {
                    onError((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                }
            }
        }
        .sheet(isPresented: $showingDocument, onDismiss: { documentKind = nil }) {
            if let documentKind {
                MediaDocumentPicker(
                    contentTypes: contentTypes(for: documentKind),
                    onPick: { url in
                        showingDocument = false
                        guard let url else { return }
                        importDocument(url, kind: documentKind)
                    },
                    onCancel: { showingDocument = false }
                )
            }
        }
    }

    private func beginAdd(_ kind: MediaLibraryKind) {
        switch kind {
        case .picture:
            showingPhotos = true
        case .video, .audio:
            documentKind = kind
            showingDocument = true
        }
    }

    private func addTitle(_ kind: MediaLibraryKind) -> String {
        switch kind {
        case .picture:
            return L("Add Picture")
        case .video:
            return L("Add Video")
        case .audio:
            return L("Add Audio")
        }
    }

    private func contentTypes(for kind: MediaLibraryKind) -> [UTType] {
        switch kind {
        case .picture:
            return [.image]
        case .video:
            return [.mpeg4Movie, .quickTimeMovie, .movie, .video]
        case .audio:
            return [.mpeg4Audio, .mp3, .wav, .audio]
        }
    }

    private func importDocument(_ url: URL, kind: MediaLibraryKind) {
        Task {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                _ = try await MediaLibraryStore.importFile(from: url, kind: kind)
                onImported()
            } catch {
                onError((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }
}

struct MediaDocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: (URL?) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL?) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
