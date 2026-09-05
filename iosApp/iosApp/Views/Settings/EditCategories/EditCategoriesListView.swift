import SwiftUI
import Combine
import VocableShared

/// Edit Categories List - Show/hide, reorder, manage categories
struct EditCategoriesListView: View {
    @StateObject private var viewModel = EditCategoriesViewModel()
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    @State private var showingAddCategory = false
    
    var body: some View {
        List {
            Section("Number of Phrases") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Number of phrases to display per page")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            if settings.symbolCount > 1 {
                                settings.symbolCount -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundColor(settings.symbolCount > 1 ? .blue : .gray)
                        }
                        .buttonStyle(.borderless)
                        .disabled(settings.symbolCount <= 1)
                        
                        Text("\(settings.symbolCount)")
                            .font(.system(size: 36, weight: .bold))
                            .frame(width: 80)
                        
                        Button(action: {
                            if settings.symbolCount < 4 {
                                settings.symbolCount += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(settings.symbolCount < 4 ? .blue : .gray)
                        }
                        .buttonStyle(.borderless)
                        .disabled(settings.symbolCount >= 4)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Text(layoutDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
            }

            ForEach(viewModel.categories) { category in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.headline)
                        
                        if category.isPreset {
                            Text("Preset")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Show/Hide toggle
                    Toggle("", isOn: Binding(
                        get: { !category.hidden },
                        set: { newValue in
                            viewModel.toggleCategoryVisibility(categoryId: category.id, hidden: !newValue)
                        }
                    ))
                    .labelsHidden()
                    
                    NavigationLink(destination: EditCategoryDetailView(category: category)) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Edit \(category.name)")
                }
            }
            .onMove { from, to in
                viewModel.reorderCategories(from: from, to: to)
            }
        }
        .scrollContentBackground(.hidden)
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("Edit Categories")
        .navigationBarTitleDisplayMode(.large)
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
                    showingAddCategory = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView {
                viewModel.loadCategories()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CategoriesUpdated"))) { _ in
            viewModel.loadCategories()
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var layoutDescription: String {
        switch settings.symbolCount {
        case 1: return "1 phrase: Full screen"
        case 2: return "2 phrases: Left and Right"
        case 3: return "3 phrases: 2 top, 1 bottom"
        case 4: return "4 phrases: 2x2 grid"
        default: return "\(settings.symbolCount) phrases"
        }
    }
}

/// ViewModel for editing categories
class EditCategoriesViewModel: ObservableObject {
    @Published var categories: [CategoryDisplayModel] = []
    
    private let database = DatabaseManager.shared.db
    
    init() {
        loadCategories()
    }
    
    func loadCategories() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var displayModels: [CategoryDisplayModel] = []
            
            // Get all preset categories (including hidden)
            let presets = self.database.presetCategoryQueries
                .getAllPresetCategories()
                .executeAsList()
            
            for preset in presets where preset.deleted == 0 {
                let name = self.getCategoryName(for: preset.category_id)
                let colorHex = preset.color_hex != nil ? UInt32(truncating: preset.color_hex!) : nil
                displayModels.append(CategoryDisplayModel(
                    id: preset.category_id,
                    name: name,
                    sortOrder: Int(preset.sort_order),
                    isPreset: true,
                    hidden: preset.hidden != 0,
                    colorHex: colorHex,
                    symbolName: preset.symbol_name
                ))
            }
            
            // Get all custom categories
            let customs = self.database.categoryQueries
                .getAllCategories()
                .executeAsList()
            
            for custom in customs {
                let colorHex = custom.color_hex != nil ? UInt32(truncating: custom.color_hex!) : nil
                displayModels.append(CategoryDisplayModel(
                    id: custom.category_id,
                    name: custom.localized_name,
                    sortOrder: Int(custom.sort_order),
                    isPreset: false,
                    hidden: custom.hidden != 0,
                    colorHex: colorHex,
                    symbolName: custom.symbol_name
                ))
            }
            
            displayModels.sort { $0.sortOrder < $1.sortOrder }
            
            DispatchQueue.main.async {
                self.categories = displayModels
            }
        }
    }
    
