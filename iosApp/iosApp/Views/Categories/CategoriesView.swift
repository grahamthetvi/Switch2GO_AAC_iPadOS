import SwiftUI
import VocableShared
import Combine

/// Main categories grid screen
struct CategoriesView: View {
    @EnvironmentObject var gazeManager: GazeTrackingManager
    @EnvironmentObject var phrasePacks: PhrasePackSession
    @StateObject private var viewModel: CategoriesViewModel
    @StateObject private var settings = AppSettings.shared
    @State private var selectedCategory: String?
    @State private var navigateToPhases = false
    @State private var lastHandledActivationToken: UInt64 = 0
    
    init(database: VocableDatabase = DatabaseManager.shared.db) {
        _viewModel = StateObject(wrappedValue: CategoriesViewModel(database: database))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView {
                        Text(l10n: "Loading categories...")
                    }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Text(l10n: "Error")
                            .font(.title)
                        Text(error)
                            .foregroundColor(.secondary)
                        Button(L("Retry")) {
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
                gazeManager.dwellManager.unregisterButtons(withPrefix: "phrase_")
                lastHandledActivationToken = gazeManager.dwellManager.activationToken
            }
            .onDisappear {
                // Only drop category targets. clearAllButtons() here races PhrasesView
                // registration when NavigationStack pushes the phrases destination.
                gazeManager.dwellManager.unregisterButtons(withPrefix: "cat_")
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CategoriesUpdated"))) { _ in
                viewModel.loadCategories()
            }
            .onChange(of: phrasePacks.importedCategoryId) { _, categoryId in
                guard let categoryId else { return }
                viewModel.loadCategories()
                selectedCategory = categoryId
                navigateToPhases = true
                phrasePacks.importedCategoryId = nil
            }
            .onReceive(gazeManager.dwellManager.$lastActivation.compactMap { $0 }) { activation in
                dispatchDwellCategoryActivation(activation)
            }
            .onChange(of: navigateToPhases) { _, isShowingPhrases in
                if isShowingPhrases {
                    // Phrases screen owns dwell targets; drop category registrations
                    // so covered category tiles cannot steal activations or remount PhrasesView.
                    gazeManager.dwellManager.unregisterButtons(withPrefix: "cat_")
                }
            }
        }
        .background(settings.appBorderColor.ignoresSafeArea())
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(.blue)
        // AAC tiles stay physical left-to-right so eye/arm/switch targeting
        // is not mirrored when the UI language is Arabic.
        .environment(\.layoutDirection, .leftToRight)
    }
    
    private var categoriesGrid: some View {
        GeometryReader { geometry in
            let columns = gridColumns
            let columnCount = max(columns.count, 1)
            let rowCount = max(Int(ceil(Double(viewModel.categories.count) / Double(columnCount))), 1)
            let spacing: CGFloat = 12
            let padding: CGFloat = 12
            // Leave room for ContentView's floating settings control
            // (status-bar inset ~59 + pad + ~44pt gear + gap).
            let topChrome: CGFloat = 100
            let totalSpacing = spacing * CGFloat(max(rowCount - 1, 0))
            let availableHeight = geometry.size.height - totalSpacing - (padding * 2) - topChrome
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
                            manager: gazeManager.dwellManager,
                            isActive: !navigateToPhases,
                            onActivate: {
                                if let activation = gazeManager.dwellManager.lastActivation,
                                   activation.buttonId == "cat_\(category.id)" {
                                    dispatchDwellCategoryActivation(activation)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, padding)
                .padding(.bottom, padding)
                .padding(.top, padding + topChrome)
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
        // Use custom color if set
        if let hex = category.colorHex {
            return Color(hex: hex)
        }
        // Default preset colors (vibrant, not grey)
        switch category.id {
        case "preset_routine_activity": return Color(hex: 0xFFE53935)
        case "preset_food_drink": return Color(hex: 0xFF1E88E5)
        case "preset_comfort_state": return Color(hex: 0xFF43A047)
        case "preset_play_leisure": return Color(hex: 0xFFFB8C00)
        case "preset_positioning": return Color(hex: 0xFF8E24AA)
        case "preset_recents": return Color(hex: 0xFFF06292)
        default: return Color(hex: 0xFF00ACC1)  // Teal - no more grey for custom categories
        }
    }

    private func dispatchDwellCategoryActivation(_ activation: DwellActivation) {
        guard activation.token != lastHandledActivationToken else { return }
        guard !navigateToPhases else { return }
        guard activation.buttonId.hasPrefix("cat_") else { return }
        let categoryId = String(activation.buttonId.dropFirst("cat_".count))
        guard viewModel.categories.contains(where: { $0.id == categoryId }) else {
            DebugLog.warn("Dwell: no category matches \(activation.buttonId)", tag: "Dwell")
            return
        }
        lastHandledActivationToken = activation.token
        selectedCategory = categoryId
        navigateToPhases = true
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
        .accessibilityLabel(L("Category: %@. Double tap to open.", category.name))
    }
    
    private var iconName: String {
        // Use custom symbol if set
        if let symbol = category.symbolName, !symbol.isEmpty {
            return symbol
        }
        // Default preset symbols (intuitive, recognizable)
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
}

#Preview {
    CategoriesView()
        .environmentObject(GazeTrackingManager())
        .environmentObject(PhrasePackSession())
}
