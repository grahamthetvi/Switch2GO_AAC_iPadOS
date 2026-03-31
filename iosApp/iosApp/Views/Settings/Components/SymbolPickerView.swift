import SwiftUI

/// Reusable SF Symbol picker for category icons
struct SymbolPickerView: View {
    let selectedSymbol: String
    let onSymbolSelected: (String) -> Void
    let onCancel: () -> Void
    
    // Curated SF Symbols suitable for AAC categories
    private let symbols: [String] = [
        "folder.fill", "star.fill", "heart.fill", "book.fill",
        "house.fill", "person.fill", "figure.stand", "figure.walk",
        "fork.knife", "cup.and.saucer.fill", "car.fill", "airplane",
        "gamecontroller.fill", "music.note", "paintbrush.fill",
        "checklist", "clock.fill", "clock.arrow.circlepath",
        "bell.fill", "envelope.fill", "phone.fill", "camera.fill",
        "lightbulb.fill", "bolt.fill", "drop.fill", "leaf.fill",
        "pawprint.fill", "fish.fill", "bird.fill",
        "hand.thumbsup.fill", "hand.thumbsdown.fill",
        "plus.circle.fill", "minus.circle.fill", "questionmark.circle.fill",
        "exclamationmark.circle.fill", "arrow.triangle.2.circlepath",
        "gearshape.fill", "wrench.and.screwdriver.fill",
        "cross.fill", "staroflife.fill", "bed.double.fill"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button(action: {
                            onSymbolSelected(symbol)
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: symbol)
                                    .font(.system(size: 32))
                                    .foregroundColor(.primary)
                                    .frame(width: 56, height: 56)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedSymbol == symbol ? Color.accentColor : Color.clear, lineWidth: 3)
                                    )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Select Icon")
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
}

#Preview {
    SymbolPickerView(
        selectedSymbol: "heart.fill",
        onSymbolSelected: { _ in },
        onCancel: {}
    )
}
