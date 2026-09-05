import SwiftUI

/// Reset App with two-step confirmation
struct ResetAppView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    @State private var showingFirstConfirmation = false
    @State private var showingSecondConfirmation = false
    @State private var resetComplete = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("Reset App")
                .font(.title)
                .fontWeight(.bold)
            
            Text("This will delete all custom categories and phrases, and remove saved images and media. Preset data will be restored to defaults. This cannot be undone.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Text("This will reset:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    resetItem("All custom categories")
                    resetItem("All custom phrases")
                    resetItem("Custom images and media files")
                    resetItem("Symbol count to 2")
                    resetItem("Colors to defaults")
                    resetItem("All settings to defaults")
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            
            Spacer()
            
            Button(action: {
                showingFirstConfirmation = true
            }) {
                Text("Reset App")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("Reset App")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    settingsHomeAction?() ?? dismiss()
                }) {
                    Label("Home", systemImage: "house.fill")
                }
            }
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Are you sure?", isPresented: $showingFirstConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                showingSecondConfirmation = true
            }
        } message: {
            Text("All custom data will be permanently deleted.")
        }
        .alert("Really reset?", isPresented: $showingSecondConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Now", role: .destructive) {
                performReset()
            }
        } message: {
            Text("This is your last chance to cancel. All custom data will be lost forever.")
        }
        .alert("App Reset Complete", isPresented: $resetComplete) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("The app has been reset to defaults. All custom data has been removed.")
        }
    }
    
    private func resetItem(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark")
                .foregroundColor(.red)
                .font(.caption)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private func performReset() {
        // Reset database
        DatabaseManager.shared.resetToDefaults()
        
        // Reset settings
        AppSettings.shared.resetToDefaults()
        
        // Show completion
        resetComplete = true
    }
}

#Preview {
    NavigationStack {
        ResetAppView()
    }
}
