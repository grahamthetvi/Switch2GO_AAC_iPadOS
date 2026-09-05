import SwiftUI
import UniformTypeIdentifiers
import VocableShared

/// Picker for phrase video or audio attachment (mutually exclusive per phrase).
struct MediaPickerView: View {
    let mediaType: String
    let currentMediaRef: String?
    let onMediaSelected: (String?, String?) -> Void
    let onCancel: () -> Void

    @State private var showingDocumentPicker = false
    @State private var pickerError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let pickerError {
                        Text(pickerError)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    Button {
                        onMediaSelected(nil, nil)
                    } label: {
                        optionRow(title: "Remove media", icon: "slash.circle", color: .gray)
                    }

                    Button {
                        showingDocumentPicker = true
                    } label: {
                        optionRow(
                            title: mediaType == PhraseStyle.companion.MEDIA_TYPE_VIDEO ? "Choose video file" : "Choose audio file",
                            icon: mediaType == PhraseStyle.companion.MEDIA_TYPE_VIDEO ? "film" : "waveform",
                            color: .blue
                        )
                    }
                }
                .padding()
            }
            .navigationTitle(mediaType == PhraseStyle.companion.MEDIA_TYPE_VIDEO ? "Attach Video" : "Attach Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel", action: onCancel)
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerRepresentable(
                    contentTypes: allowedTypes,
                    onPick: handlePickedURL,
                    onCancel: { showingDocumentPicker = false }
                )
            }
        }
    }

    private var allowedTypes: [UTType] {
        if mediaType == PhraseStyle.companion.MEDIA_TYPE_VIDEO {
            return [.mpeg4Movie, .quickTimeMovie, .movie, .video]
        }
        return [.mpeg4Audio, .mp3, .wav, .audio]
    }

    private func handlePickedURL(_ url: URL?) {
        showingDocumentPicker = false
        guard let url else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.isEmpty ? (mediaType == PhraseStyle.companion.MEDIA_TYPE_VIDEO ? "mp4" : "m4a") : url.pathExtension
        guard let relativeRef = MediaStorage.saveMedia(from: url, preferredExtension: ext) else {
            pickerError = "Could not save file (max 100 MB)."
            return
        }
        onMediaSelected(relativeRef, mediaType)
    }

    private func optionRow(title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
            Text(title)
                .font(.headline)
            Spacer()
            if title == "Remove media" && currentMediaRef == nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct DocumentPickerRepresentable: UIViewControllerRepresentable {
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
