import SwiftUI

/// Emoji keyboard for selecting emojis as phrase icons
struct EmojiKeyboardView: View {
    let onEmojiSelected: (String) -> Void
    let onCancel: () -> Void
    
    @State private var emojiText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter an emoji to use as the phrase icon")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                TextField("Tap to enter emoji", text: $emojiText)
                    .font(.system(size: 60))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .focused($isTextFieldFocused)
                    .onAppear {
                        isTextFieldFocused = true
                    }
                
                Text("Use your device's emoji keyboard")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    let trimmed = emojiText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onEmojiSelected(trimmed)
                    }
                }) {
                    Text("Use This Emoji")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(emojiText.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(emojiText.isEmpty)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Emoji Picker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

#Preview {
    EmojiKeyboardView(
        onEmojiSelected: { _ in },
        onCancel: {}
    )
}
