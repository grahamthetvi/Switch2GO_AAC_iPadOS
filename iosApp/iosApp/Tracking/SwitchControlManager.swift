import Foundation
import GameController
import Combine
import UIKit

// MARK: - Switch Event Model

/// A single switch press or release event from the USB HID device.
struct SwitchEvent {
    /// Which switch fired (0-3 maps to Switch 1-4)
    let switchIndex: Int

    /// True = pressed, false = released
    let isPress: Bool

    /// Timestamp of the event
    let timestamp: TimeInterval
}

/// Configurable action assigned to each physical switch.
enum SwitchAction: String, CaseIterable, Identifiable {
    case select   = "select"     // Activate hovered button
    case next     = "next"       // Move to next item (scanning)
    case previous = "previous"   // Move to previous item (scanning)
    case back     = "back"       // Go back / cancel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .select:   return "Select"
        case .next:     return "Next"
        case .previous: return "Previous"
        case .back:     return "Back"
        }
    }

    var systemImage: String {
        switch self {
        case .select:   return "hand.tap"
        case .next:     return "arrow.right"
        case .previous: return "arrow.left"
        case .back:     return "arrow.uturn.backward"
        }
    }
}

/// The mode in which switch control operates.
enum SwitchControlMode: String, CaseIterable, Identifiable {
    /// Switches work alongside eye/head tracking.
    /// Tracking moves the cursor, switch press activates the hovered button.
    case direct = "direct"

    /// Auto-step scanning: buttons are highlighted in sequence.
    /// Switch press selects the currently highlighted button.
    case scanning = "scanning"

    /// Direct mapping: each physical switch activates a specific phrase tile by position.
    /// Switch 1 → phrase 1 (top-left), Switch 2 → phrase 2, etc.
    case directMapping = "directMapping"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .direct:        return "Direct (with tracking)"
        case .scanning:      return "Auto-Scan"
        case .directMapping: return "Direct Switch-to-Phrase"
        }
    }
}

// MARK: - Key Mapping

/// Represents a keyboard key that can be mapped to a switch input.
/// Uses HID usage codes which map directly to GCKeyCode.rawValue.
struct SwitchKeyMapping: Equatable, Identifiable {
    let hidUsageCode: Int
    let displayName: String

    var id: Int { hidUsageCode }

    // Common keys for switch input
    static let space      = SwitchKeyMapping(hidUsageCode: 44, displayName: "Space")
    static let returnKey  = SwitchKeyMapping(hidUsageCode: 40, displayName: "Return")
    static let escape     = SwitchKeyMapping(hidUsageCode: 41, displayName: "Escape")
    static let tab        = SwitchKeyMapping(hidUsageCode: 43, displayName: "Tab")
    static let rightArrow = SwitchKeyMapping(hidUsageCode: 79, displayName: "→ Right Arrow")
    static let leftArrow  = SwitchKeyMapping(hidUsageCode: 80, displayName: "← Left Arrow")
    static let upArrow    = SwitchKeyMapping(hidUsageCode: 82, displayName: "↑ Up Arrow")
    static let downArrow  = SwitchKeyMapping(hidUsageCode: 81, displayName: "↓ Down Arrow")
    static let key1       = SwitchKeyMapping(hidUsageCode: 30, displayName: "1")
    static let key2       = SwitchKeyMapping(hidUsageCode: 31, displayName: "2")
    static let key3       = SwitchKeyMapping(hidUsageCode: 32, displayName: "3")
    static let key4       = SwitchKeyMapping(hidUsageCode: 33, displayName: "4")
    static let f1         = SwitchKeyMapping(hidUsageCode: 58, displayName: "F1")
    static let f2         = SwitchKeyMapping(hidUsageCode: 59, displayName: "F2")
    static let f3         = SwitchKeyMapping(hidUsageCode: 60, displayName: "F3")
    static let f4         = SwitchKeyMapping(hidUsageCode: 61, displayName: "F4")

    /// All available key mappings for the UI picker
    static let allMappings: [SwitchKeyMapping] = [
        .space, .returnKey, .escape, .tab,
        .rightArrow, .leftArrow, .upArrow, .downArrow,
        .key1, .key2, .key3, .key4,
        .f1, .f2, .f3, .f4
    ]

    /// Find a mapping by HID usage code
    static func from(hidUsageCode: Int) -> SwitchKeyMapping? {
        allMappings.first { $0.hidUsageCode == hidUsageCode }
    }

    /// Display name for a given HID code (with fallback)
    static func displayName(for hidCode: Int) -> String {
        from(hidUsageCode: hidCode)?.displayName ?? "Key \(hidCode)"
    }
}

