import SwiftUI

/// Selection mode settings - Face Tracking vs Eye Gaze, plus Switch Control toggle
struct SelectionModeView: View {
    @EnvironmentObject var gazeManager: GazeTrackingManager
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Choose how you want to control the app")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                // Face Tracking Option
                SelectionModeButton(
                    title: "Head Tracking",
                    description: "Use head movements to control the cursor",
                    icon: "face.smiling",
                    isSelected: settings.selectionMode == "face"
                ) {
                    settings.selectionMode = "face"
                }
                
                // Eye Gaze Option
                SelectionModeButton(
                    title: "Eye Gaze Tracking",
                    description: "Use eye movements to control the cursor (more precise)",
                    icon: "eye",
                    isSelected: settings.selectionMode == "eyeGaze"
                ) {
                    settings.selectionMode = "eyeGaze"
                }

                // No Tracking Option
                SelectionModeButton(
                    title: "No Tracking (Touch & Switch)",
                    description: "Use touch or switch control only, no head or eye tracking",
                    icon: "hand.tap",
                    isSelected: settings.selectionMode == "none"
                ) {
                    settings.selectionMode = "none"
                }

                Divider()
                    .padding(.horizontal)

                // MARK: - Switch Control

                NavigationLink(destination: SwitchControlSettingsView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "keyboard")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("USB Switch Control")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Coming Soon")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                            Text("Support for Tapio and compatible USB switches is in development")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .disabled(true)
                .opacity(0.6)
                
                // Current Status
                VStack(spacing: 8) {
                    Text("Current Mode:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(currentModeLabel)
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Selection Mode")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    settingsHomeAction?() ?? dismiss()
                }) {
                    Label("Home", systemImage: "house.fill")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var currentModeLabel: String {
        switch settings.selectionMode {
        case "face": return "Head Tracking"
        case "none": return "No Tracking"
        default: return "Eye Gaze Tracking"
        }
    }
}

struct SelectionModeButton: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.largeTitle)
                        .foregroundColor(isSelected ? .white : .blue)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(radius: isSelected ? 6 : 2)
        }
    }
}

#Preview {
    NavigationStack {
        SelectionModeView()
            .environmentObject(GazeTrackingManager())
    }
}
