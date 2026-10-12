import SwiftUI
import VocableShared

/// QWERTY keyboard for custom phrase input
struct KeyboardView: View {
    @State private var inputText: String = ""
    @State private var showingSaveCategoryPicker = false
    @FocusState private var isSystemKeyboardFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    private let keys = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]
    
    private let specialKeys = ["'", ",", ".", "?"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Output preview
            VStack {
                TextField("Type a phrase", text: $inputText, axis: .vertical)
                    .font(.title)
                    .foregroundColor(inputText.isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding()
                    .focused($isSystemKeyboardFocused)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
            }
            
            Spacer()
            
            // Keyboard
            VStack(spacing: 8) {
                // Letter rows
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { key in
                            KeyButton(label: key) {
                                inputText += key.lowercased()
                            }
                        }
                    }
                }
                
                // Special characters row
                HStack(spacing: 8) {
                    ForEach(specialKeys, id: \.self) { key in
                        KeyButton(label: key) {
                            inputText += key
                        }
                    }
                }
                
                // Control keys
                HStack(spacing: 8) {
                    // Space
                    KeyButton(label: "Space", width: 200) {
                        inputText += " "
                    }
                    
                    // Backspace
                    KeyButton(label: "⌫", width: 80, color: .orange) {
                        if !inputText.isEmpty {
                            inputText.removeLast()
                        }
                    }
                    
                    // Clear
                    KeyButton(label: "Clear", width: 100, color: .red) {
                        inputText = ""
                    }
                }
            }
            .padding()
            
            // Save button
            Button(action: {
                showingSaveCategoryPicker = true
            }) {
                Text(l10n: "Save Phrase")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(inputText.isEmpty ? Color.gray : Color.green)
                    .cornerRadius(12)
            }
            .disabled(inputText.isEmpty)
            .padding()
        }
        .environment(\.layoutDirection, .leftToRight)
        .onAppear {
            isSystemKeyboardFocused = true
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(l10n: "Back")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSaveCategoryPicker) {
            SavePhraseToCategoryView(phraseText: inputText) {
                dismiss()
            }
        }
    }
}

/// Individual keyboard key button
struct KeyButton: View {
    let label: String
    var width: CGFloat? = nil
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: width ?? 60, height: 60)
                .background(color)
                .cornerRadius(10)
        }
    }
}

/// Category picker for saving custom phrase
struct SavePhraseToCategoryView: View {
    let phraseText: String
    let onSaved: () -> Void
    
    @StateObject private var viewModel = CategoriesViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.categories.filter { !$0.isPreset || $0.id == "preset_user_favorites" }) { category in
                    Button(action: {
                        savePhrase(to: category.id)
                    }) {
                        HStack {
                            Text(category.name)
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                }
            }
            .navigationTitle("Save to Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func savePhrase(to categoryId: String) {
        let database = DatabaseManager.shared.db
        let phraseId = "custom_\(UUID().uuidString)"
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        
        database.phraseQueries.insertPhrase(
            phrase_id: phraseId,
            parent_category_id: categoryId,
            creation_date: timestamp,
            last_spoken_date: nil,
            localized_utterance: phraseText,
            sort_order: 999,
            style: nil
        )
        dismiss()
        onSaved()
    }
}

#Preview {
    NavigationStack {
        KeyboardView()
    }
}
