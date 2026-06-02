import SwiftUI
import VocableShared

/// Attach a YouTube video URL or ID to a phrase (mutually exclusive with file video/audio).
struct YouTubePickerView: View {
    let currentMediaRef: String?
    let onMediaSelected: (String?, String?) -> Void
    let onCancel: () -> Void

    @State private var input = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Paste a YouTube link or 11-character video ID. Playback uses the same fullscreen gaze controls as uploaded video.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let currentMediaRef, !currentMediaRef.isEmpty {
                        Text("Current: \(currentMediaRef)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    TextField("YouTube URL or video ID", text: $input)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button("Attach YouTube video") {
                        attachYouTube()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Remove YouTube video") {
                        onMediaSelected(nil, nil)
                    }
                    .foregroundColor(.red)
                }
                .padding()
            }
            .navigationTitle("Attach YouTube")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    private func attachYouTube() {
        errorMessage = nil
        guard let normalized = PhraseStyle.companion.normalizeYouTubeMediaRef(input: input) else {
            errorMessage = "Paste a valid YouTube link or 11-character video ID."
            return
        }
        onMediaSelected(normalized, PhraseStyle.companion.MEDIA_TYPE_YOUTUBE)
    }
}
