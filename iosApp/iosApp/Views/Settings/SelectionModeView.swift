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

                SelectionModeButton(
                    title: "Arm Raise Selection",
                    description: "Raise your left or right arm to choose the left or right phrase (2-symbol layout)",
                    icon: "figure.wave",
                    isSelected: settings.selectionMode == "armRaise"
                ) {
                    settings.selectionMode = "armRaise"
                }

                SelectionModeButton(
                    title: "Hand Gesture Selection",
                    description: "Open then close your left or right hand to choose the matching phrase (2-symbol layout)",
                    icon: "hand.raised",
                    isSelected: settings.selectionMode == "handGesture"
                ) {
                    settings.selectionMode = "handGesture"
                }

                // No Tracking Option
                SelectionModeButton(
                    title: "Touch Only",
                    description: "Use touch only, no head or eye tracking",
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
                            .foregroundColor(.blue)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Switch Control")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("ESP32 Bluetooth switches — scan or direct phrase")
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
        .scrollContentBackground(.hidden)
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
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
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var currentModeLabel: String {
        switch settings.selectionMode {
        case "face": return "Head Tracking"
        case "armRaise": return "Arm Raise Selection"
        case "handGesture": return "Hand Gesture Selection"
        case "none": return "Touch Only"
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
