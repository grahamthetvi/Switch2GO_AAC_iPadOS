import SwiftUI

/// Empty state when custom category has no phrases
struct EmptyPhrasesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("No phrases yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add phrases to this category from Settings")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            NavigationLink(destination: KeyboardView()) {
                Label("Add Phrase", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 300)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
}

#Preview {
    EmptyPhrasesView()
}
