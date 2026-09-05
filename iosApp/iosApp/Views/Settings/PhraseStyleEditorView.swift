import SwiftUI
import VocableShared

/// Comprehensive phrase style editor - CRITICAL CVI FEATURE
/// Allows per-phrase customization of colors, text, borders, images, and emojis
struct PhraseStyleEditorView: View {
    let phrase: PhraseDisplayModel
    
    @StateObject private var settings = AppSettings.shared
    @State private var currentStyle: PhraseStyle
    @State private var showingBackgroundColorPicker = false
    @State private var showingTextColorPicker = false
    @State private var showingBorderColorPicker = false
    @State private var showingBorderWidthPicker = false
    @State private var showingImagePicker = false
    @State private var showingVideoPicker = false
    @State private var showingAudioPicker = false
    @State private var showingYouTubePicker = false
    @State private var showingGamePicker = false
    @State private var isBold = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    private let database = DatabaseManager.shared.db
    
    init(phrase: PhraseDisplayModel) {
        self.phrase = phrase
        let baseStyle = phrase.style ?? PhraseStyle(
            backgroundColor: nil,
            textColor: nil,
            textSizeSp: nil,
            isBold: false,
            borderColor: nil,
            borderWidthDp: nil,
            imageRef: nil,
            mediaRef: nil,
            mediaType: nil,
            gameType: nil
        )
        let initialStyle = PhraseStyle(
            backgroundColor: baseStyle.backgroundColor,
            textColor: baseStyle.textColor,
            textSizeSp: baseStyle.textSizeSp,
            isBold: baseStyle.isBold,
            borderColor: baseStyle.borderColor,
            borderWidthDp: baseStyle.borderWidthDp,
            imageRef: baseStyle.imageRef,
            mediaRef: baseStyle.mediaRef,
            mediaType: baseStyle.mediaType,
            gameType: baseStyle.gameType
        )
        initialStyle.sendSwitchOutput = phrase.style?.sendSwitchOutput ?? false
        _currentStyle = State(initialValue: initialStyle)
        _isBold = State(initialValue: phrase.style?.isBold ?? false)
    }

