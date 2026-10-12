import SwiftUI

/// Empty state when all categories are hidden
struct EmptyCategoriesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text(l10n: "All categories are hidden")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(l10n: "Go to Settings to show categories")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            NavigationLink(destination: MainSettingsView()) {
                Label(L("Open Settings"), systemImage: "gear")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
}

#Preview {
    EmptyCategoriesView()
}
