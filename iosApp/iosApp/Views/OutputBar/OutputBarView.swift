import SwiftUI

/// Output bar showing composed phrases and TTS controls
struct OutputBarView: View {
    @StateObject private var ttsManager = TTSManager.shared
    @State private var composedText: String = ""
    
    var body: some View {
        HStack(spacing: 16) {
            // Composed text display
            Text(composedText.isEmpty ? "Select something" : composedText)
                .font(.title2)
                .foregroundColor(composedText.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            // Speaker icon (when speaking)
            if ttsManager.isSpeaking {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                    .transition(.scale)
            }
            
            // Speak button
            Button(action: {
                if !composedText.isEmpty {
                    ttsManager.speak(composedText)
                }
            }) {
                Image(systemName: "speaker.3.fill")
                    .font(.title2)
                    .foregroundColor(composedText.isEmpty ? .gray : .blue)
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
            }
            .disabled(composedText.isEmpty)
            
            // Clear button
            Button(action: {
                composedText = ""
                ttsManager.stop()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(composedText.isEmpty ? .gray : .red)
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
            }
            .disabled(composedText.isEmpty)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .shadow(radius: 4)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PhraseSelected"))) { notification in
            if let text = notification.userInfo?["text"] as? String {
                addPhraseToComposed(text)
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Add phrase to composed text
    func addPhrase(_ text: String) {
        addPhraseToComposed(text)
    }
    
    private func addPhraseToComposed(_ text: String) {
        if composedText.isEmpty {
            composedText = text
        } else {
            composedText += " " + text
        }
    }
    
    /// Clear composed text
    func clear() {
        composedText = ""
        ttsManager.stop()
    }
}

#Preview {
    OutputBarView()
}
