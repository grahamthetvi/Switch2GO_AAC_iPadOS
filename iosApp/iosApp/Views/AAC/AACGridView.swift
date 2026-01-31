import SwiftUI
import AVFoundation

/// Main AAC phrase grid view with dwell selection support.
struct AACGridView: View {
    @EnvironmentObject var gazeManager: GazeTrackingManager
    @State private var selectedPhrase: String = ""
    @State private var hoveredButtonId: String?
    @State private var dwellProgress: Double = 0

    // Dwell selection timing
    private let dwellDuration: TimeInterval = 1.0 // seconds to select

    // Sample phrases - in production, load from storage
    let phrases = [
        "Hello", "Goodbye", "Thank you", "Please",
        "Yes", "No", "Help me", "I need",
        "I want", "I feel", "More", "Stop"
    ]

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Output bar showing selected phrase
            OutputBarView(text: selectedPhrase) {
                speakPhrase(selectedPhrase)
            }

            // Phrase grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(phrases, id: \.self) { phrase in
                        PhraseButtonView(
                            phrase: phrase,
                            isHovered: hoveredButtonId == phrase,
                            dwellProgress: hoveredButtonId == phrase ? dwellProgress : 0
                        ) {
                            selectPhrase(phrase)
                        }
                        .id(phrase)
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private func selectPhrase(_ phrase: String) {
        selectedPhrase = phrase
        speakPhrase(phrase)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func speakPhrase(_ phrase: String) {
        guard !phrase.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: phrase)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}

/// Output bar showing the currently selected/composed phrase.
struct OutputBarView: View {
    let text: String
    let onSpeak: () -> Void

    var body: some View {
        HStack {
            Text(text.isEmpty ? "Tap or look at a phrase" : text)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(text.isEmpty ? .secondary : .primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !text.isEmpty {
                Button(action: onSpeak) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Speak phrase")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
}

/// Individual phrase button with dwell progress indicator.
struct PhraseButtonView: View {
    let phrase: String
    let isHovered: Bool
    let dwellProgress: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                // Dwell progress ring
                if isHovered && dwellProgress > 0 {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.blue, lineWidth: 4)
                        .opacity(dwellProgress)
                }

                // Phrase text
                Text(phrase)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .frame(height: 100)
        .accessibilityLabel(phrase)
        .accessibilityHint("Double tap to speak")
    }

    private var backgroundColor: Color {
        if isHovered {
            return Color.blue.opacity(0.2)
        }
        return Color(.systemBackground)
    }
}

#Preview {
    AACGridView()
        .environmentObject(GazeTrackingManager())
}
