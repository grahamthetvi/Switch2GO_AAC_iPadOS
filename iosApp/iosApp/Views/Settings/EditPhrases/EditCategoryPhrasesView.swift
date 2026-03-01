import SwiftUI
import VocableShared

/// Edit phrases for a category
struct EditCategoryPhrasesView: View {
    let categoryId: String
    
    @StateObject private var viewModel: PhrasesViewModel
    @State private var showingAddPhrase = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    
    init(categoryId: String) {
        self.categoryId = categoryId
        _viewModel = StateObject(wrappedValue: PhrasesViewModel(categoryId: categoryId))
    }
    
    var body: some View {
        List {
            ForEach(viewModel.phrases) { phrase in
                NavigationLink(destination: EditPhraseDetailView(phrase: phrase)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(phrase.text)
                                .font(.body)
                            
                            if phrase.isPreset {
                                Text("Preset")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if phrase.style != nil {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                }
            }
            .onMove { from, to in
                viewModel.reorderPhrases(from: from, to: to)
                NotificationCenter.default.post(name: Notification.Name("PhrasesUpdated"), object: nil)
            }
        }
        .navigationTitle("Edit Phrases")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    settingsHomeAction?() ?? dismiss()
                }) {
                    Label("Home", systemImage: "house.fill")
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                EditButton()
                Button(action: {
                    showingAddPhrase = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPhrase) {
            AddPhraseView(categoryId: categoryId) {
                viewModel.loadPhrases()
            }
        }
    }
}

/// Add new phrase view
struct AddPhraseView: View {
    let categoryId: String
    let onSaved: () -> Void
    
    @State private var phraseText: String = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Phrase text", text: $phraseText)
                    .font(.title2)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding()
                
                Button(action: savePhrase) {
                    Text("Save Phrase")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(phraseText.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(phraseText.isEmpty)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Add Phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Home") {
                        settingsHomeAction?() ?? dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func savePhrase() {
        let database = DatabaseManager.shared.db
        let phraseId = "custom_\(UUID().uuidString)"
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        
        database.phraseQueries.insertPhrase(
            phrase_id: phraseId,
            parent_category_id: categoryId,
            creation_date: timestamp,
            last_spoken_date: nil,
            localized_utterance: phraseText,
            sort_order: 999,
            style: nil
        )
        dismiss()
        onSaved()
        NotificationCenter.default.post(name: Notification.Name("PhrasesUpdated"), object: nil)
    }
}

#Preview {
    NavigationStack {
        EditCategoryPhrasesView(categoryId: "preset_general")
    }
}
