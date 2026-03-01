import SwiftUI

/// Empty state when no phrases have been spoken
struct EmptyRecentsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("No recent phrases")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select phrases to see them here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    EmptyRecentsView()
}
