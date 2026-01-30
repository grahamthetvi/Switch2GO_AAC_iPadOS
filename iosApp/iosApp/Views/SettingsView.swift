import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingCalibration = false
    @State private var dwellTime: Double = 1.0
    @State private var sensitivity: Double = 0.5

    var body: some View {
        Form {
            // Tracking Mode Section
            Section(header: Text("Tracking Mode")) {
                Toggle("Eye Tracking", isOn: $appState.isEyeTrackingEnabled)
                    .onChange(of: appState.isEyeTrackingEnabled) { _ in
                        appState.savePreferences()
                        if appState.isEyeTrackingEnabled {
                            appState.eyeTrackingManager.startTracking()
                        } else {
                            appState.eyeTrackingManager.stopTracking()
                        }
                    }

                Toggle("Head Tracking", isOn: $appState.isHeadTrackingEnabled)
                    .onChange(of: appState.isHeadTrackingEnabled) { _ in
                        appState.savePreferences()
                    }

                if appState.isEyeTrackingEnabled || appState.isHeadTrackingEnabled {
                    Button("Calibrate") {
                        showingCalibration = true
                    }
                    .foregroundColor(.blue)
                }
            }

            // Sensitivity Section
            Section(header: Text("Sensitivity")) {
                VStack(alignment: .leading) {
                    Text("Dwell Time: \(String(format: "%.1f", dwellTime))s")
                    Slider(value: $dwellTime, in: 0.5...3.0, step: 0.1)
                }

                VStack(alignment: .leading) {
                    Text("Pointer Sensitivity: \(Int(sensitivity * 100))%")
                    Slider(value: $sensitivity, in: 0.1...1.0, step: 0.1)
                }
            }

            // Voice Section
            Section(header: Text("Voice Settings")) {
                NavigationLink("Voice Selection") {
                    VoiceSettingsView()
                }

                NavigationLink("Speech Rate") {
                    SpeechRateView()
                }
            }

            // Appearance Section
            Section(header: Text("Appearance")) {
                NavigationLink("Button Size") {
                    ButtonSizeSettingsView()
                }

                NavigationLink("Color Theme") {
                    ThemeSettingsView()
                }
            }

            // My Phrases Section
            Section(header: Text("My Phrases")) {
                NavigationLink("Edit Categories") {
                    EditCategoriesView()
                }

                NavigationLink("Add Custom Phrases") {
                    AddPhrasesView()
                }
            }

            // About Section
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.gray)
                }

                NavigationLink("Privacy Policy") {
                    PrivacyPolicyView()
                }

                NavigationLink("Help & Support") {
                    HelpView()
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingCalibration) {
            CalibrationView()
        }
    }
}

// MARK: - Placeholder Views for Settings

struct VoiceSettingsView: View {
    var body: some View {
        List {
            Text("Samantha (Default)")
            Text("Alex")
            Text("Daniel")
            Text("Karen")
        }
        .navigationTitle("Voice Selection")
    }
}

struct SpeechRateView: View {
    @State private var rate: Double = 0.5

    var body: some View {
        Form {
            Section {
                VStack {
                    Text("Speech Rate: \(Int(rate * 100))%")
                    Slider(value: $rate, in: 0.1...1.0)
                }
            }

            Section {
                Button("Test Voice") {
                    // Test speech
                }
            }
        }
        .navigationTitle("Speech Rate")
    }
}

struct ButtonSizeSettingsView: View {
    var body: some View {
        List {
            Text("Small")
            Text("Medium")
            Text("Large")
            Text("Extra Large")
        }
        .navigationTitle("Button Size")
    }
}

struct ThemeSettingsView: View {
    var body: some View {
        List {
            Text("System Default")
            Text("Light")
            Text("Dark")
            Text("High Contrast")
        }
        .navigationTitle("Color Theme")
    }
}

struct EditCategoriesView: View {
    var body: some View {
        Text("Edit Categories - Coming Soon")
            .navigationTitle("Edit Categories")
    }
}

struct AddPhrasesView: View {
    var body: some View {
        Text("Add Custom Phrases - Coming Soon")
            .navigationTitle("Add Phrases")
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("""
            Privacy Policy for Switch2GO AAC

            This app processes camera data locally on your device for eye tracking functionality. No video or image data is transmitted or stored externally.

            Data Collection:
            - Camera access is used solely for eye and head tracking
            - All processing happens on-device
            - No personal data is collected or transmitted

            For questions, contact support.
            """)
            .padding()
        }
        .navigationTitle("Privacy Policy")
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section(header: Text("Getting Started")) {
                Text("1. Enable Eye Tracking in Settings")
                Text("2. Complete the calibration")
                Text("3. Use your eyes to select buttons")
            }

            Section(header: Text("Tips")) {
                Text("• Keep your device at a comfortable distance")
                Text("• Ensure good lighting conditions")
                Text("• Take breaks if your eyes feel tired")
            }
        }
        .navigationTitle("Help & Support")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
    }
}