    private var sendSwitchOutputBinding: Binding<Bool> {
        Binding(
            get: { currentStyle.sendSwitchOutput },
            set: { newValue in
                currentStyle.sendSwitchOutput = newValue
                saveStyle()
            }
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Live Preview
                previewSection
                
                // Style Options
                styleOptionsSection
            }
            .padding(.vertical)
        }
        .scrollContentBackground(.hidden)
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("Edit Style")
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
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingBackgroundColorPicker) {
            ColorPickerView(
                selectedColor: backgroundColorForDisplay,
                onColorSelected: handleBackgroundColorSelection,
                onCancel: { showingBackgroundColorPicker = false }
            )
        }
        .sheet(isPresented: $showingTextColorPicker) {
            textColorPickerSheet
        }
        .sheet(isPresented: $showingBorderColorPicker) {
            borderColorPickerSheet
        }
        .sheet(isPresented: $showingBorderWidthPicker) {
            borderWidthPickerSheet
        }
        .sheet(isPresented: $showingImagePicker) {
            imagePickerSheet
        }
        .sheet(isPresented: $showingVideoPicker) {
            mediaPickerSheet(type: PhraseStyle.companion.MEDIA_TYPE_VIDEO)
        }
        .sheet(isPresented: $showingAudioPicker) {
            mediaPickerSheet(type: PhraseStyle.companion.MEDIA_TYPE_AUDIO)
        }
        .sheet(isPresented: $showingYouTubePicker) {
            youtubePickerSheet
        }
        .sheet(isPresented: $showingGamePicker) {
            GamePickerView(
                currentGameType: currentStyle.gameType,
                onGameSelected: { gameType in
                    if let gameType {
                        clearPreviousLocalMedia(oldRef: currentStyle.mediaRef, newRef: nil)
                        currentStyle = cloneCurrentStyle(
                            gameType: gameType,
                            clearMedia: true,
                            clearGame: false
                        )
                    } else {
                        currentStyle = cloneCurrentStyle(clearGame: true)
                    }
                    saveStyle()
                    showingGamePicker = false
                },
                onCancel: { showingGamePicker = false }
            )
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    // MARK: - View Components
    
    private var styleOptionsSection: some View {
        VStack(spacing: 16) {
                    // Background Color
                    styleButton(
                        title: "Background Color",
                        icon: "paintbrush.fill",
                        color: backgroundColorForDisplay
                    ) {
                        showingBackgroundColorPicker = true
                    }
                    
                    // Text Color
                    styleButton(
                        title: "Text Color",
                        icon: "textformat",
                        color: textColorForDisplay
                    ) {
                        showingTextColorPicker = true
                    }
                    
                    // Bold Toggle
                    Toggle(isOn: $isBold) {
                        Label("Bold Text", systemImage: "bold")
                            .font(.headline)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .onChange(of: isBold) { _, newValue in
                        currentStyle = cloneCurrentStyle(isBold: newValue)
                        saveStyle()
                    }
                    
                    // Border Color
                    styleButton(
                        title: "Border Color",
                        icon: "square.on.square",
                        color: borderColorForDisplay
                    ) {
                        showingBorderColorPicker = true
                    }
                    
                    // Border Thickness
                    styleButton(
                        title: "Border Thickness: \(borderWidthLabel)",
                        icon: "line.3.horizontal",
                        color: .blue
                    ) {
                        showingBorderWidthPicker = true
                    }
                    
                    // Image/Emoji
                    styleButton(
                        title: imageLabel,
                        icon: "photo",
                        color: .purple
                    ) {
                        showingImagePicker = true
                    }

                    styleButton(
                        title: videoMediaLabel,
                        icon: "film",
                        color: .indigo
                    ) {
                        showingVideoPicker = true
                    }

                    styleButton(
                        title: audioMediaLabel,
                        icon: "waveform",
                        color: .teal
                    ) {
                        showingAudioPicker = true
                    }

                    styleButton(
                        title: youtubeMediaLabel,
                        icon: "play.rectangle",
                        color: .red
                    ) {
                        showingYouTubePicker = true
                    }

                    styleButton(
                        title: gameLabel,
                        icon: "gamecontroller.fill",
                        color: .mint
                    ) {
                        showingGamePicker = true
                    }

                    Toggle(isOn: sendSwitchOutputBinding) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Send switch output", systemImage: "poweroutlet.type.b")
                                .font(.headline)
                            Text("When this phrase is selected, pulse the paired ESP32 so a PowerLink can toggle a device (fan, light).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Reset to Default
                    Button(action: resetToDefault) {
                        Label("Reset to Default", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
        }
    
    // MARK: - Sheet Views
    
    private var textColorPickerSheet: some View {
        ColorPickerView(
            selectedColor: textColorForDisplay,
            onColorSelected: { color in
                currentStyle = cloneCurrentStyle(
                    textColor: KotlinUInt(value: UInt32(color.toHex()))
                )
                saveStyle()
                showingTextColorPicker = false
            },
            onCancel: { showingTextColorPicker = false }
        )
    }
    
    private var borderColorPickerSheet: some View {
        ColorPickerView(
            selectedColor: borderColorForDisplay,
            onColorSelected: { color in
                    currentStyle = cloneCurrentStyle(
                        borderColor: KotlinUInt(value: UInt32(color.toHex())),
                        borderWidthDp: currentStyle.borderWidthDp ?? KotlinFloat(value: 6.0)
                    )
                    saveStyle()
                    showingBorderColorPicker = false
                },
                onCancel: { showingBorderColorPicker = false }
        )
    }
    
    
    private var borderWidthPickerSheet: some View {
        BorderWidthPickerView(
                selectedWidth: currentStyle.borderWidthDp?.floatValue ?? 0.0,
                onWidthSelected: { width in
                    currentStyle = cloneCurrentStyle(borderWidthDp: KotlinFloat(value: width))
                    saveStyle()
                    showingBorderWidthPicker = false
                },
                onCancel: { showingBorderWidthPicker = false }
        )
    }
    
    private var imagePickerSheet: some View {
        ImagePickerView(
                selectedImage: currentStyle.imageRef,
                onImageSelected: { imageRef in
                    currentStyle = cloneCurrentStyle(imageRef: imageRef)
                    saveStyle()
                    showingImagePicker = false
                },
                onCancel: { showingImagePicker = false }
        )
    }

    private func mediaPickerSheet(type: String) -> some View {
        MediaPickerView(
            mediaType: type,
            currentMediaRef: currentStyle.mediaRef,
            currentImageRef: currentStyle.imageRef,
            onMediaSelected: { mediaRef, mediaType, posterRef in
                clearPreviousLocalMedia(oldRef: currentStyle.mediaRef, newRef: mediaRef)
                if mediaRef == nil {
                    clearPreviousLocalMedia(oldRef: currentStyle.mediaRef, newRef: nil)
                }
                let shouldApplyPoster = posterRef != nil && (currentStyle.imageRef == nil || currentStyle.imageRef?.isEmpty == true)
                currentStyle = cloneCurrentStyle(
                    imageRef: shouldApplyPoster ? posterRef : nil,
                    mediaRef: mediaRef,
                    mediaType: mediaType,
                    clearMedia: mediaRef == nil,
                    clearGame: mediaRef != nil
                )
                saveStyle()
                showingVideoPicker = false
                showingAudioPicker = false
            },
            onCancel: {
                showingVideoPicker = false
                showingAudioPicker = false
            }
        )
    }

    private var youtubePickerSheet: some View {
        YouTubePickerView(
            currentMediaRef: currentStyle.mediaRef,
            onMediaSelected: { mediaRef, mediaType in
                clearPreviousLocalMedia(oldRef: currentStyle.mediaRef, newRef: mediaRef)
                currentStyle = cloneCurrentStyle(
                    mediaRef: mediaRef,
                    mediaType: mediaType,
                    clearMedia: mediaRef == nil,
                    clearGame: mediaRef != nil
                )
                saveStyle()
                showingYouTubePicker = false
            },
            onCancel: {
                showingYouTubePicker = false
            }
        )
    }

    private func clearPreviousLocalMedia(oldRef: String?, newRef: String?) {
        guard let oldRef, oldRef != newRef, MediaStorage.isLocalMediaRef(oldRef) else { return }
        MediaStorage.deleteMedia(mediaRef: oldRef)
    }

    private func cloneCurrentStyle(
        backgroundColor: KotlinUInt? = nil,
        textColor: KotlinUInt? = nil,
        textSizeSp: KotlinFloat? = nil,
        isBold: Bool? = nil,
        borderColor: KotlinUInt? = nil,
        borderWidthDp: KotlinFloat? = nil,
        imageRef: String? = nil,
        mediaRef: String? = nil,
        mediaType: String? = nil,
        gameType: String? = nil,
        clearMedia: Bool = false,
        clearGame: Bool = false,
        sendSwitchOutput: Bool? = nil
    ) -> PhraseStyle {
        let style = PhraseStyle(
            backgroundColor: backgroundColor ?? currentStyle.backgroundColor,
            textColor: textColor ?? currentStyle.textColor,
            textSizeSp: textSizeSp ?? currentStyle.textSizeSp,
            isBold: isBold ?? currentStyle.isBold,
            borderColor: borderColor ?? currentStyle.borderColor,
            borderWidthDp: borderWidthDp ?? currentStyle.borderWidthDp,
            imageRef: imageRef ?? currentStyle.imageRef,
            mediaRef: clearMedia ? nil : (mediaRef ?? currentStyle.mediaRef),
            mediaType: clearMedia ? nil : (mediaType ?? currentStyle.mediaType),
            gameType: clearGame ? nil : (gameType ?? currentStyle.gameType)
        )
        style.sendSwitchOutput = sendSwitchOutput ?? currentStyle.sendSwitchOutput
        return style
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColorForDisplay: Color {
        Color(hex: UInt32(truncatingIfNeeded: currentStyle.effectiveBackgroundColor()))
    }
    
    private var textColorForDisplay: Color {
        Color(hex: UInt32(truncatingIfNeeded: currentStyle.effectiveTextColor()))
    }
    
    private var borderColorForDisplay: Color {
        if let borderColor = currentStyle.borderColor {
            return Color(hex: borderColor.uint32Value)
        }
        return Color(hex: 0xFFE53935) // Default red matches DEFAULT_BORDER_COLOR
    }
    
    // MARK: - Handlers
    
    private func handleBackgroundColorSelection(_ color: Color) {
        currentStyle = cloneCurrentStyle(
            backgroundColor: KotlinUInt(value: UInt32(color.toHex()))
        )
        saveStyle()
        showingBackgroundColorPicker = false
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(spacing: 12) {
            Text("Preview")
                .font(.caption)
                .foregroundColor(.secondary)
            
            bubblePreviewText()
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(hex: UInt32(truncatingIfNeeded: currentStyle.effectiveBackgroundColor())))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            currentStyle.borderColor != nil
                                ? Color(hex: currentStyle.borderColor!.uint32Value)
                                : Color.clear,
                            lineWidth: currentStyle.borderWidthDp != nil
                                ? CGFloat(truncating: currentStyle.borderWidthDp!)
                                : 0
                        )
                )
                .shadow(radius: 4)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func bubblePreviewText() -> some View {
        let font = Font.system(
            size: CGFloat(currentStyle.effectiveTextSize()),
            weight: currentStyle.isBold ? .bold : .regular,
            design: .default
        )
        let textColor = Color(hex: UInt32(truncatingIfNeeded: currentStyle.effectiveTextColor()))
        let outlineColor = currentStyle.borderColor != nil
            ? Color(hex: currentStyle.borderColor!.uint32Value)
            : nil
        let borderWidth = currentStyle.borderWidthDp != nil
            ? CGFloat(truncating: currentStyle.borderWidthDp!)
            : 0
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
                    Text(phrase.text)
                        .font(font)
                        .foregroundColor(outlineColor)
                        .offset(x: offsets[index].0, y: offsets[index].1)
                        .lineLimit(3)
                }
            }
            Text(phrase.text)
                .font(font)
                .foregroundColor(textColor)
                .lineLimit(3)
        }
        .multilineTextAlignment(.center)
    }
    
    // MARK: - Helper Views
    
    private func styleButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Labels
    
    private var borderWidthLabel: String {
        let width = currentStyle.borderWidthDp ?? 0
        switch width {
        case 0: return "None"
        case 6: return "Thin"
        case 10: return "Medium"
        case 14: return "Thick"
        case 20: return "XL"
        case 28: return "XXL"
        default: return "\(Int(truncating: width))dp"
        }
    }
    
    private var imageLabel: String {
        guard let imageRef = currentStyle.imageRef, !imageRef.isEmpty else {
            return "Image/Emoji: None"
        }
        
        if let emoji = PhraseStyle.extractEmoji(ref: imageRef) {
            return "Image/Emoji: \(emoji)"
        }
        
        if imageRef.hasPrefix("content://")
            || imageRef.hasPrefix("file://")
            || imageRef.hasPrefix("/")
            || MediaStorage.isRelativeFileRef(imageRef) {
            return "Image/Emoji: Custom"
        }
        
        return "Image/Emoji: Symbol"
    }

    private var videoMediaLabel: String {
        if currentStyle.isVideo() { return "Video: Attached" }
        return "Video: None"
    }

    private var audioMediaLabel: String {
        if currentStyle.isAudio() { return "Audio: Attached" }
        return "Audio: None"
    }

    private var youtubeMediaLabel: String {
        if currentStyle.isYouTube(), let ref = currentStyle.mediaRef {
            return "YouTube: \(ref)"
        }
        return "YouTube: None"
    }

    private var gameLabel: String {
        if currentStyle.isCursorRocketGame() {
            return "Game: Rocket cursor follower"
        }
        if currentStyle.isBlocsGameType() {
            return "Game: Blocs"
        }
        if currentStyle.isPieCrazyGameType() {
            return "Game: Pie Crazy"
        }
        return "Game: None"
    }
    
    // MARK: - Actions
    
    private func saveStyle() {
        // Clone on the main thread so associated fields (e.g. sendSwitchOutput) are captured
        // before hopping to a background queue for JSON + DB writes.
        let styleToSave = cloneCurrentStyle()
        DispatchQueue.global(qos: .background).async {
            let styleString = styleToSave.toJSONString()
            
            // Update in database
            if phrase.isPreset {
                database.presetPhraseQueries.updatePresetPhraseStyle(
                    style: styleString,
                    phrase_id: phrase.id
                )
            } else {
                database.phraseQueries.updatePhraseStyle(
                    style: styleString,
                    phrase_id: phrase.id
                )
            }
            
            DebugLog.debug("Saved style for phrase \(phrase.id)", tag: "PhraseStyleEditor")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("PhrasesUpdated"), object: nil)
            }
        }
    }
    
    private func resetToDefault() {
        MediaStorage.deleteMedia(mediaRef: currentStyle.mediaRef)
        let reset = PhraseStyle(
            backgroundColor: nil,
            textColor: nil,
            textSizeSp: nil,
            isBold: false,
            borderColor: nil,
            borderWidthDp: nil,
            imageRef: nil,
            mediaRef: nil,
            mediaType: nil,
            gameType: nil
        )
        reset.sendSwitchOutput = false
        currentStyle = reset
        isBold = false
        saveStyle()
    }
}

#Preview {
    NavigationStack {
        PhraseStyleEditorView(phrase: PhraseDisplayModel(
            id: "test",
            text: "Hello World",
            sortOrder: 0,
            isPreset: false,
            style: nil
        ))
    }
}
