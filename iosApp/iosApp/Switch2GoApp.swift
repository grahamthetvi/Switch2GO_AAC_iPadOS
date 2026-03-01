import SwiftUI
import VocableShared
import Combine
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
    @Published var isCalibrated = true
    @Published var isTrackingEnabled = true
    @Published var selectedCategory: String?
    @Published var initializationError: String?

    // Shared module instances
    let storage: Storage
    let logger: Logger
    let database: VocableDatabase

    init() {
        // Create platform implementations from shared module
        storage = StorageKt.createStorage()
        logger = LoggerKt.createLogger(tag: "Switch2Go")
        
        // Initialize database (will auto-populate presets on first launch)
        database = DatabaseManager.shared.db

        // Calibration is not required for iOS app flow
        isCalibrated = true

        logger.info(message: "Switch2Go app initialized with database")
    }

    func markCalibrated() {
        isCalibrated = true
        storage.saveBoolean(key: "hasCalibration", value: true)
    }
}
