import SwiftUI
import VocableShared
import UIKit

/// Phrases grid screen for a category
struct PhrasesView: View {
    let categoryId: String
    
    @EnvironmentObject var gazeManager: GazeTrackingManager
    @EnvironmentObject var mediaCoordinator: MediaPlaybackCoordinator
    @EnvironmentObject var gameCoordinator: GamePlaybackCoordinator
    @StateObject private var viewModel: PhrasesViewModel
    @StateObject private var settings = AppSettings.shared
    @StateObject private var ttsManager = TTSManager.shared
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss
    
    init(categoryId: String, database: VocableDatabase = DatabaseManager.shared.db) {
        self.categoryId = categoryId
        _viewModel = StateObject(wrappedValue: PhrasesViewModel(categoryId: categoryId, database: database))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView("Loading phrases...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack {
                    Text("Error")
                        .font(.title)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        viewModel.loadPhrases()
                    }
                    .padding()
                }
            } else if viewModel.phrases.isEmpty {
                EmptyPhrasesView()
            } else {
                phrasesContent
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .background(settings.appBorderColor)
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(.blue)
        .onAppear {
            gazeManager.dwellManager.clearAllButtons()
        }
        .onDisappear {
            gazeManager.dwellManager.clearAllButtons()
            mediaCoordinator.cancelPending()
            gameCoordinator.cancelPending()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PhrasesUpdated"))) { _ in
            viewModel.loadPhrases()
        }
    }
    
    private var phrasesContent: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                TabView(selection: $currentPage) {
                    // Use Array(...) instead of bare Range so SwiftUI
                    // treats it as dynamic data that updates when totalPages changes.
                    ForEach(Array(0..<totalPages), id: \.self) { page in
                        phrasesGridForPage(page, in: geometry)
                            .tag(page)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Force the TabView to fully recreate when symbolCount changes.
                // Without this, the paged TabView caches stale children and
                // won't show the correct number of phrases per page.
                .id(settings.symbolCount)

                if totalPages > 1 {
                    Text("Page \(currentPage + 1) of \(totalPages)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 8)
                }
            }
        }
        .onChange(of: settings.symbolCount) { _, _ in
            // Reset to page 0 when symbol count changes so we don't
            // land on an out-of-bounds page (e.g. page 3 when there are now only 2 pages)
            currentPage = 0
        }
    }
    
    private func phrasesGridForPage(_ page: Int, in geometry: GeometryProxy) -> some View {
        let phrases = viewModel.phrasesForPage(page: page, symbolCount: settings.symbolCount)
        let columns = gridColumns
        let columnCount = max(columns.count, 1)
        let rowCount = max(Int(ceil(Double(phrases.count) / Double(columnCount))), 1)
        let spacing: CGFloat = 12
        let padding: CGFloat = 12
        let totalSpacing = spacing * CGFloat(max(rowCount - 1, 0))
        let availableHeight = geometry.size.height - totalSpacing - (padding * 2)
        let itemHeight = max(120, availableHeight / CGFloat(rowCount))
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(Array(phrases.enumerated()), id: \.element.id) { index, phrase in
                    let position = (page * settings.symbolCount) + index + 1
                    PhraseButton(
                        phrase: phrase,
                        color: settings.getSymbolColor(position: position),
                        position: position,
                        height: itemHeight
                    ) {
                        handlePhraseSelection(phrase)
                    }
                    .dwellSelectable(
                        id: "phrase_\(phrase.id)",
                        manager: gazeManager.dwellManager
                    ) {
                        handlePhraseSelection(phrase)
                    }
                }
            }
            .padding(padding)
        }
    }
    
    private var gridColumns: [GridItem] {
        let columns = gridColumnsForSymbolCount(settings.symbolCount)
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
    }
    
    private func gridColumnsForSymbolCount(_ count: Int) -> Int {
        switch count {
        case 1: return 1
        case 2: return 2
        case 3: return 2
        case 4: return 2
        default: return 2
        }
    }
    
    private var totalPages: Int {
        viewModel.totalPages(symbolCount: settings.symbolCount)
    }
    
    private func handlePhraseSelection(_ phrase: PhraseDisplayModel) {
        guard mediaCoordinator.phase != .playing, gameCoordinator.phase != .playing else { return }
        viewModel.markPhraseAsSpoken(phraseId: phrase.id)
        ttsManager.speak(phrase.text)
        mediaCoordinator.onPhraseSelected(phrase)
        gameCoordinator.onPhraseSelected(phrase)
    }
}

/// Individual phrase button with optional styling
struct PhraseButton: View {
    let phrase: PhraseDisplayModel
    let color: Color
    let position: Int
    let height: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                let availableHeight = geometry.size.height
                let hasImage = phrase.style?.imageRef?.isEmpty == false
                let minimumTextHeight: CGFloat = 64
                let maxImageHeight = max(0, availableHeight - minimumTextHeight)
                let imageHeight = hasImage ? min(availableHeight * 0.35, maxImageHeight) : 0
                let imageSide = min(geometry.size.width * 0.7, imageHeight)
                
