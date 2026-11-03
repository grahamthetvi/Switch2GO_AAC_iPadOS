import SwiftUI
import VocableShared

/// Detail view for editing a single phrase
struct EditPhraseDetailView: View {
    let phrase: PhraseDisplayModel
    
    @StateObject private var settings = AppSettings.shared
    @State private var phraseText: String
    @State private var spokenText: String
    @State private var showingDeleteConfirmation = false
    @State private var showingMediaDelayTip = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    
    init(phrase: PhraseDisplayModel) {
        self.phrase = phrase
        _phraseText = State(initialValue: phrase.text)
        _spokenText = State(initialValue: phrase.spokenText ?? "")
    }
    
    var body: some View {
        List {
            Section {
                if phrase.isPreset {
                    Text(phrase.text)
                        .foregroundColor(.secondary)
                    Text("Preset button text comes from the app and cannot be edited.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    TextField("What shows on the button", text: $phraseText, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.body)
                        .onChange(of: phraseText) { _, newValue in
                            updatePhraseText(newValue)
                        }
                    Text("This is the label on the phrase button.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Presented text")
            }

            Section {
                TextField("Same as the button text", text: $spokenText, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.body)
                    .onChange(of: spokenText) { _, newValue in
                        updateSpokenText(newValue)
                    }
                Text("What is spoken aloud. Leave blank to say the button text.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Preview speech") {
                    let presented = phrase.isPreset ? phrase.text : phraseText
                    TTSManager.shared.speak(PhraseSpeech.speechText(presented: presented, spoken: spokenText))
                }
                .disabled((phrase.isPreset ? phrase.text : phraseText)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty)
            } header: {
                Text("Spoken text")
            }
            
            Section("Style") {
                NavigationLink(destination: PhraseStyleEditorView(phrase: phrase)) {
                    HStack {
                        Label("Edit Style", systemImage: "paintbrush.fill")
                        
                        Spacer()
                        
                        if phrase.style != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Section {
                if !phrase.isPreset {
                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        Label("Delete Phrase", systemImage: "trash")
                    }
                } else {
                    Text("Preset phrases cannot be deleted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("Edit Phrase")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    settingsHomeAction?() ?? dismiss()
                }) {
                    Label("Home", systemImage: "house.fill")
                }
            }
        }
        .onAppear {
            if !settings.hasSeenPhraseMediaDelayTip {
                showingMediaDelayTip = true
            }
        }
        .alert("Video, Audio & Game Delay", isPresented: $showingMediaDelayTip) {
            Button("Got It") {
                settings.hasSeenPhraseMediaDelayTip = true
            }
        } message: {
            Text(
                "When you attach a video, audio, or game to a phrase, it starts after a short delay "
                + "(\(Self.formattedDelay(settings.mediaPlaybackDelay))) so another phrase can be selected first. "
                + "Change this anytime in Settings → Timing & Sensitivity."
            )
        }
        .alert("Delete Phrase?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePhrase()
            }
        } message: {
            Text(L("This will permanently delete '%@'.", phrase.text))
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private static func formattedDelay(_ seconds: Double) -> String {
        if seconds == seconds.rounded() {
            return "\(Int(seconds)) seconds"
        }
        return String(format: "%.1f seconds", seconds)
    }
    
    private func updatePhraseText(_ newText: String) {
        guard !phrase.isPreset else { return }
        
        let database = DatabaseManager.shared.db
        DispatchQueue.global(qos: .background).async {
            database.phraseQueries.updatePhraseText(
                localized_utterance: newText,
                phrase_id: phrase.id
            )
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("PhrasesUpdated"), object: nil)
            }
        }
    }

    private func updateSpokenText(_ newText: String) {
        let stored = PhraseSpeech.normalizedSpokenText(newText)
        let database = DatabaseManager.shared.db
        DispatchQueue.global(qos: .background).async {
            if phrase.isPreset {
                database.presetPhraseQueries.updatePresetPhraseSpokenText(
                    spoken_text: stored,
                    phrase_id: phrase.id
                )
            } else {
                database.phraseQueries.updatePhraseSpokenText(
                    spoken_text: stored,
                    phrase_id: phrase.id
                )
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("PhrasesUpdated"), object: nil)
            }
        }
    }
    
    private func deletePhrase() {
        let database = DatabaseManager.shared.db
        
        DispatchQueue.global(qos: .background).async {
            database.phraseQueries.deletePhrase(phrase_id: phrase.id)
            
            DispatchQueue.main.async {
                dismiss()
                NotificationCenter.default.post(name: Notification.Name("PhrasesUpdated"), object: nil)
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditPhraseDetailView(phrase: PhraseDisplayModel(
            id: "test",
            text: "Test Phrase",
            spokenText: nil,
            sortOrder: 0,
            isPreset: false,
            style: nil
        ))
    }
}
