import SwiftUI
import VocableShared

/// Detail view for editing a single phrase
struct EditPhraseDetailView: View {
    let phrase: PhraseDisplayModel
    
    @StateObject private var settings = AppSettings.shared
    @State private var phraseText: String
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    
    init(phrase: PhraseDisplayModel) {
        self.phrase = phrase
        _phraseText = State(initialValue: phrase.text)
    }
    
    var body: some View {
        List {
            Section("Phrase Text") {
                if phrase.isPreset {
                    Text(phrase.text)
                        .foregroundColor(.secondary)
                    Text("Preset phrases cannot be edited")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    TextField("Text", text: $phraseText)
                        .font(.body)
                        .onChange(of: phraseText) { _, newValue in
                            updatePhraseText(newValue)
                        }
                }
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
        .alert("Delete Phrase?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePhrase()
            }
        } message: {
            Text("This will permanently delete '\(phrase.text)'.")
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
            sortOrder: 0,
            isPreset: false,
            style: nil
        ))
    }
}
