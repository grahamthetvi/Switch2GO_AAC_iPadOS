import SwiftUI
import VocableShared
import UIKit
import Combine

/// Phrases grid screen for a category
struct PhrasesView: View {
    let categoryId: String
    
    @EnvironmentObject var gazeManager: GazeTrackingManager
    @EnvironmentObject var mediaCoordinator: MediaPlaybackCoordinator
    @EnvironmentObject var gameCoordinator: GamePlaybackCoordinator
    @StateObject private var viewModel: PhrasesViewModel
    @StateObject private var settings = AppSettings.shared
    @State private var currentPage = 0
    @State private var lastHandledActivationToken: UInt64 = 0
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
            gazeManager.dwellManager.unregisterButtons(withPrefix: "cat_")
            // Don't replay activations that happened before this screen appeared.
            lastHandledActivationToken = gazeManager.dwellManager.activationToken
            if categoryId == "preset_recents" {
                viewModel.loadPhrases()
            }
        }
        .onDisappear {
            gazeManager.dwellManager.unregisterButtons(withPrefix: "phrase_")
            mediaCoordinator.cancelPending()
            gameCoordinator.cancelPending()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PhrasesUpdated"))) { _ in
            viewModel.loadPhrases()
        }
        .onReceive(gazeManager.dwellManager.$lastActivation.compactMap { $0 }) { activation in
            dispatchDwellPhraseActivation(activation)
        }
        .onReceive(gazeManager.armRaiseActivation) { side in
            guard settings.selectionMode == "armRaise" else { return }
            selectPhraseBySide(side, onPage: currentPage)
        }
        .onReceive(gazeManager.handGestureActivation) { side in
            guard settings.selectionMode == "handGesture" else { return }
            selectPhraseBySide(side, onPage: currentPage)
        }
    }

    private var armRaiseActive: Bool { settings.selectionMode == "armRaise" }
    private var handGestureActive: Bool { settings.selectionMode == "handGesture" }
    private var binarySelectionActive: Bool { armRaiseActive || handGestureActive }

    private func pagePhrases(for page: Int) -> [PhraseDisplayModel] {
        viewModel.phrasesForPage(page: page, symbolCount: settings.symbolCount)
    }

    private func binarySelectionReady(for page: Int) -> Bool {
        binarySelectionActive && settings.symbolCount == 2 && pagePhrases(for: page).count == 2
    }

    private func selectPhraseBySide(_ side: ArmSide, onPage page: Int) {
        guard binarySelectionReady(for: page) else { return }
        let phrases = pagePhrases(for: page)
        let index = side == .left ? 0 : 1
        handlePhraseSelection(phrases[index])
    }

    private func gestureHighlighted(for index: Int, page: Int) -> Bool {
        guard binarySelectionReady(for: page) else { return false }
        if armRaiseActive {
            return (index == 0 && gazeManager.armState.leftRaised)
                || (index == 1 && gazeManager.armState.rightRaised)
        }
        if handGestureActive {
            return (index == 0 && gazeManager.handState.leftPose != nil)
                || (index == 1 && gazeManager.handState.rightPose != nil)
        }
        return false
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
        
        return VStack(spacing: 8) {
            if binarySelectionActive && !binarySelectionReady(for: page) {
                Text(armRaiseActive
                    ? "Arm raise selection works with 2 phrases per page (left and right). Change layout in Settings → CVI Display."
                    : "Hand gesture selection works with 2 phrases per page (left and right). Change layout in Settings → CVI Display.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, padding)
            } else if armRaiseActive && binarySelectionReady(for: page) {
                Text("Raise your left arm for the left phrase, or your right arm for the right phrase.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, padding)
            } else if handGestureActive && binarySelectionReady(for: page) {
                Text("Open then close your left hand (or close then open) for the left phrase. Use your right hand for the right phrase.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, padding)
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(Array(phrases.enumerated()), id: \.element.id) { index, phrase in
                        let position = (page * settings.symbolCount) + index + 1
                        let phraseButton = PhraseButton(
                            phrase: phrase,
                            color: settings.getSymbolColor(position: position),
                            position: position,
                            height: itemHeight,
                            isGestureHighlighted: gestureHighlighted(for: index, page: page)
                        ) {
                            handlePhraseSelection(phrase)
                        }

                        if binarySelectionActive {
                            phraseButton
                        } else {
                            phraseButton
                                .dwellSelectable(
                                    id: "phrase_\(phrase.id)",
                                    manager: gazeManager.dwellManager,
                                    isActive: currentPage == page,
                                    onActivate: {
                                        // Belt-and-suspenders with $lastActivation:
                                        // LazyVGrid recycling can drop per-button handlers,
                                        // but when they fire this shares the token dedupe path.
                                        if let activation = gazeManager.dwellManager.lastActivation,
                                           activation.buttonId == "phrase_\(phrase.id)" {
                                            dispatchDwellPhraseActivation(activation)
                                        }
                                    }
                                )
                        }
                    }
                }
                .padding(padding)
            }
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
        guard mediaCoordinator.phase != .playing, gameCoordinator.phase != .playing else {
            DebugLog.debug(
                "Phrase selection blocked — media=\(mediaCoordinator.phase) game=\(gameCoordinator.phase)",
                tag: "Dwell"
            )
            return
        }
        DebugLog.info("Phrase selected — speaking \"\(phrase.text)\"", tag: "Dwell")
        viewModel.markPhraseAsSpoken(phraseId: phrase.id)
        TTSManager.shared.speak(phrase.text)
        mediaCoordinator.onPhraseSelected(phrase)
        gameCoordinator.onPhraseSelected(phrase)
    }

    private func dispatchDwellPhraseActivation(_ activation: DwellActivation) {
        guard activation.token != lastHandledActivationToken else { return }
        guard activation.buttonId.hasPrefix("phrase_") else { return }
        // Ignore stale activations replayed while phrases are still loading
        // (onReceive resubscribes and can redeliver CurrentValueSubject values).
        guard !viewModel.isLoading else { return }

        let phraseId = String(activation.buttonId.dropFirst("phrase_".count))
        guard let phrase = viewModel.phrases.first(where: { $0.id == phraseId }) else {
            DebugLog.warn("Dwell: no phrase matches \(activation.buttonId)", tag: "Dwell")
            return
        }
        lastHandledActivationToken = activation.token
        handlePhraseSelection(phrase)
    }
}

/// Individual phrase button with optional styling
struct PhraseButton: View {
    let phrase: PhraseDisplayModel
    let color: Color
    let position: Int
    let height: CGFloat
    var isGestureHighlighted: Bool = false
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
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isGestureHighlighted ? Color.yellow : Color.clear, lineWidth: 4)
            )
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
        // Sample a full circle so stroked glyphs don't show flat "rungs"
        // from the old 8-direction offset technique.
        let sampleCount = 16
        let offsets: [(CGFloat, CGFloat)] = (0..<sampleCount).map { index in
            let angle = (Double(index) / Double(sampleCount)) * 2 * Double.pi
            return (CGFloat(cos(angle)) * outlineWidth, CGFloat(sin(angle)) * outlineWidth)
        }

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