// MARK: - SwitchControlManager

/// Manages USB HID keyboard input from a Raspberry Pi Zero 2 W (or any USB keyboard)
/// acting as a switch input device.
///
/// The Pi connects via USB and appears as a standard keyboard. When a physical switch
/// wired to the Pi's GPIO is pressed, the Pi sends a specific keypress. This manager
/// listens for those keypresses and maps them to switch actions.
///
/// Responsibilities:
/// - Detect USB keyboard connection via GameController framework
/// - Receive key press/release events
/// - Map configured keys to switch actions (select, next, previous, back)
/// - Provide scanning-mode auto-stepping through buttons
class SwitchControlManager: NSObject, ObservableObject {

    // MARK: - Published State

    /// Whether a USB keyboard/switch device is connected
    @Published var isConnected = false

    /// Name of the connected device
    @Published var connectedDeviceName: String?

    /// Number of switches (always 4 for USB HID mode)
    @Published var switchCount: Int = 4

    /// Most recent switch event (for UI feedback)
    @Published var lastSwitchEvent: SwitchEvent?

    /// The currently highlighted button ID in scanning mode
    @Published var scanHighlightedButtonId: String?

    // MARK: - Action Publishers

    /// Fires when a "select" action is triggered by any switch
    let selectAction = PassthroughSubject<Void, Never>()

    /// Fires when a "next" action is triggered
    let nextAction = PassthroughSubject<Void, Never>()

    /// Fires when a "previous" action is triggered
    let previousAction = PassthroughSubject<Void, Never>()

    /// Fires when a "back" action is triggered
    let backAction = PassthroughSubject<Void, Never>()

    /// Fires in directMapping mode with the button ID to activate (switch N → phrase N)
    let directActivateAction = PassthroughSubject<String, Never>()

    // MARK: - Configuration

    /// The control mode (direct, scanning, or directMapping)
    var controlMode: SwitchControlMode = .direct

    /// Action mapping for each switch (index 0-3 → action)
    var switchActions: [SwitchAction] = [.select, .next, .previous, .back]

    /// Kept for API compatibility with existing code
    var autoReconnect: Bool = true

    /// HID usage codes for each switch key (index 0-3)
    /// Default: Key "1" (30), Key "2" (31), Key "3" (32), Key "4" (33)
    /// These match the Raspberry Pi script which sends 0x1E, 0x1F, 0x20, 0x21
    var switchKeyHIDCodes: [Int] = [30, 31, 32, 33]

    // MARK: - Scanning Mode State

    /// Ordered list of button IDs for scanning and direct mapping modes
    private(set) var scanButtonIds: [String] = []

    /// Public read-only accessor for comparing button lists
    var currentScanButtonIds: [String] { scanButtonIds }

    /// Current index in the scanning order
    private var scanIndex: Int = 0

    /// Timer for auto-stepping in scanning mode
    private var scanTimer: Timer?

    /// Interval between auto-steps in scanning mode (seconds)
    var scanInterval: TimeInterval = 1.5

    // MARK: - Internal State

    private var isInitialized = false

    // MARK: - Initialization

    override init() {
        super.init()
    }

