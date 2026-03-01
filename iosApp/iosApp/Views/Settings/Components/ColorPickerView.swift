import SwiftUI

/// Reusable color picker with 19 preset colors
struct ColorPickerView: View {
    let selectedColor: Color
    let onColorSelected: (Color) -> Void
    let onCancel: () -> Void
    
    // 19 preset colors matching Android
    private let colors: [Color] = [
        Color(hex: 0xFFE53935), // Red
        Color(hex: 0xFF1E88E5), // Blue
        Color(hex: 0xFF43A047), // Green
        Color(hex: 0xFFFB8C00), // Orange
        Color(hex: 0xFF8E24AA), // Purple
        Color(hex: 0xFF00ACC1), // Cyan
        Color(hex: 0xFFF06292), // Pink
        Color(hex: 0xFFFFEE58), // Yellow
        Color(hex: 0xFF78909C), // Grey
        Color(hex: 0xFF26A69A), // Teal
        Color(hex: 0xFF795548), // Brown
        Color(hex: 0xFFCDDC39), // Lime
        Color(hex: 0xFF3F51B5), // Indigo
        Color(hex: 0xFFFFC107), // Amber
        Color(hex: 0xFF673AB7), // Deep Purple
        Color(hex: 0xFF000000), // Black
        Color(hex: 0xFFFFFFFF), // White
        Color(hex: 0xFFD9D9D9), // Light Gray
        Color(hex: 0xFF4A4A4A)  // Dark Gray
    ]
    
    private let colorNames: [String] = [
        "Red", "Blue", "Green", "Orange", "Purple", "Cyan",
        "Pink", "Yellow", "Grey", "Teal", "Brown", "Lime",
        "Indigo", "Amber", "Deep Purple", "Black", "White",
        "Light Gray", "Dark Gray"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                        Button(action: {
                            onColorSelected(color)
                        }) {
                            VStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(color)
                                    .frame(height: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.primary, lineWidth: isSelected(color) ? 4 : 0)
                                    )
                                    .overlay(
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .opacity(isSelected(color) ? 1 : 0)
                                    )
                                
                                Text(colorNames[index])
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Select Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    private func isSelected(_ color: Color) -> Bool {
        return color.toHex() == selectedColor.toHex()
    }
}

#Preview {
    ColorPickerView(
        selectedColor: Color(hex: 0xFFE53935),
        onColorSelected: { _ in },
        onCancel: {}
    )
}
