import SwiftUI

/// App border color settings
struct AppBorderColorView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction

    private let colors: [Color] = [
        Color(hex: 0xFFE53935),
        Color(hex: 0xFF1E88E5),
        Color(hex: 0xFF43A047),
        Color(hex: 0xFFFB8C00),
        Color(hex: 0xFF8E24AA),
        Color(hex: 0xFF00ACC1),
        Color(hex: 0xFFF06292),
        Color(hex: 0xFFFFEE58),
        Color(hex: 0xFF78909C),
        Color(hex: 0xFF26A69A),
        Color(hex: 0xFF795548),
        Color(hex: 0xFFCDDC39),
        Color(hex: 0xFF3F51B5),
        Color(hex: 0xFFFFC107),
        Color(hex: 0xFF673AB7),
        Color(hex: 0xFF000000),
        Color(hex: 0xFFFFFFFF),
        Color(hex: 0xFFD9D9D9),
        Color(hex: 0xFF4A4A4A)
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("App Border Color")
                .font(.title2)
                .fontWeight(.bold)

            RoundedRectangle(cornerRadius: 12)
                .stroke(settings.appBorderColor, lineWidth: 6)
                .frame(height: 120)
                .padding(.horizontal)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(colors.indices, id: \.self) { index in
                    let color = colors[index]
                    Button(action: {
                        settings.appBorderColor = color
                    }) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(color)
                            .frame(height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        isSelected(color) ? Color.primary : Color.clear,
                                        lineWidth: 4
                                    )
                            )
                    }
                    .accessibilityLabel("Border color option")
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .navigationTitle("Border Color")
        .navigationBarTitleDisplayMode(.inline)
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
    }

    private func isSelected(_ color: Color) -> Bool {
        settings.appBorderColor.toHex() == color.toHex()
    }
}

#Preview {
    NavigationStack {
        AppBorderColorView()
    }
}