    /// Start listening for USB keyboard events.
    /// Call this when the app wants to enable switch control.
    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
        DebugLog.info("Switch control initializing — mode=\(controlMode.rawValue), keys=\(switchKeyHIDCodes)", tag: "Switch")
        setupKeyboardMonitoring()
    }

    /// Stop listening for keyboard events.
    /// Call this when switch control is disabled.
    func shutdown() {
        stopScanningMode()
        removeKeyboardMonitoring()
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedDeviceName = nil
        }
        isInitialized = false
    }

    // MARK: - Keyboard Monitoring (GameController Framework)

    private func setupKeyboardMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidConnect(_:)),
            name: .GCKeyboardDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidDisconnect(_:)),
            name: .GCKeyboardDidDisconnect,
            object: nil
        )

        // Check if a keyboard is already connected
        if let keyboard = GCKeyboard.coalesced {
            bindKeyboard(keyboard)
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectedDeviceName = "USB Switch Device"
            }
            DebugLog.info("USB keyboard already connected (GCKeyboard)", tag: "Switch")
        } else {
            DebugLog.info("No USB keyboard via GCKeyboard — waiting for connection. UIKit fallback will catch key events if device appears as keyboard.", tag: "Switch")
        }
        DebugLog.info("Switch key HID codes: \(switchKeyHIDCodes) (1=30, 2=31, 3=32, 4=33)", tag: "Switch")
    }

    private func removeKeyboardMonitoring() {
        NotificationCenter.default.removeObserver(self, name: .GCKeyboardDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: .GCKeyboardDidDisconnect, object: nil)
        GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = nil
    }

    @objc private func keyboardDidConnect(_ notification: Notification) {
        DebugLog.info("USB keyboard connected (GCKeyboard)", tag: "Switch")
        if let keyboard = GCKeyboard.coalesced {
            bindKeyboard(keyboard)
        }
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectedDeviceName = "USB Switch Device"
        }
    }

    @objc private func keyboardDidDisconnect(_ notification: Notification) {
        DebugLog.info("USB keyboard disconnected (GCKeyboard)", tag: "Switch")
        DispatchQueue.main.async {
            self.isConnected = (GCKeyboard.coalesced != nil)
            if !self.isConnected {
                self.connectedDeviceName = nil
            }
        }
    }

    private func bindKeyboard(_ keyboard: GCKeyboard) {
        keyboard.keyboardInput?.keyChangedHandler = { [weak self] _, _, keyCode, pressed in
            self?.handleKeyEvent(keyCode: keyCode, pressed: pressed)
        }
    }

    private func handleKeyEvent(keyCode: GCKeyCode, pressed: Bool) {
        let hidCode = Int(keyCode.rawValue)

        // Only process keys that are configured as switch inputs
        guard let switchIndex = switchKeyHIDCodes.firstIndex(of: hidCode) else {
            return
        }

        // Log switch key events for debugging
        let actionName = switchIndex < switchActions.count ? switchActions[switchIndex].displayName : "?"
        DebugLog.info("GCKeyboard: HID=\(hidCode) switch=\(switchIndex + 1) \(pressed ? "PRESS" : "release") → \(actionName)", tag: "Switch")

        // If we receive a valid switch key, the device is definitely connected.
        // This serves as a reliable fallback if GCKeyboard notifications didn't fire.
        if !isConnected {
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectedDeviceName = "USB Switch Device"
                DebugLog.info("Connection confirmed via GCKeyboard key event", tag: "Switch")
            }
        }

        let event = SwitchEvent(
            switchIndex: switchIndex,
            isPress: pressed,
            timestamp: CACurrentMediaTime()
        )
        processSwitchEvent(event)
    }

    // MARK: - Scanning Mode

    /// Set the ordered list of button IDs for scanning mode.
    func setScanButtons(_ buttonIds: [String]) {
        let changed = scanButtonIds != buttonIds
        scanButtonIds = buttonIds
        scanIndex = 0
        updateScanHighlight()
        if changed && !buttonIds.isEmpty {
            DebugLog.debug("Scan buttons updated: \(buttonIds.count) buttons", tag: "Switch")
        }
    }

    /// Start auto-stepping through buttons in scanning mode.
    func startScanningMode() {
        guard controlMode == .scanning, !scanButtonIds.isEmpty else { return }

        scanIndex = 0
        updateScanHighlight()
        DebugLog.info("Scanning started: \(scanButtonIds.count) buttons, interval=\(scanInterval)s", tag: "Switch")

        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanInterval, repeats: true) { [weak self] _ in
            self?.advanceScan()
        }
    }

    /// Stop scanning mode.
    func stopScanningMode() {
        scanTimer?.invalidate()
        scanTimer = nil
        scanHighlightedButtonId = nil
        DebugLog.debug("Scanning stopped", tag: "Switch")
    }

    private func advanceScan() {
        guard !scanButtonIds.isEmpty else { return }
        scanIndex = (scanIndex + 1) % scanButtonIds.count
        updateScanHighlight()
    }

    private func retreatScan() {
        guard !scanButtonIds.isEmpty else { return }
        scanIndex = (scanIndex - 1 + scanButtonIds.count) % scanButtonIds.count
        updateScanHighlight()
    }

    private func updateScanHighlight() {
        guard scanIndex < scanButtonIds.count else {
            scanHighlightedButtonId = nil
            return
        }
        scanHighlightedButtonId = scanButtonIds[scanIndex]
    }

    // MARK: - Switch Event Processing

    private func processSwitchEvent(_ event: SwitchEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.lastSwitchEvent = event
        }

        // Only act on press events (ignore release)
        guard event.isPress else { return }

        // Haptic feedback
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }

        // Direct Mapping mode: switch index maps directly to a phrase position
        if controlMode == .directMapping {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if event.switchIndex < self.scanButtonIds.count {
                    let buttonId = self.scanButtonIds[event.switchIndex]
                    DebugLog.info("Direct mapping: Switch \(event.switchIndex + 1) → \(buttonId)", tag: "Switch")
                    self.directActivateAction.send(buttonId)
                } else {
                    DebugLog.warn("Direct mapping: Switch \(event.switchIndex + 1) has no mapped phrase (only \(self.scanButtonIds.count) phrases visible)", tag: "Switch")
                }
            }
            return
        }

        // Standard action-based modes (direct + scanning)
        guard event.switchIndex < switchActions.count else { return }

        let action = switchActions[event.switchIndex]
        DebugLog.info("Switch \(event.switchIndex + 1) → \(action.displayName)", tag: "Switch")

        // Dispatch action
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            switch action {
            case .select:
                if self.controlMode == .scanning {
                    // In scanning mode, "select" activates the highlighted button
                    // Reset the scan timer so the user has time to see the result
                    self.scanTimer?.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.startScanningMode()
                    }
                }
                self.selectAction.send()

            case .next:
                if self.controlMode == .scanning {
                    self.advanceScan()
                    // Reset auto-step timer
                    self.scanTimer?.invalidate()
                    self.scanTimer = Timer.scheduledTimer(
                        withTimeInterval: self.scanInterval,
                        repeats: true
                    ) { [weak self] _ in self?.advanceScan() }
                }
                self.nextAction.send()

            case .previous:
                if self.controlMode == .scanning {
                    self.retreatScan()
                    self.scanTimer?.invalidate()
                    self.scanTimer = Timer.scheduledTimer(
                        withTimeInterval: self.scanInterval,
                        repeats: true
                    ) { [weak self] _ in self?.advanceScan() }
                }
                self.previousAction.send()

            case .back:
                self.backAction.send()
            }
        }
    }

    // MARK: - UIKit Key Press Fallback

    /// Called by KeyPressInterceptorViewController when a hardware key is pressed
    /// through the UIKit responder chain. This is a fallback in case GCKeyboard
    /// doesn't detect the USB HID device.
    func handleUIKitKeyPress(hidUsageCode: Int, pressed: Bool) {
        guard let switchIndex = switchKeyHIDCodes.firstIndex(of: hidUsageCode) else {
            // Only log for keys that could be from a switch (1-4=30-33, Space=44, etc.)
            let switchLikeHIDs = [30, 31, 32, 33, 40, 41, 43, 44]
            if switchLikeHIDs.contains(hidUsageCode) {
                DebugLog.debug("UIKit: HID=\(hidUsageCode) not in configured list \(switchKeyHIDCodes) — check Settings → Switch Control key mapping", tag: "Switch")
            }
            return
        }

        let actionName = switchIndex < switchActions.count ? switchActions[switchIndex].displayName : "?"
        DebugLog.info("UIKit fallback: HID=\(hidUsageCode) switch=\(switchIndex + 1) \(pressed ? "PRESS" : "release") → \(actionName)", tag: "Switch")

        // Mark connected on first valid key event
        if !isConnected {
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectedDeviceName = "USB Switch Device"
                DebugLog.info("Connection confirmed via UIKit key event (GCKeyboard may not see this device)", tag: "Switch")
            }
        }

        let event = SwitchEvent(
            switchIndex: switchIndex,
            isPress: pressed,
            timestamp: CACurrentMediaTime()
        )
        processSwitchEvent(event)
    }
}

