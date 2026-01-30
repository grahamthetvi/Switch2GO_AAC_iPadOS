import SwiftUI
import VocableShared

/// Main entry point for the Switch2Go iOS app.
/// This file should be set as the App entry point in Xcode project settings.
@main
struct Switch2GoApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

/// Global app state shared across views.
class AppState: ObservableObject {
    @Published var isCalibrated = false
    @Published var isTrackingEnabled = true
    @Published var selectedCategory: String?

    // Shared module instances
    let storage: Storage_
    let logger: Logger_

    init() {
        // Create platform implementations from shared module
        storage = StorageKt.createStorage()
        logger = LoggerKt.createLogger(tag: "Switch2Go")

        // Check if we have existing calibration
        isCalibrated = storage.loadBoolean(key: "hasCalibration", defaultValue: false)

        logger.info(message: "Switch2Go app initialized")
    }

    func markCalibrated() {
        isCalibrated = true
        storage.saveBoolean(key: "hasCalibration", value: true)
    }
}