    func toggleCategoryVisibility(categoryId: String, hidden: Bool) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            // Check if preset or custom
            if categoryId.hasPrefix("preset_") {
                self.database.presetCategoryQueries.updatePresetCategoryHidden(
                    hidden: hidden ? 1 : 0,
                    category_id: categoryId
                )
            } else {
                self.database.categoryQueries.updateCategoryHidden(
                    hidden: hidden ? 1 : 0,
                    category_id: categoryId
                )
            }
            
            DispatchQueue.main.async {
                self.loadCategories()
                NotificationCenter.default.post(name: Notification.Name("CategoriesUpdated"), object: nil)
            }
        }
    }
    
    func reorderCategories(from: IndexSet, to: Int) {
        var reordered = categories
        reordered.move(fromOffsets: from, toOffset: to)
        
        // Update sort orders
        for (index, category) in reordered.enumerated() {
            updateCategorySortOrder(categoryId: category.id, sortOrder: index)
        }
        
        categories = reordered
        NotificationCenter.default.post(name: Notification.Name("CategoriesUpdated"), object: nil)
    }
    
    private func updateCategorySortOrder(categoryId: String, sortOrder: Int) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            if categoryId.hasPrefix("preset_") {
                self.database.presetCategoryQueries.updatePresetCategorySortOrder(
                    sort_order: Int64(sortOrder),
                    category_id: categoryId
                )
            } else {
                self.database.categoryQueries.updateCategorySortOrder(
                    sort_order: Int64(sortOrder),
                    category_id: categoryId
                )
            }
        }
    }
    
    private func getCategoryName(for categoryId: String) -> String {
        switch categoryId {
        case "preset_routine_activity": return "Daily Activities"
        case "preset_food_drink": return "Food & Drinks"
        case "preset_comfort_state": return "How I Feel"
        case "preset_play_leisure": return "Fun & Games"
        case "preset_positioning": return "Move Me"
        case "preset_recents": return "Recently Said"
        default: return categoryId
        }
    }
}

/// Default colors for new custom categories (vibrant palette, no grey)
private let newCategoryColorPalette: [UInt32] = [
    0xFFE53935, 0xFF1E88E5, 0xFF43A047, 0xFFFB8C00,
    0xFF8E24AA, 0xFF00ACC1, 0xFFF06292, 0xFFFFEE58,
    0xFF26A69A, 0xFF673AB7
]

/// Add new custom category
struct AddCategoryView: View {
    @State private var categoryName: String = ""
    @State private var selectedColorHex: UInt32 = 0xFF00ACC1  // Teal default
    @State private var selectedSymbol: String = "folder.fill"
    @State private var showingColorPicker = false
    @State private var showingSymbolPicker = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    let onSaved: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section("Category Name") {
                    TextField("Name", text: $categoryName)
                        .font(.body)
                }
                
                Section("Appearance") {
                    Button(action: { showingColorPicker = true }) {
                        HStack {
                            Text("Color")
                            Spacer()
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: selectedColorHex))
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
                            Image(systemName: selectedSymbol)
                                .font(.title2)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: saveCategory) {
                        HStack {
                            Spacer()
                            Text("Save Category")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding()
                        .background(categoryName.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(categoryName.isEmpty)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Add Category")
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
            .sheet(isPresented: $showingColorPicker) {
                ColorPickerView(
                    selectedColor: Color(hex: selectedColorHex),
                    onColorSelected: { color in
                        selectedColorHex = color.toHex()
                        showingColorPicker = false
                    },
                    onCancel: { showingColorPicker = false }
                )
            }
            .sheet(isPresented: $showingSymbolPicker) {
                SymbolPickerView(
                    selectedSymbol: selectedSymbol,
                    onSymbolSelected: { symbol in
                        selectedSymbol = symbol
                        showingSymbolPicker = false
                    },
                    onCancel: { showingSymbolPicker = false }
                )
            }
        }
    }
    
    private func saveCategory() {
        let database = DatabaseManager.shared.db
        let categoryId = "custom_\(UUID().uuidString)"
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        
        database.categoryQueries.insertCategory(
            category_id: categoryId,
            creation_date: timestamp,
            localized_name: categoryName,
            hidden: 0,
            sort_order: -timestamp,
            color_hex: KotlinLong(value: Int64(selectedColorHex)),
            symbol_name: selectedSymbol
        )
        dismiss()
        onSaved()
        NotificationCenter.default.post(name: Notification.Name("CategoriesUpdated"), object: nil)
    }
}

#Preview {
    NavigationStack {
        KeyboardView()
    }
}