// MARK: - UIKit Key Press Interceptor

/// A transparent UIViewController that captures hardware key presses through
/// the UIKit responder chain. This provides a reliable fallback for USB HID
/// keyboards that may not be detected by the GameController framework.
///
/// Embed this in the SwiftUI view hierarchy using KeyPressInterceptorView.
class KeyPressInterceptorViewController: UIViewController {
    /// Map of UIKeyboardHIDUsage raw values to their integer HID usage codes
    weak var switchManager: SwitchControlManager?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let becameFirst = becomeFirstResponder()
        DebugLog.debug("KeyPressInterceptor: viewDidAppear, becomeFirstResponder=\(becameFirst)", tag: "Switch")
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let key = press.key {
                let hidCode = Int(key.keyCode.rawValue)
                if switchManager?.switchKeyHIDCodes.contains(hidCode) == true {
                    switchManager?.handleUIKitKeyPress(hidUsageCode: hidCode, pressed: true)
                    handled = true
                }
            }
        }
        if !handled {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let key = press.key {
                let hidCode = Int(key.keyCode.rawValue)
                if switchManager?.switchKeyHIDCodes.contains(hidCode) == true {
                    switchManager?.handleUIKitKeyPress(hidUsageCode: hidCode, pressed: false)
                    handled = true
                }
            }
        }
        if !handled {
            super.pressesEnded(presses, with: event)
        }
    }
}

