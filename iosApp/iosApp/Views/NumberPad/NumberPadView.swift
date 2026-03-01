import SwiftUI

/// Number pad view (0-9, Yes, No)
struct NumberPadView: View {
    @StateObject private var ttsManager = TTSManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private let numbers = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let spacing: CGFloat = 12
                let padding: CGFloat = 12
                let rows: CGFloat = 4
                let totalSpacing = spacing * (rows - 1)
                let availableHeight = geometry.size.height - totalSpacing - (padding * 2)
                let itemHeight = max(120, availableHeight / rows)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3), spacing: spacing) {
                    ForEach(numbers, id: \.self) { number in
                        NumberButton(number: number, height: itemHeight) {
                            ttsManager.speak(number)
                        }
                    }
                    
                    // Yes button
                    Button(action: {
                        ttsManager.speak("Yes")
                    }) {
                        Text("Yes")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: itemHeight)
                            .background(Color.green)
                            .cornerRadius(16)
                    }
                    
                    // No button
                    Button(action: {
                        ttsManager.speak("No")
                    }) {
                        Text("No")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: itemHeight)
                            .background(Color.red)
                            .cornerRadius(16)
                    }
                }
                .padding(padding)
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
    }
}

struct NumberButton: View {
    let number: String
    let height: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Color.blue)
                .cornerRadius(16)
                .shadow(radius: 4)
        }
        .accessibilityLabel("Number \(number)")
    }
}

#Preview {
    NavigationStack {
        NumberPadView()
    }
}
