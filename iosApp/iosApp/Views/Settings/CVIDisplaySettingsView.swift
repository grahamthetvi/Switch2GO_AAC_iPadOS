import SwiftUI

/// CVI Display Settings - Symbol count and per-position colors
struct CVIDisplaySettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    @State private var showingColorPicker = false
    @State private var selectedPosition: Int?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Symbol Count Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Symbol Count")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Number of symbols to display per page (reduces visual complexity)")
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
                            .font(.system(size: 48, weight: .bold))
                            .frame(width: 100)
                        
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
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Per-Position Colors Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Position Colors")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Customize the color for each symbol position")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(1...max(settings.symbolCount, 1), id: \.self) { position in
                            positionColorButton(position: position)
                        }
                    }
                    
                    Button("Reset to Default Colors") {
                        settings.resetColorsToDefaults()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("CVI Display Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Home") {
                    settingsHomeAction?() ?? dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingColorPicker) {
            if let position = selectedPosition {
                ColorPickerView(
                    selectedColor: settings.getSymbolColor(position: position),
                    onColorSelected: { color in
                        settings.setSymbolColor(position: position, color: color)
                        showingColorPicker = false
                    },
                    onCancel: {
                        showingColorPicker = false
                    }
                )
            }
        }
    }
    
    private func positionColorButton(position: Int) -> some View {
        Button(action: {
            selectedPosition = position
            showingColorPicker = true
        }) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(settings.getSymbolColor(position: position))
                    .frame(height: 60)
                    .overlay(
                        Text("\(position)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                Text(positionLabel(position))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func positionLabel(_ position: Int) -> String {
        switch position {
        case 1: return "Top Left"
        case 2: return "Top Right"
        case 3: return "Bottom Left"
        case 4: return "Bottom Right"
        case 5: return "Center"
        case 6: return "Position 6"
        case 7: return "Position 7"
        case 8: return "Position 8"
        case 9: return "Position 9"
        default: return "Position \(position)"
        }
    }
    
    private var layoutDescription: String {
        switch settings.symbolCount {
        case 1: return "1 symbol: Full screen"
        case 2: return "2 symbols: Left and Right"
        case 3: return "3 symbols: 2 top, 1 bottom"
        case 4: return "4 symbols: 2x2 grid"
        default: return "\(settings.symbolCount) symbols"
        }
    }
}

#Preview {
    NavigationStack {
        CVIDisplaySettingsView()
    }
}
