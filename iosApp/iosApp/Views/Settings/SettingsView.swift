import SwiftUI
import VocableShared

/// App settings view.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var isTrackingEnabled = true
    @State private var dwellDuration: Double = 1.0
    @State private var pointerSize: Double = 30
    @State private var showPointer = true
    @State private var selectedVoice = "Default"
    @State private var speechRate: Double = 0.5

    let voices = ["Default", "Samantha", "Alex", "Victoria"]

    var body: some View {
        NavigationStack {
            Form {
                // Eye Tracking Section
                Section("Eye Tracking") {
                    Toggle("Enable Eye Tracking", isOn: $isTrackingEnabled)
                        .onChange(of: isTrackingEnabled) { _, newValue in
                            appState.isTrackingEnabled = newValue
                        }

                    if isTrackingEnabled {
                        Toggle("Show Gaze Pointer", isOn: $showPointer)

                        VStack(alignment: .leading) {
                            Text("Pointer Size: \(Int(pointerSize))pt")
                            Slider(value: $pointerSize, in: 20...60, step: 5)
                        }

                        VStack(alignment: .leading) {
                            Text("Dwell Duration: \(String(format: "%.1f", dwellDuration))s")
                            Slider(value: $dwellDuration, in: 0.5...2.0, step: 0.1)
                        }

                        NavigationLink("Recalibrate") {
                            CalibrationView()
                                .environmentObject(appState)
                        }
                    }
                }

                // Speech Section
                Section("Speech") {
                    Picker("Voice", selection: $selectedVoice) {
                        ForEach(voices, id: \.self) { voice in
                            Text(voice).tag(voice)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Speech Rate")
                        Slider(value: $speechRate, in: 0.1...1.0, step: 0.1)
                    }
                }

                // Appearance Section
                Section("Appearance") {
                    NavigationLink("Grid Layout") {
                        GridLayoutSettingsView()
                    }

                    NavigationLink("Colors") {
                        ColorSettingsView()
                    }

                    NavigationLink("Text Size") {
                        TextSizeSettingsView()
                    }
                }

                // Phrases Section
                Section("Phrases") {
                    NavigationLink("Manage Categories") {
                        CategoriesSettingsView()
                    }

                    NavigationLink("My Saved Phrases") {
                        SavedPhrasesView()
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)

                    Link("Report an Issue", destination: URL(string: "https://github.com/grahamthetvi/Switch2GO_AAC_iPadOS/issues")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }

    private func loadSettings() {
        isTrackingEnabled = appState.storage.loadBoolean(key: "trackingEnabled", defaultValue: true)
        dwellDuration = Double(appState.storage.loadFloat(key: "dwellDuration", defaultValue: 1.0))
        pointerSize = Double(appState.storage.loadFloat(key: "pointerSize", defaultValue: 30))
        showPointer = appState.storage.loadBoolean(key: "showPointer", defaultValue: true)
        selectedVoice = appState.storage.loadString(key: "voice", defaultValue: "Default")
        speechRate = Double(appState.storage.loadFloat(key: "speechRate", defaultValue: 0.5))
    }

    private func saveSettings() {
        appState.storage.saveBoolean(key: "trackingEnabled", value: isTrackingEnabled)
        appState.storage.saveFloat(key: "dwellDuration", value: Float(dwellDuration))
        appState.storage.saveFloat(key: "pointerSize", value: Float(pointerSize))
        appState.storage.saveBoolean(key: "showPointer", value: showPointer)
        appState.storage.saveString(key: "voice", value: selectedVoice)
        appState.storage.saveFloat(key: "speechRate", value: Float(speechRate))
    }
}

// MARK: - Placeholder Settings Views

struct GridLayoutSettingsView: View {
    var body: some View {
        Form {
            Section("Grid Size") {
                // TODO: Implement grid layout options
                Text("Grid layout settings will be implemented here")
            }
        }
        .navigationTitle("Grid Layout")
    }
}

struct ColorSettingsView: View {
    var body: some View {
        Form {
            Section("Color Scheme") {
                // TODO: Implement color settings
                Text("Color settings for CVI accessibility")
            }
        }
        .navigationTitle("Colors")
    }
}

struct TextSizeSettingsView: View {
    var body: some View {
        Form {
            Section("Text Size") {
                // TODO: Implement text size settings
                Text("Text size settings")
            }
        }
        .navigationTitle("Text Size")
    }
}

struct CategoriesSettingsView: View {
    var body: some View {
        Form {
            Section("Categories") {
                // TODO: Implement categories management
                Text("Category management")
            }
        }
        .navigationTitle("Categories")
    }
}

struct SavedPhrasesView: View {
    var body: some View {
        Form {
            Section("Saved Phrases") {
                // TODO: Implement saved phrases
                Text("Saved phrases management")
            }
        }
        .navigationTitle("My Phrases")
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
