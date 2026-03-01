import SwiftUI
import VocableShared

/// Main categories grid screen
struct CategoriesView: View {
    @EnvironmentObject var gazeManager: GazeTrackingManager
    @StateObject private var viewModel: CategoriesViewModel
    @StateObject private var settings = AppSettings.shared
    @State private var selectedCategory: String?
    @State private var navigateToPhases = false
    
    init(database: VocableDatabase = DatabaseManager.shared.db) {
        _viewModel = StateObject(wrappedValue: CategoriesViewModel(database: database))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView("Loading categories...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Text("Error")
                            .font(.title)
                        Text(error)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            viewModel.loadCategories()
                        }
                        .padding()
                    }
                } else if viewModel.categories.isEmpty {
                    EmptyCategoriesView()
                } else {
                    categoriesGrid
                }
            }
            .navigationDestination(isPresented: $navigateToPhases) {
                if let categoryId = selectedCategory {
                    PhrasesView(categoryId: categoryId)
                }
            }
            .onAppear {
                viewModel.loadCategories()
                gazeManager.dwellManager.clearAllButtons()
            }
            .onDisappear {
                gazeManager.dwellManager.clearAllButtons()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CategoriesUpdated"))) { _ in
                viewModel.loadCategories()
            }
        }
        .background(settings.appBorderColor.ignoresSafeArea())
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(.blue)
    }
    
    private var categoriesGrid: some View {
        GeometryReader { geometry in
            let columns = gridColumns
            let columnCount = max(columns.count, 1)
            let rowCount = max(Int(ceil(Double(viewModel.categories.count) / Double(columnCount))), 1)
            let spacing: CGFloat = 12
            let padding: CGFloat = 12
            let totalSpacing = spacing * CGFloat(max(rowCount - 1, 0))
            let availableHeight = geometry.size.height - totalSpacing - (padding * 2)
            let itemHeight = max(140, availableHeight / CGFloat(rowCount))

            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(viewModel.categories) { category in
                        CategoryButton(
                            category: category,
                            color: categoryColor(for: category),
                            height: itemHeight
                        ) {
                            selectedCategory = category.id
                            navigateToPhases = true
                        }
                        .dwellSelectable(
                            id: "cat_\(category.id)",
                            manager: gazeManager.dwellManager
                        ) {
                            selectedCategory = category.id
                            navigateToPhases = true
                        }
                    }
                }
                .padding(padding)
            }
            .scrollContentBackground(.hidden)
            .background(settings.appBorderColor)
        }
    }
    
    private var gridColumns: [GridItem] {
        let count = 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }
    
    private func categoryColor(for category: CategoryDisplayModel) -> Color {
        // Use preset colors for preset categories
        switch category.id {
        case "preset_general": return Color(hex: 0xFFE53935)
        case "preset_basic_needs": return Color(hex: 0xFF1E88E5)
        case "preset_personal_care": return Color(hex: 0xFF43A047)
        case "preset_conversation": return Color(hex: 0xFFFB8C00)
        case "preset_environment": return Color(hex: 0xFF8E24AA)
        case "preset_user_keypad": return Color(hex: 0xFF00ACC1)
        case "preset_recents": return Color(hex: 0xFFF06292)
        default: return Color.gray
        }
    }
}

/// Individual category button
struct CategoryButton: View {
    let category: CategoryDisplayModel
    let color: Color
    let height: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: iconName)
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                Text(category.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(color)
            .cornerRadius(16)
            .shadow(radius: 4)
        }
        .accessibilityLabel("Category: \(category.name). Double tap to open.")
    }
    
    private var iconName: String {
        switch category.id {
        case "preset_general": return "star.fill"
        case "preset_basic_needs": return "heart.fill"
        case "preset_personal_care": return "person.fill"
        case "preset_conversation": return "bubble.left.and.bubble.right.fill"
        case "preset_environment": return "house.fill"
        case "preset_user_keypad": return "textformat.123"
        case "preset_recents": return "clock.fill"
        default: return "folder.fill"
        }
    }
}

#Preview {
    CategoriesView()
}
