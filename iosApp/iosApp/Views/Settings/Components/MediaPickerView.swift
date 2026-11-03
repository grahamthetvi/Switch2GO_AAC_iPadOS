import SwiftUI
import UniformTypeIdentifiers
import VocableShared

/// Picker for phrase video or audio attachment (mutually exclusive per phrase).
struct MediaPickerView: View {
    let mediaType: String
    let currentMediaRef: String?
    var currentImageRef: String? = nil
    let onMediaSelected: (String?, String?, String?) -> Void
    let onCancel: () -> Void

    @State private var showingDocumentPicker = false
    @State private var showingLibrary = false
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
                        onMediaSelected(nil, nil, nil)
                    } label: {
                        optionRow(title: "Remove media", icon: "slash.circle", color: .gray)
                    }

                    Button {
                        showingLibrary = true
                    } label: {
                        optionRow(
                            title: "Choose from Library",
                            icon: "rectangle.stack",
                            color: .purple
                        )
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

                    Text("Taking media off this phrase leaves the file in Media Library, where you can save it or use it on another phrase.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    if mediaType == PhraseStyle.companion.MEDIA_TYPE_VIDEO {
                        Text("Videos must be 20 seconds or shorter. Longer files are not attached.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
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
                MediaDocumentPicker(
                    contentTypes: allowedTypes,
                    onPick: handlePickedURL,
                    onCancel: { showingDocumentPicker = false }
                )
            }
            .sheet(isPresented: $showingLibrary) {
                MediaLibraryPickerView(
                    kind: mediaType == PhraseStyle.companion.MEDIA_TYPE_VIDEO ? .video : .audio,
                    onSelect: { relativeRef in
                        showingLibrary = false
                        deliverSavedMedia(relativeRef)
                    },
                    onCancel: { showingLibrary = false }
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
        Task {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            if mediaType == PhraseStyle.companion.MEDIA_TYPE_VIDEO {
                do {
                    let seconds = try await VideoDurationLimiter.durationSeconds(url: url)
                    if !VideoDurationLimiter.isWithinLimit(seconds) {
                        await MainActor.run {
                            pickerError = "Videos must be 20 seconds or shorter. This video is \(Int(seconds.rounded())) seconds."
                        }
                        return
                    }
                } catch {
                    await MainActor.run {
                        pickerError = "Could not read this video."
                    }
                    return
                }
            }

            let ext = url.pathExtension.isEmpty
                ? (mediaType == PhraseStyle.companion.MEDIA_TYPE_VIDEO ? "mp4" : "m4a")
                : url.pathExtension
            guard let relativeRef = MediaStorage.saveMedia(from: url, preferredExtension: ext) else {
                await MainActor.run {
                    pickerError = "Could not save file (max 100 MB)."
                }
                return
            }
            deliverSavedMedia(relativeRef)
        }
    }

    private func deliverSavedMedia(_ relativeRef: String) {
        Task {
            var posterRef: String?
            let imageMissing = currentImageRef == nil || currentImageRef?.isEmpty == true
            let needsPoster = mediaType == PhraseStyle.companion.MEDIA_TYPE_VIDEO
                && (imageMissing || MediaStorage.isVideoPosterRef(currentImageRef))
            if needsPoster, let videoURL = MediaStorage.resolveURL(mediaRef: relativeRef),
               let posterData = VideoPosterGenerator.jpegPoster(from: videoURL) {
                posterRef = MediaStorage.savePosterImage(data: posterData)
            }

            await MainActor.run {
                onMediaSelected(relativeRef, mediaType, posterRef)
            }
        }
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

