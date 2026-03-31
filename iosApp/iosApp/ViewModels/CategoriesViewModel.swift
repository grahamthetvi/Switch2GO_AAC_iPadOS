import Foundation
import Combine
import VocableShared

/// ViewModel for categories screen
class CategoriesViewModel: ObservableObject {
    @Published var categories: [CategoryDisplayModel] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    private let database: VocableDatabase
    private var cancellables = Set<AnyCancellable>()
    
    init(database: VocableDatabase = DatabaseManager.shared.db) {
        self.database = database
        loadCategories()
    }
    
    /// Load all visible categories
    func loadCategories() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Get preset categories
            let presets = self.database.presetCategoryQueries
                .getVisiblePresetCategories()
                .executeAsList()
            
            // Get custom categories
            let customs = self.database.categoryQueries
                .getVisibleCategories()
                .executeAsList()
            
            // Map to display models
            var displayModels: [CategoryDisplayModel] = []
            
            // Add preset categories
            for preset in presets {
                let name = self.getCategoryName(for: preset.category_id)
                let colorHex = preset.color_hex != nil ? UInt32(truncating: preset.color_hex!) : nil
                displayModels.append(CategoryDisplayModel(
                    id: preset.category_id,
                    name: name,
                    sortOrder: Int(preset.sort_order),
                    isPreset: true,
                    hidden: preset.hidden == 1,
                    colorHex: colorHex,
                    symbolName: preset.symbol_name
                ))
            }
            
            // Add custom categories
            for custom in customs {
                let colorHex = custom.color_hex != nil ? UInt32(truncating: custom.color_hex!) : nil
                displayModels.append(CategoryDisplayModel(
                    id: custom.category_id,
                    name: custom.localized_name,
                    sortOrder: Int(custom.sort_order),
                    isPreset: false,
                    hidden: custom.hidden == 1,
                    colorHex: colorHex,
                    symbolName: custom.symbol_name
                ))
            }
            
            // Sort by sortOrder
            displayModels.sort { $0.sortOrder < $1.sortOrder }
            
            DispatchQueue.main.async {
                self.categories = displayModels
                self.isLoading = false
            }
        }
    }
    
    /// Get localized category name (natural, conversational)
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

/// Display model for a category
struct CategoryDisplayModel: Identifiable {
    let id: String
    let name: String
    let sortOrder: Int
    let isPreset: Bool
    let hidden: Bool
    let colorHex: UInt32?
    let symbolName: String?
}

extension Bool {
    var boolValue: Bool {
        return self
    }
}
