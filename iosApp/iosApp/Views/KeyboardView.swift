import SwiftUI
import AVFoundation

struct KeyboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText: String = ""
    @State private var predictions: [String] = []

    // QWERTY keyboard layout
    let keyboardRows = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Output display
            OutputTextView(text: inputText)

            // Prediction bar
            PredictionBar(predictions: predictions) { word in
                appendWord(word)
            }

            Spacer()

            // Keyboard
            VStack(spacing: 8) {
                ForEach(keyboardRows, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.self) { key in
                            KeyButton(key: key) {
                                inputText += key.lowercased()
                                updatePredictions()
                            }
                        }
                    }
                }

                // Bottom row with special keys
                HStack(spacing: 8) {
                    ActionButton(title: "Clear", color: .red) {
                        inputText = ""
                        predictions = []
                    }

                    ActionButton(title: "Space", color: .gray) {
                        inputText += " "
                        updatePredictions()
                    }
                    .frame(maxWidth: .infinity)

                    ActionButton(title: "⌫", color: .orange) {
                        if !inputText.isEmpty {
                            inputText.removeLast()
                            updatePredictions()
                        }
                    }

                    ActionButton(title: "Speak", color: .blue) {
                        speakText()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Keyboard")
    }

    private func appendWord(_ word: String) {
        // Remove partial word and add the predicted word
        let words = inputText.split(separator: " ")
        if let lastWord = words.last, !inputText.hasSuffix(" ") {
            inputText = words.dropLast().joined(separator: " ")
            if !inputText.isEmpty {
                inputText += " "
            }
        }
        inputText += word + " "
        updatePredictions()
    }

    private func updatePredictions() {
        // Simple prediction based on common words
        let commonWords = ["the", "and", "is", "it", "to", "of", "in", "for", "on", "with",
                          "hello", "help", "how", "here", "have", "happy",
                          "I", "want", "need", "like", "love", "please", "thank", "you",
                          "good", "great", "okay", "yes", "no", "maybe"]

        let currentWord = inputText.split(separator: " ").last?.lowercased() ?? ""

        if currentWord.isEmpty {
            predictions = Array(commonWords.prefix(5))
        } else {
            predictions = commonWords
                .filter { $0.hasPrefix(currentWord) && $0 != currentWord }
                .prefix(5)
                .map { String($0) }
        }
    }

    private func speakText() {
        guard !inputText.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: inputText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5

        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}

struct OutputTextView: View {
    let text: String

    var body: some View {
        HStack {
            Text(text.isEmpty ? "Type to speak..." : text)
                .font(.title2)
                .foregroundColor(text.isEmpty ? .gray : .primary)
                .padding()
            Spacer()
        }
        .frame(height: 80)
        .background(Color(.systemGray6))
    }
}

struct PredictionBar: View {
    let predictions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(predictions, id: \.self) { word in
                    Button(action: { onSelect(word) }) {
                        Text(word)
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 50)
    }
}

struct KeyButton: View {
    let key: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(key)
                .font(.title2)
                .fontWeight(.medium)
                .frame(width: 32, height: 48)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(8)
        }
    }
}

struct ActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(height: 48)
                .frame(minWidth: 60)
                .padding(.horizontal, 12)
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
}

#Preview {
    KeyboardView()
        .environmentObject(AppState())
}