                VStack(spacing: 10) {
                    // Show image/emoji if present
                    if hasImage, let style = phrase.style, let imageRef = style.imageRef, !imageRef.isEmpty, imageHeight > 0 {
                        CachedAsyncImage(imageRef: imageRef, renderSize: imageSide)
                            .frame(height: imageHeight)
                            .frame(maxWidth: .infinity)
                    }
                    
                    bubbleText(
                        phrase.text,
                        fontSize: resolvedFontSize(in: geometry.size, reservedImageHeight: imageHeight)
                    )
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(6)
            .background(backgroundColor)
            .cornerRadius(16)
            .shadow(radius: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Phrase: \(phrase.text). Double tap to speak.")
    }
    
    // MARK: - Style Properties
    
    private var fontWeight: Font.Weight {
        if let style = phrase.style, style.isBold {
            return .bold
        }
        return .medium
    }
    
    // Default phrase style colors (kept as Swift constants to avoid KMP framework rebuild dependency)
    private static let defaultTextColor: UInt32      = 0xFF000000 // Black
    private static let defaultBackgroundColor: UInt32 = 0xFF000000 // Black
    private static let defaultBorderColor: UInt32    = 0xFFE53935 // Red

    private var textColor: Color {
        if let style = phrase.style, let color = style.textColor {
            return Color(hex: color.uint32Value)
        }
        return Color(hex: PhraseButton.defaultTextColor)
    }
    
    private var backgroundColor: Color {
        if let style = phrase.style, let bgColor = style.backgroundColor {
            return Color(hex: bgColor.uint32Value)
        }
        return Color(hex: PhraseButton.defaultBackgroundColor)
    }
    
    private var borderColor: Color {
        if let style = phrase.style, let bColor = style.borderColor {
            return Color(hex: bColor.uint32Value)
        }
        return Color(hex: PhraseButton.defaultBorderColor)
    }
    
    private var borderWidth: CGFloat {
        if let style = phrase.style, let width = style.borderWidthDp {
            return CGFloat(truncating: width)
        }
        return 6
    }

    private func bubbleText(_ text: String, fontSize: CGFloat) -> some View {
        let font = Font.system(size: fontSize, weight: fontWeight, design: .default)
        let outlineColor = borderWidth > 0 ? borderColor : nil
        let outlineWidth = outlineColor != nil ? max(2, min(8, borderWidth)) : 0
        let offsets: [(CGFloat, CGFloat)] = [
            (-outlineWidth, 0), (outlineWidth, 0),
            (0, -outlineWidth), (0, outlineWidth),
            (-outlineWidth, -outlineWidth), (outlineWidth, -outlineWidth),
            (-outlineWidth, outlineWidth), (outlineWidth, outlineWidth)
        ]

        return ZStack {
            if let outlineColor, outlineWidth > 0 {
                ForEach(0..<offsets.count, id: \.self) { index in
                    Text(text)
                        .font(font)
                        .foregroundColor(outlineColor)
                        .offset(x: offsets[index].0, y: offsets[index].1)
                        .lineLimit(3)
                }
            }
            Text(text)
                .font(font)
                .foregroundColor(textColor)
                .lineLimit(3)
        }
        .multilineTextAlignment(.center)
    }

    private func resolvedFontSize(in size: CGSize, reservedImageHeight: CGFloat) -> CGFloat {
        let reservedHeight: CGFloat = reservedImageHeight + 8 + 12
        let availableWidth = max(size.width - 12, 40)
        let availableHeight = max(size.height - reservedHeight, 20)
        let isSingleWord = !phrase.text.contains { $0.isWhitespace }

        let maxSize = min(96, availableHeight)
        let minSize: CGFloat = 18
        let uiWeight: UIFont.Weight = (fontWeight == .bold) ? .bold : .medium

        var low = minSize
        var high = maxSize
        var best = minSize

        for _ in 0..<14 {
            let mid = (low + high) / 2
            let font = UIFont.systemFont(ofSize: mid, weight: uiWeight)
            let bounding = NSString(string: phrase.text).boundingRect(
                with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )

            let maxHeight = isSingleWord ? font.lineHeight : font.lineHeight * 3
            let fitsWidth = !isSingleWord || bounding.width <= availableWidth
            let fitsHeight = bounding.height <= min(availableHeight, maxHeight) + 0.5

            if fitsWidth && fitsHeight {
                best = mid
                low = mid
            } else {
                high = mid
            }
        }

        return best
    }
}

#Preview {
    NavigationStack {
        PhrasesView(categoryId: "preset_routine_activity")
    }
}
