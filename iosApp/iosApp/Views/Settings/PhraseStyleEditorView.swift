import SwiftUI
import VocableShared

/// Comprehensive phrase style editor - CRITICAL CVI FEATURE
/// Allows per-phrase customization of colors, text, borders, images, and emojis
struct PhraseStyleEditorView: View {
    let phrase: PhraseDisplayModel
    
    @State private var currentStyle: PhraseStyle
    @State private var showingBackgroundColorPicker = false
    @State private var showingTextColorPicker = false
    @State private var showingBorderColorPicker = false
    @State private var showingBorderWidthPicker = false
    @State private var showingImagePicker = false
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
            imageRef: nil
        )
        _currentStyle = State(initialValue: PhraseStyle(
            backgroundColor: baseStyle.backgroundColor,
            textColor: baseStyle.textColor,
            textSizeSp: nil,
            isBold: baseStyle.isBold,
            borderColor: baseStyle.borderColor,
            borderWidthDp: baseStyle.borderWidthDp,
            imageRef: baseStyle.imageRef
        ))
        _isBold = State(initialValue: phrase.style?.isBold ?? false)
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
                        currentStyle = PhraseStyle(
                            backgroundColor: currentStyle.backgroundColor,
                            textColor: currentStyle.textColor,
                            textSizeSp: currentStyle.textSizeSp,
                            isBold: newValue,
                            borderColor: currentStyle.borderColor,
                            borderWidthDp: currentStyle.borderWidthDp,
                            imageRef: currentStyle.imageRef
                        )
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
                currentStyle = PhraseStyle(
                    backgroundColor: currentStyle.backgroundColor,
                    textColor: KotlinUInt(value: UInt32(color.toHex())),
                    textSizeSp: currentStyle.textSizeSp,
                    isBold: currentStyle.isBold,
                    borderColor: currentStyle.borderColor,
                    borderWidthDp: currentStyle.borderWidthDp,
                    imageRef: currentStyle.imageRef
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
                    currentStyle = PhraseStyle(
                        backgroundColor: currentStyle.backgroundColor,
                        textColor: currentStyle.textColor,
                        textSizeSp: currentStyle.textSizeSp,
                        isBold: currentStyle.isBold,
                        borderColor: KotlinUInt(value: UInt32(color.toHex())),
                        borderWidthDp: currentStyle.borderWidthDp ?? KotlinFloat(value: 6.0),
                        imageRef: currentStyle.imageRef
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
                    currentStyle = PhraseStyle(
                        backgroundColor: currentStyle.backgroundColor,
                        textColor: currentStyle.textColor,
                        textSizeSp: currentStyle.textSizeSp,
                        isBold: currentStyle.isBold,
                        borderColor: currentStyle.borderColor,
                        borderWidthDp: KotlinFloat(value: width),
                        imageRef: currentStyle.imageRef
                    )
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
                    currentStyle = PhraseStyle(
                        backgroundColor: currentStyle.backgroundColor,
                        textColor: currentStyle.textColor,
                        textSizeSp: currentStyle.textSizeSp,
                        isBold: currentStyle.isBold,
                        borderColor: currentStyle.borderColor,
                        borderWidthDp: currentStyle.borderWidthDp,
                        imageRef: imageRef
                    )
                    saveStyle()
                    showingImagePicker = false
                },
                onCancel: { showingImagePicker = false }
        )
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
        return .gray
    }
    
    // MARK: - Handlers
    
    private func handleBackgroundColorSelection(_ color: Color) {
        currentStyle = PhraseStyle(
            backgroundColor: KotlinUInt(value: UInt32(color.toHex())),
            textColor: currentStyle.textColor,
            textSizeSp: currentStyle.textSizeSp,
            isBold: currentStyle.isBold,
            borderColor: currentStyle.borderColor,
            borderWidthDp: currentStyle.borderWidthDp,
            imageRef: currentStyle.imageRef
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
        
        if imageRef.hasPrefix("content://") || imageRef.hasPrefix("file://") {
            return "Image/Emoji: Custom"
        }
        
        return "Image/Emoji: Symbol"
    }
    
    // MARK: - Actions
    
    private func saveStyle() {
        DispatchQueue.global(qos: .background).async {
            // Serialize style to JSON using PhraseStyle extension
            let styleToSave = PhraseStyle(
                backgroundColor: currentStyle.backgroundColor,
                textColor: currentStyle.textColor,
                textSizeSp: nil,
                isBold: currentStyle.isBold,
                borderColor: currentStyle.borderColor,
                borderWidthDp: currentStyle.borderWidthDp,
                imageRef: currentStyle.imageRef
            )
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
        currentStyle = PhraseStyle(
            backgroundColor: nil,
            textColor: nil,
            textSizeSp: nil,
            isBold: false,
            borderColor: nil,
            borderWidthDp: nil,
            imageRef: nil
        )
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
