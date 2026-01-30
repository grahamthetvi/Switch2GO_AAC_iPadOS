import SwiftUI
import VocableShared

@main
struct Switch2GOApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

/// Global app state shared across views
class AppState: ObservableObject {
    @Published var isEyeTrackingEnabled: Bool = false
    @Published var isHeadTrackingEnabled: Bool = false
    @Published var selectedCategory: String? = nil
    @Published var currentPhrase: String = ""

    // Eye tracking manager (uses VocableShared KMP framework)
    let eyeTrackingManager = EyeTrackingManager()

    init() {
        // Initialize with saved preferences
        isEyeTrackingEnabled = UserDefaults.standard.bool(forKey: "eyeTrackingEnabled")
        isHeadTrackingEnabled = UserDefaults.standard.bool(forKey: "headTrackingEnabled")
    }

    func savePreferences() {
        UserDefaults.standard.set(isEyeTrackingEnabled, forKey: "eyeTrackingEnabled")
        UserDefaults.standard.set(isHeadTrackingEnabled, forKey: "headTrackingEnabled")
    }
}
