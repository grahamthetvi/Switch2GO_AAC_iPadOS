import SwiftUI

/// Categories Display Settings - Gateway to Edit Categories
struct CategoriesDisplaySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Manage categories and phrases")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            
            // Edit Categories & Phrases
            NavigationLink(destination: EditCategoriesListView()) {
                settingOption(
                    title: "Edit Categories & Phrases",
                    description: "Show, hide, reorder, and customize categories",
                    icon: "folder.fill.badge.gearshape",
                    color: .blue
                )
            }
            
            // CVI Display Settings
            NavigationLink(destination: CVIDisplaySettingsView()) {
                settingOption(
                    title: "CVI Display Settings",
                    description: "Adjust symbol count and colors",
                    icon: "square.grid.3x3.fill",
                    color: .purple
                )
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Categories Display")
        .navigationBarTitleDisplayMode(.large)
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
    
    private func settingOption(title: String, description: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        CategoriesDisplaySettingsView()
    }
}
