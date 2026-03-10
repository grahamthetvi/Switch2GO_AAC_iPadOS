import SwiftUI
import VocableShared

/// Detail view for editing a single category
struct EditCategoryDetailView: View {
    let category: CategoryDisplayModel
    
    @StateObject private var settings = AppSettings.shared
    @State private var categoryName: String
    @State private var showingDeleteConfirmation = false
    @StateObject private var phrasesViewModel: PhrasesViewModel
    @State private var showingAddPhrase = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    
    init(category: CategoryDisplayModel) {
        self.category = category
        _categoryName = State(initialValue: category.name)
        _phrasesViewModel = StateObject(wrappedValue: PhrasesViewModel(categoryId: category.id))
    }
    
    var body: some View {
        List {
            Section("Category Name") {
                if category.isPreset {
                    Text(category.name)
                        .foregroundColor(.secondary)
                    Text("Preset categories cannot be renamed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    TextField("Name", text: $categoryName)
                        .font(.body)
                        .onChange(of: categoryName) { _, newValue in
                            updateCategoryName(newValue)
                        }
                }
            }
            
            Section {
                ForEach(phrasesViewModel.phrases) { phrase in
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
                    phrasesViewModel.reorderPhrases(from: from, to: to)
                    NotificationCenter.default.post(name: Notification.Name("PhrasesUpdated"), object: nil)
                }
            } header: {
                HStack {
                    Text("Phrases")
                    Spacer()
                    Button(action: {
                        showingAddPhrase = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add Phrase")
                }
            }
            
            Section {
                if !category.isPreset {
                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        Label("Delete Category", systemImage: "trash")
                    }
                } else {
                    Text("Preset categories cannot be deleted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("Edit Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    settingsHomeAction?() ?? dismiss()
                }) {
                    Label("Home", systemImage: "house.fill")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .alert("Delete Category?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteCategory()
            }
        } message: {
            Text("This will permanently delete '\(category.name)' and all its phrases.")
        }
        .sheet(isPresented: $showingAddPhrase) {
            AddPhraseView(categoryId: category.id) {
                phrasesViewModel.loadPhrases()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PhrasesUpdated"))) { _ in
            phrasesViewModel.loadPhrases()
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    private func updateCategoryName(_ newName: String) {
        guard !category.isPreset else { return }
        
        let database = DatabaseManager.shared.db
        DispatchQueue.global(qos: .background).async {
            database.categoryQueries.updateCategoryName(
                localized_name: newName,
                category_id: category.id
            )
        }
    }
    
    private func deleteCategory() {
        let database = DatabaseManager.shared.db
        
        DispatchQueue.global(qos: .background).async {
            // Delete all phrases in category
            database.phraseQueries.deletePhrasesForCategory(parent_category_id: category.id)
            
            // Delete category
            database.categoryQueries.deleteCategory(category_id: category.id)
            
            DispatchQueue.main.async {
                dismiss()
                NotificationCenter.default.post(name: Notification.Name("CategoriesUpdated"), object: nil)
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditCategoryDetailView(category: CategoryDisplayModel(
            id: "test",
            name: "Test Category",
            sortOrder: 0,
            isPreset: false,
            hidden: false
        ))
    }
}
