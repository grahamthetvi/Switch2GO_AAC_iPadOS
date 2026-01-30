import SwiftUI
import AVFoundation

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var outputText: String = ""

    // Predefined phrase categories (matching Android app structure)
    let categories = [
        PhraseCategory(name: "General", icon: "bubble.left.fill", phrases: [
            "Hello", "Goodbye", "Yes", "No", "Please", "Thank you",
            "I need help", "I'm okay", "Wait a moment"
        ]),
        PhraseCategory(name: "Feelings", icon: "heart.fill", phrases: [
            "I'm happy", "I'm sad", "I'm tired", "I'm hungry",
            "I'm thirsty", "I'm in pain", "I feel good"
        ]),
        PhraseCategory(name: "Questions", icon: "questionmark.circle.fill", phrases: [
            "What time is it?", "Where are we going?", "Who is that?",
            "Can you help me?", "What's happening?", "When will it be ready?"
        ]),
        PhraseCategory(name: "Actions", icon: "figure.walk", phrases: [
            "I want to go", "I want to stay", "Turn it on", "Turn it off",
            "Open it", "Close it", "Move it"
        ]),
        PhraseCategory(name: "My Sayings", icon: "star.fill", phrases: [])
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Output display area
            OutputDisplayView(text: outputText)

            // Categories grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(categories) { category in
                        CategoryCard(category: category) { phrase in
                            outputText = phrase
                            speakPhrase(phrase)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Switch2GO AAC")
    }

    private func speakPhrase(_ phrase: String) {
        let utterance = AVSpeechUtterance(string: phrase)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5

        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}

struct PhraseCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let phrases: [String]
}

struct CategoryCard: View {
    let category: PhraseCategory
    let onPhraseSelected: (String) -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack {
            Button(action: { isExpanded.toggle() }) {
                VStack(spacing: 12) {
                    Image(systemName: category.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    Text(category.name)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(Color.blue)
                .cornerRadius(16)
            }
            .sheet(isPresented: $isExpanded) {
                PhrasesListView(category: category, onPhraseSelected: onPhraseSelected)
            }
        }
    }
}

struct PhrasesListView: View {
    let category: PhraseCategory
    let onPhraseSelected: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List(category.phrases, id: \.self) { phrase in
                Button(action: {
                    onPhraseSelected(phrase)
                    dismiss()
                }) {
                    Text(phrase)
                        .font(.title2)
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle(category.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct OutputDisplayView: View {
    let text: String

    var body: some View {
        HStack {
            Text(text.isEmpty ? "Tap a category to speak" : text)
                .font(.title)
                .foregroundColor(text.isEmpty ? .gray : .primary)
                .padding()
            Spacer()
            if !text.isEmpty {
                Button(action: {
                    // Speak again
                    let utterance = AVSpeechUtterance(string: text)
                    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                    let synthesizer = AVSpeechSynthesizer()
                    synthesizer.speak(utterance)
                }) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                .padding()
            }
        }
        .frame(height: 80)
        .background(Color(.systemGray6))
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
