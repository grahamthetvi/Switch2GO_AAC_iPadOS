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
    @State private var showingColorPicker = false
    @State private var showingSymbolPicker = false
    @State private var categoryColorHex: UInt32?
    @State private var categorySymbolName: String?
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportShareURL: URL?
    @State private var showingEmailSizeWarning = false
    @State private var pendingExport: PhrasePackExportResult?
    @State private var exportError: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    
    init(category: CategoryDisplayModel) {
        self.category = category
        _categoryName = State(initialValue: category.name)
        _phrasesViewModel = StateObject(wrappedValue: PhrasesViewModel(categoryId: category.id))
        _categoryColorHex = State(initialValue: category.colorHex)
        _categorySymbolName = State(initialValue: category.symbolName)
    }
    
    private var displayColor: Color {
        if let hex = categoryColorHex {
            return Color(hex: hex)
        }
        return defaultColorForCategory
    }
    
    private var displaySymbol: String {
        categorySymbolName ?? defaultSymbolForCategory
    }
    
    private var defaultColorForCategory: Color {
        switch category.id {
        case "preset_routine_activity": return Color(hex: 0xFFE53935)
        case "preset_food_drink": return Color(hex: 0xFF1E88E5)
        case "preset_comfort_state": return Color(hex: 0xFF43A047)
        case "preset_play_leisure": return Color(hex: 0xFFFB8C00)
        case "preset_positioning": return Color(hex: 0xFF8E24AA)
        case "preset_recents": return Color(hex: 0xFFF06292)
        default: return Color(hex: 0xFF00ACC1)
        }
    }
    
    private var defaultSymbolForCategory: String {
        switch category.id {
        case "preset_routine_activity": return "checklist"
        case "preset_food_drink": return "fork.knife"
        case "preset_comfort_state": return "heart.fill"
        case "preset_play_leisure": return "gamecontroller.fill"
        case "preset_positioning": return "figure.stand"
        case "preset_recents": return "clock.arrow.circlepath"
        default: return "folder.fill"
        }
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
            
            Section("Appearance") {
                Button(action: { showingColorPicker = true }) {
                    HStack {
                        Text("Color")
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(displayColor)
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                            )
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: { showingSymbolPicker = true }) {
                    HStack {
                        Text("Icon")
                        Spacer()
                        Image(systemName: displaySymbol)
                            .font(.title2)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
            
            Section("Phrase Pack") {
                if CoreVocabulary.isRecents(category.id) {
                    Text("Recently Said cannot be exported.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button {
                        exportCategory()
                    } label: {
                        if isExporting {
                            HStack {
                                ProgressView()
                                Text("Preparing pack...")
                            }
                        } else {
                            Label("Export Category", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isExporting)
                    Text("Creates a .switch2go file you can send by Mail, AirDrop, or Files. Videos should be 20 seconds or shorter. Files larger than 24.75 MB may not send by school email.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button(role: .destructive, action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete Category", systemImage: "trash")
                }
                if category.isPreset {
                    Text("Preset categories can be restored by resetting the app.")
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
            if CoreVocabulary.isRecents(category.id) {
                Text("This will remove '\(category.name)' from the category list. Reset the app to restore it.")
            } else if category.isPreset {
                Text("This will remove '\(category.name)' and all its phrases. Reset the app to restore preset categories.")
            } else {
                Text("This will permanently delete '\(category.name)' and all its phrases.")
            }
        }
        .sheet(isPresented: $showingAddPhrase) {
            AddPhraseView(categoryId: category.id) {
                phrasesViewModel.loadPhrases()
            }
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(
                selectedColor: displayColor,
                onColorSelected: { color in
                    let hex = color.toHex()
                    categoryColorHex = hex
                    updateCategoryColor(hex)
                    showingColorPicker = false
                },
                onCancel: { showingColorPicker = false }
            )
        }
        .sheet(isPresented: $showingSymbolPicker) {
            SymbolPickerView(
                selectedSymbol: displaySymbol,
                onSymbolSelected: { symbol in
                    categorySymbolName = symbol
                    updateCategorySymbol(symbol)
                    showingSymbolPicker = false
                },
                onCancel: { showingSymbolPicker = false }
            )
        }
        .alert("Could not export", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .alert("File may be too large for email", isPresented: $showingEmailSizeWarning) {
            Button("Share anyway") {
                if let pendingExport {
                    exportShareURL = pendingExport.fileURL
                    showingShareSheet = true
                }
            }
            Button("Cancel", role: .cancel) {
                pendingExport = nil
            }
        } message: {
            Text("This pack is larger than 24.75 MB. School email may reject it. Use AirDrop or Save to Files.")
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: {
            exportShareURL = nil
            pendingExport = nil
        }) {
            if let exportShareURL {
                ShareSheet(items: [exportShareURL])
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PhrasesUpdated"))) { _ in
            phrasesViewModel.loadPhrases()
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    private func updateCategoryColor(_ hex: UInt32) {
        let database = DatabaseManager.shared.db
        DispatchQueue.global(qos: .background).async {
            if category.id.hasPrefix("preset_") {
                database.presetCategoryQueries.updatePresetCategoryColor(
                    color_hex: KotlinLong(value: Int64(hex)),
                    category_id: category.id
                )
            } else {
                database.categoryQueries.updateCategoryColor(
                    color_hex: KotlinLong(value: Int64(hex)),
                    category_id: category.id
                )
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("CategoriesUpdated"), object: nil)
            }
        }
    }
    
    private func updateCategorySymbol(_ symbol: String) {
        let database = DatabaseManager.shared.db
        DispatchQueue.global(qos: .background).async {
            if category.id.hasPrefix("preset_") {
                database.presetCategoryQueries.updatePresetCategorySymbol(
                    symbol_name: symbol,
                    category_id: category.id
                )
            } else {
                database.categoryQueries.updateCategorySymbol(
                    symbol_name: symbol,
                    category_id: category.id
                )
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("CategoriesUpdated"), object: nil)
            }
        }
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
        let categoryId = category.id
        let isPreset = category.isPreset
        let isRecents = CoreVocabulary.isRecents(categoryId)
        
        DispatchQueue.global(qos: .background).async {
            if isPreset {
                database.presetCategoryQueries.updatePresetCategoryDeleted(
                    deleted: 1,
                    category_id: categoryId
                )
                if !isRecents {
                    let presetPhrases = database.presetPhraseQueries
                        .getPresetPhrasesForCategory(parent_category_id: categoryId)
                        .executeAsList()
                    for phrase in presetPhrases {
                        database.presetPhraseQueries.updatePresetPhraseDeleted(
                            deleted: 1,
                            phrase_id: phrase.phrase_id
                        )
                    }
                    database.phraseQueries.deletePhrasesForCategory(parent_category_id: categoryId)
                }
            } else {
                database.phraseQueries.deletePhrasesForCategory(parent_category_id: categoryId)
                database.categoryQueries.deleteCategory(category_id: categoryId)
            }
            
            DispatchQueue.main.async {
                dismiss()
                NotificationCenter.default.post(name: Notification.Name("CategoriesUpdated"), object: nil)
                NotificationCenter.default.post(name: Notification.Name("PhrasesUpdated"), object: nil)
            }
        }
    }

    private func exportCategory() {
        isExporting = true
        let snapshot = category
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try PhrasePackExporter.exportCategory(category: snapshot)
                DispatchQueue.main.async {
                    isExporting = false
                    pendingExport = result
                    if result.exceedsEmailLimit {
                        showingEmailSizeWarning = true
                    } else {
                        exportShareURL = result.fileURL
                        showingShareSheet = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    exportError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
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
            hidden: false,
            colorHex: nil,
            symbolName: nil
        ))
    }
}
