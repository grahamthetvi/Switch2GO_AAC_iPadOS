import Foundation
import SwiftUI
import Combine

/// UserDefaults wrapper for app settings
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let symbolCount = "symbolCount"
        static let dwellTime = "dwellTime"
        static let sensitivity = "sensitivity"
        static let useGPU = "useGPU"
        static let trackingMode = "trackingMode"
        static let smoothingMode = "smoothingMode"
        static let eyeSelection = "eyeSelection"
        static let gazeAmplification = "gazeAmplification"
        static let enableOutOfBoundsHiding = "enableOutOfBoundsHiding"
        static let showTrackingErrorBanner = "showTrackingErrorBanner"
        static let enableDoubleBlinkRecenter = "enableDoubleBlinkRecenter"
        static let enableAutoRecenter = "enableAutoRecenter"
        static let headCameraPosition = "headCameraPosition"
        static let headCameraOffsetYaw = "headCameraOffsetYaw"
        static let headCameraOffsetPitch = "headCameraOffsetPitch"
        static let headSensitivityX = "headSensitivityX"
        static let headSensitivityY = "headSensitivityY"
        static let selectionMode = "selectionMode"
        static let appBorderColor = "appBorderColor"
        
        // Switch Control
        static let switchControlEnabled = "switchControlEnabled"
        static let switchControlMode = "switchControlMode"
        static let switchScanInterval = "switchScanInterval"
        static let switchAction1 = "switchAction1"
        static let switchAction2 = "switchAction2"
        static let switchAction3 = "switchAction3"
        static let switchAction4 = "switchAction4"
        static let switchAutoReconnect = "switchAutoReconnect"
        static let switchLastDeviceId = "switchLastDeviceId"
        
        // USB HID Key Mapping (HID usage codes)
        static let switchKey1 = "switchKey1"
        static let switchKey2 = "switchKey2"
        static let switchKey3 = "switchKey3"
        static let switchKey4 = "switchKey4"
        
        // Onboarding
        static let hasSeenOnboarding = "hasSeenOnboarding"
        
        // Per-position colors (9 positions)
        static func symbolColor(_ position: Int) -> String {
            return "symbolColor\(position)"
        }
    }
    
    // MARK: - CVI Display Settings
    
    /// Number of symbols to display per page (1-4)
    @Published var symbolCount: Int {
        didSet {
            defaults.set(symbolCount, forKey: Keys.symbolCount)
        }
    }
    
    /// Get color for symbol position (1-indexed, 1-4)
    func getSymbolColor(position: Int) -> Color {
        guard position >= 1 && position <= 4 else { return defaultColors[0] }
        
        if let colorValue = defaults.object(forKey: Keys.symbolColor(position)) as? UInt32 {
            return Color(hex: colorValue)
        }
        return defaultColors[position - 1]
    }
    
    /// Set color for symbol position (1-indexed, 1-4)
    func setSymbolColor(position: Int, color: Color) {
        guard position >= 1 && position <= 4 else { return }
        defaults.set(color.toHex(), forKey: Keys.symbolColor(position))
        objectWillChange.send()
    }
    
    /// Reset all colors to defaults
    func resetColorsToDefaults() {
        for position in 1...4 {
            defaults.removeObject(forKey: Keys.symbolColor(position))
        }
        objectWillChange.send()
    }
    
    // Default colors for each position (1-indexed)
    private let defaultColors: [Color] = [
        Color(hex: 0xFFE53935), // Red
        Color(hex: 0xFF1E88E5), // Blue
        Color(hex: 0xFF43A047), // Green
        Color(hex: 0xFFFB8C00), // Orange
        Color(hex: 0xFF8E24AA), // Purple
        Color(hex: 0xFF00ACC1), // Cyan
        Color(hex: 0xFFF06292), // Pink
        Color(hex: 0xFFFFEE58), // Yellow
        Color(hex: 0xFF78909C)  // Grey
    ]
    
    // MARK: - Eye Tracking Settings
    
    /// Dwell time in seconds (0.5 - 5.0)
    @Published var dwellTime: Double {
        didSet {
            defaults.set(dwellTime, forKey: Keys.dwellTime)
        }
    }
    
    /// Cursor sensitivity (0 = low, 1 = medium, 2 = high)
    @Published var sensitivity: Int {
        didSet {
            defaults.set(sensitivity, forKey: Keys.sensitivity)
        }
    }
    
    /// Use GPU acceleration for MediaPipe
    @Published var useGPU: Bool {
        didSet {
            defaults.set(useGPU, forKey: Keys.useGPU)
        }
    }
    
    /// Tracking mode: "2D" or "3D"
    @Published var trackingMode: String {
        didSet {
            defaults.set(trackingMode, forKey: Keys.trackingMode)
        }
    }
    
    /// Smoothing mode: "none", "simple", "kalman", "adaptive", "combined"
    @Published var smoothingMode: String {
        didSet {
            defaults.set(smoothingMode, forKey: Keys.smoothingMode)
        }
    }
    
    /// Eye selection: "both", "left", "right"
    @Published var eyeSelection: String {
        didSet {
            defaults.set(eyeSelection, forKey: Keys.eyeSelection)
        }
    }

    /// Gaze amplification (1.0x - 2.0x)
    @Published var gazeAmplification: Double {
        didSet {
            defaults.set(gazeAmplification, forKey: Keys.gazeAmplification)
        }
    }

    /// Hide cursor when gaze is out of bounds
    @Published var enableOutOfBoundsHiding: Bool {
        didSet {
            defaults.set(enableOutOfBoundsHiding, forKey: Keys.enableOutOfBoundsHiding)
        }
    }

    /// Show banner when tracking is lost
    @Published var showTrackingErrorBanner: Bool {
        didSet {
            defaults.set(showTrackingErrorBanner, forKey: Keys.showTrackingErrorBanner)
        }
    }

    /// Enable double-blink to recenter
    @Published var enableDoubleBlinkRecenter: Bool {
        didSet {
            defaults.set(enableDoubleBlinkRecenter, forKey: Keys.enableDoubleBlinkRecenter)
        }
    }

    /// Enable auto-recenter when gaze is centered
    @Published var enableAutoRecenter: Bool {
        didSet {
            defaults.set(enableAutoRecenter, forKey: Keys.enableAutoRecenter)
        }
    }

    // MARK: - Head Tracking Settings

    /// Camera position preset: "center", "left", "right", "custom"
    @Published var headCameraPosition: String {
        didSet {
            defaults.set(headCameraPosition, forKey: Keys.headCameraPosition)
        }
    }

    /// Stored neutral yaw offset from head pose calibration
    @Published var headCameraOffsetYaw: Double {
        didSet {
            defaults.set(headCameraOffsetYaw, forKey: Keys.headCameraOffsetYaw)
        }
    }

    /// Stored neutral pitch offset from head pose calibration
    @Published var headCameraOffsetPitch: Double {
        didSet {
            defaults.set(headCameraOffsetPitch, forKey: Keys.headCameraOffsetPitch)
        }
    }

    /// Head tracking horizontal sensitivity (1.0 - 4.0)
    @Published var headSensitivityX: Double {
        didSet {
            defaults.set(headSensitivityX, forKey: Keys.headSensitivityX)
        }
    }

    /// Head tracking vertical sensitivity (1.0 - 4.0)
    @Published var headSensitivityY: Double {
        didSet {
            defaults.set(headSensitivityY, forKey: Keys.headSensitivityY)
        }
    }

    /// Selection mode: "face", "eyeGaze", or "none"
    @Published var selectionMode: String {
        didSet {
            defaults.set(selectionMode, forKey: Keys.selectionMode)
        }
    }

    /// App border color
    @Published var appBorderColor: Color {
        didSet {
            defaults.set(appBorderColor.toHex(), forKey: Keys.appBorderColor)
        }
    }

    // MARK: - Switch Control Settings

    /// Whether external BLE switch control is enabled
    @Published var switchControlEnabled: Bool {
        didSet {
            defaults.set(switchControlEnabled, forKey: Keys.switchControlEnabled)
        }
    }

    /// Switch control mode: "direct" or "scanning"
    @Published var switchControlMode: String {
        didSet {
            defaults.set(switchControlMode, forKey: Keys.switchControlMode)
        }
    }

    /// Auto-scan interval in seconds (for scanning mode)
    @Published var switchScanInterval: Double {
        didSet {
            defaults.set(switchScanInterval, forKey: Keys.switchScanInterval)
        }
    }

    /// Action for switch 1 (default: "select")
    @Published var switchAction1: String {
        didSet {
            defaults.set(switchAction1, forKey: Keys.switchAction1)
        }
    }

    /// Action for switch 2 (default: "next")
    @Published var switchAction2: String {
        didSet {
            defaults.set(switchAction2, forKey: Keys.switchAction2)
        }
    }

    /// Action for switch 3 (default: "previous")
    @Published var switchAction3: String {
        didSet {
            defaults.set(switchAction3, forKey: Keys.switchAction3)
        }
    }

    /// Action for switch 4 (default: "back")
    @Published var switchAction4: String {
        didSet {
            defaults.set(switchAction4, forKey: Keys.switchAction4)
        }
    }

    /// Whether to auto-reconnect to the last switch device (legacy, kept for compatibility)
    @Published var switchAutoReconnect: Bool {
        didSet {
            defaults.set(switchAutoReconnect, forKey: Keys.switchAutoReconnect)
        }
    }

    /// UUID of the last connected switch device (legacy, kept for compatibility)
    @Published var switchLastDeviceId: String {
        didSet {
            defaults.set(switchLastDeviceId, forKey: Keys.switchLastDeviceId)
        }
    }

    /// HID usage code for switch 1 key (default: Space = 44)
    @Published var switchKey1: Int {
        didSet {
            defaults.set(switchKey1, forKey: Keys.switchKey1)
        }
    }

    /// HID usage code for switch 2 key (default: Right Arrow = 79)
    @Published var switchKey2: Int {
        didSet {
            defaults.set(switchKey2, forKey: Keys.switchKey2)
        }
    }

    /// HID usage code for switch 3 key (default: Left Arrow = 80)
    @Published var switchKey3: Int {
        didSet {
            defaults.set(switchKey3, forKey: Keys.switchKey3)
        }
    }

    /// HID usage code for switch 4 key (default: Escape = 41)
    @Published var switchKey4: Int {
        didSet {
            defaults.set(switchKey4, forKey: Keys.switchKey4)
        }
    }

    // MARK: - Onboarding

    /// Whether the user has seen the first-launch onboarding
    @Published var hasSeenOnboarding: Bool {
        didSet {
            defaults.set(hasSeenOnboarding, forKey: Keys.hasSeenOnboarding)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved values or use defaults
        self.symbolCount = defaults.object(forKey: Keys.symbolCount) as? Int ?? 2
        self.dwellTime = defaults.object(forKey: Keys.dwellTime) as? Double ?? 1.0
        self.sensitivity = defaults.object(forKey: Keys.sensitivity) as? Int ?? 1
        self.useGPU = defaults.object(forKey: Keys.useGPU) as? Bool ?? false
        self.trackingMode = defaults.string(forKey: Keys.trackingMode) ?? "2D"
        self.smoothingMode = defaults.string(forKey: Keys.smoothingMode) ?? "adaptive"
        self.eyeSelection = defaults.string(forKey: Keys.eyeSelection) ?? "both"
        self.gazeAmplification = defaults.object(forKey: Keys.gazeAmplification) as? Double ?? 1.0
        self.enableOutOfBoundsHiding = defaults.object(forKey: Keys.enableOutOfBoundsHiding) as? Bool ?? true
        self.showTrackingErrorBanner = defaults.object(forKey: Keys.showTrackingErrorBanner) as? Bool ?? true
        self.enableDoubleBlinkRecenter = defaults.object(forKey: Keys.enableDoubleBlinkRecenter) as? Bool ?? true
        self.enableAutoRecenter = defaults.object(forKey: Keys.enableAutoRecenter) as? Bool ?? true
        self.headCameraPosition = defaults.string(forKey: Keys.headCameraPosition) ?? "left"
        self.headCameraOffsetYaw = defaults.object(forKey: Keys.headCameraOffsetYaw) as? Double ?? 4.0
        self.headCameraOffsetPitch = defaults.object(forKey: Keys.headCameraOffsetPitch) as? Double ?? 0.0
        self.headSensitivityX = defaults.object(forKey: Keys.headSensitivityX) as? Double ?? 2.0
        self.headSensitivityY = defaults.object(forKey: Keys.headSensitivityY) as? Double ?? 2.5
        self.selectionMode = defaults.string(forKey: Keys.selectionMode) ?? "none"
        let borderHex = defaults.object(forKey: Keys.appBorderColor) as? UInt32 ?? 0xFF000000
        self.appBorderColor = Color(hex: borderHex)

        // Switch Control (Currently disabled - Coming Soon feature)
        self.switchControlEnabled = false
        defaults.set(false, forKey: Keys.switchControlEnabled)
        
        self.switchControlMode = defaults.string(forKey: Keys.switchControlMode) ?? "direct"
        self.switchScanInterval = defaults.object(forKey: Keys.switchScanInterval) as? Double ?? 1.5
        self.switchAction1 = defaults.string(forKey: Keys.switchAction1) ?? "select"
        self.switchAction2 = defaults.string(forKey: Keys.switchAction2) ?? "next"
        self.switchAction3 = defaults.string(forKey: Keys.switchAction3) ?? "previous"
        self.switchAction4 = defaults.string(forKey: Keys.switchAction4) ?? "back"
        self.switchAutoReconnect = defaults.object(forKey: Keys.switchAutoReconnect) as? Bool ?? true
        self.switchLastDeviceId = defaults.string(forKey: Keys.switchLastDeviceId) ?? ""
        self.switchKey1 = defaults.object(forKey: Keys.switchKey1) as? Int ?? 30  // Key "1"
        self.switchKey2 = defaults.object(forKey: Keys.switchKey2) as? Int ?? 31  // Key "2"
        self.switchKey3 = defaults.object(forKey: Keys.switchKey3) as? Int ?? 32  // Key "3"
        self.switchKey4 = defaults.object(forKey: Keys.switchKey4) as? Int ?? 33  // Key "4"

        // Onboarding
        self.hasSeenOnboarding = defaults.object(forKey: Keys.hasSeenOnboarding) as? Bool ?? false
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        symbolCount = 2
        hasSeenOnboarding = false
        dwellTime = 1.0
        sensitivity = 1
        useGPU = false
        trackingMode = "2D"
        smoothingMode = "adaptive"
        eyeSelection = "both"
        gazeAmplification = 1.0
        enableOutOfBoundsHiding = true
        showTrackingErrorBanner = true
        enableDoubleBlinkRecenter = true
        enableAutoRecenter = true
        headCameraPosition = "left"
        headCameraOffsetYaw = 4.0
        headCameraOffsetPitch = 0.0
        headSensitivityX = 2.0
        headSensitivityY = 2.5
        selectionMode = "none"
        appBorderColor = Color(hex: 0xFF000000)
        switchControlEnabled = false
        switchControlMode = "direct"
        switchScanInterval = 1.5
        switchAction1 = "select"
        switchAction2 = "next"
        switchAction3 = "previous"
        switchAction4 = "back"
        switchAutoReconnect = true
        switchLastDeviceId = ""
        switchKey1 = 30  // Key "1"
        switchKey2 = 31  // Key "2"
        switchKey3 = 32  // Key "3"
        switchKey4 = 33  // Key "4"
        resetColorsToDefaults()
    }
    /// Returns .dark when appBorderColor is dark (low luminance), .light otherwise.
    /// Use this to keep system text colors readable on top of the border background.
    var preferredColorScheme: ColorScheme {
        let cgColor = UIColor(appBorderColor).cgColor
        let components = cgColor.components ?? [0, 0, 0, 1]
        let r = cgColor.colorSpace?.model == .monochrome ? Double(components[0]) : Double(components[0])
        let g = cgColor.colorSpace?.model == .monochrome ? Double(components[0]) : (components.count > 1 ? Double(components[1]) : 0)
        let b = cgColor.colorSpace?.model == .monochrome ? Double(components[0]) : (components.count > 2 ? Double(components[2]) : 0)
        let luminance = (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
        return luminance > 0.6 ? .light : .dark
    }
}

// MARK: - Color Extensions

extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        let alpha = Double((hex >> 24) & 0xFF) / 255.0
        
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
    
    func toHex() -> UInt32 {
        let cgColor = UIColor(self).cgColor
        let components = cgColor.components ?? [0, 0, 0, 1]

        let r, g, b, a: Double
        if cgColor.colorSpace?.model == .monochrome {
            // Grayscale: components are [white, alpha]
            let white = Double(components[0])
            r = white; g = white; b = white
            a = components.count > 1 ? Double(components[1]) : 1.0
        } else {
            r = Double(components[0])
            g = components.count > 1 ? Double(components[1]) : 0
            b = components.count > 2 ? Double(components[2]) : 0
            a = components.count > 3 ? Double(components[3]) : 1.0
        }

        return (UInt32(a * 255) << 24) | (UInt32(r * 255) << 16) | (UInt32(g * 255) << 8) | UInt32(b * 255)
    }
}
