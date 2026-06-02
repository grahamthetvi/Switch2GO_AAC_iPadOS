import SwiftUI

/// Banner shown when a game phrase is selected in an unsupported selection mode.
struct GameUnsupportedBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "gamecontroller")
                    .font(.title3)
                    .foregroundColor(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Button("Dismiss", action: onDismiss)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.red.opacity(0.88))
            .cornerRadius(12)
            .padding(.top, 20)
            .padding(.horizontal, 16)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(15)
    }
}
