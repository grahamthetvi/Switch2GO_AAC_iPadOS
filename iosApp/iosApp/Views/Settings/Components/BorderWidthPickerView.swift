import SwiftUI

/// Border thickness picker with 6 options
struct BorderWidthPickerView: View {
    let selectedWidth: Float
    let onWidthSelected: (Float) -> Void
    let onCancel: () -> Void
    
    // 6 border width options (matching Android)
    private let widths: [(Float, String)] = [
        (0, "None"),
        (6, "Thin"),
        (10, "Medium"),
        (14, "Thick"),
        (20, "XL"),
        (28, "XXL")
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(widths, id: \.0) { width, label in
                    Button(action: {
                        onWidthSelected(width)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(label)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                // Visual preview
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: CGFloat(width))
                                    .frame(width: 100, height: 50)
                            }
                            
                            Spacer()
                            
                            if abs(selectedWidth - width) < 0.1 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Border Thickness")
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
    BorderWidthPickerView(
        selectedWidth: 6,
        onWidthSelected: { _ in },
        onCancel: {}
    )
}
