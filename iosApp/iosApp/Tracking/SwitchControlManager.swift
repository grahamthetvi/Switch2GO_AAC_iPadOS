import Foundation
import GameController
import Combine
import UIKit

// MARK: - Models

/// A normalized switch press from the ESP32 BLE HID keyboard.
struct SwitchEvent: Equatable {
    /// Zero-based index (scanning: 0 = select, 1 = next; direct phrase: phrase slot).
    let switchIndex: Int
    let isPress: Bool
    let timestamp: TimeInterval
}

/// How external switches interact with the phrase grid.
enum SwitchControlMode: String, CaseIterable, Identifiable {
    /// Two switches: one advances the highlight, one selects (optional auto-scan).
    case scanning = "scanning"
    /// Two to four switches: each switch activates one phrase tile by position.
    case directPhrase = "directPhrase"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .scanning: return "Scan & Select"
        case .directPhrase: return "Switch to Phrase"
        }
    }

    var detail: String {
        switch self {
        case .scanning:
            return "Use 2 switches to move a highlight across phrases, then select. Works with or without auto-scan."
        case .directPhrase:
            return "Use 2–4 switches; each switch speaks the phrase in that grid position."
        }
    }

    var systemImage: String {
        switch self {
        case .scanning: return "arrow.right.arrow.left"
        case .directPhrase: return "square.grid.2x2"
        }
    }

    /// Migrates legacy persisted mode strings.
    static func migrated(from raw: String?) -> SwitchControlMode {
        switch raw {
        case "scanning": return .scanning
        case "directPhrase", "directMapping": return .directPhrase
        case "direct": return .scanning
        default: return .directPhrase
        }
    }
}

/// Runtime configuration pushed from `AppSettings`.
struct SwitchControlConfiguration: Equatable {
    var mode: SwitchControlMode = .directPhrase
    var scanInterval: TimeInterval = 1.5
    /// Phrases on screen (2–4); limits active switches in direct phrase mode.
    var phraseSlotCount: Int = 2
    /// Scanning: HID code for the select switch (default key "1").
    var scanSelectKeyHID: Int = 30
    /// Scanning: HID code for the next switch (default key "2").
    var scanNextKeyHID: Int = 31
    /// Direct phrase: HID codes for slots 1–4 (default keys "1"–"4").
    var phraseKeyHIDs: [Int] = [30, 31, 32, 33]

    static let minPhraseSlots = 2
    static let maxPhraseSlots = 4
    static let scanningSwitchCount = 2

    var clampedPhraseSlotCount: Int {
        min(max(phraseSlotCount, Self.minPhraseSlots), Self.maxPhraseSlots)
    }

    /// HID codes the app listens for in the current mode.
    var activeKeyHIDs: [Int] {
        switch mode {
        case .scanning:
            return [scanSelectKeyHID, scanNextKeyHID]
        case .directPhrase:
            return Array(phraseKeyHIDs.prefix(clampedPhraseSlotCount))
        }
    }
}

/// Keyboard key mapping for settings UI (HID usage → label).
struct SwitchKeyMapping: Equatable, Identifiable {
    let hidUsageCode: Int
    let displayName: String

    var id: Int { hidUsageCode }

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

    static let allMappings: [SwitchKeyMapping] = [
        .space, .returnKey, .escape, .tab,
        .rightArrow, .leftArrow, .upArrow, .downArrow,
        .key1, .key2, .key3, .key4,
        .f1, .f2, .f3, .f4
    ]

    static func from(hidUsageCode: Int) -> SwitchKeyMapping? {
        allMappings.first { $0.hidUsageCode == hidUsageCode }
    }

    static func displayName(for hidCode: Int) -> String {
        from(hidUsageCode: hidCode)?.displayName ?? "Key \(hidCode)"
    }
}

// MARK: - SwitchControlManager

/// Listens for ESP32 BLE HID keyboard switch input (keys 1–4) and drives phrase selection.
///
/// Supported modes:
/// - **Scanning** (2 switches): select + next, with optional auto-scan highlight.
/// - **Direct phrase** (2–4 switches): switch N activates phrase slot N.
final class SwitchControlManager: NSObject, ObservableObject {

    // MARK: - Published

    @Published private(set) var isConnected = false
    @Published private(set) var connectedDeviceName: String?
    @Published private(set) var lastSwitchEvent: SwitchEvent?
    @Published private(set) var scanHighlightedButtonId: String?

    // MARK: - Configuration

    private(set) var configuration = SwitchControlConfiguration()

    var controlMode: SwitchControlMode {
        get { configuration.mode }
        set { configuration.mode = newValue }
    }

    var currentScanButtonIds: [String] { phraseButtonIds }

    // MARK: - Outputs

    /// Scanning mode: user pressed the select switch.
    let selectAction = PassthroughSubject<Void, Never>()

    /// Direct phrase mode: activate the phrase button with this ID.
    let directActivateAction = PassthroughSubject<String, Never>()

    // MARK: - Scanning state

    private var phraseButtonIds: [String] = []
    private var scanIndex = 0
    private var scanTimer: Timer?
    private var lastScanAdvanceTime: TimeInterval = 0
    private var lastScanSelectTime: TimeInterval = 0

    // MARK: - Input

    private var isListening = false
    /// Deduplicate GCKeyboard + UIKit delivering the same HID event.
    private var lastHIDKey: (code: Int, pressed: Bool, time: TimeInterval)?
    static let hidDedupeWindow: TimeInterval = 0.05
    static let scanActionDebounce: TimeInterval = 0.05

    // MARK: - Lifecycle

    func apply(configuration newConfig: SwitchControlConfiguration) {
        let modeChanged = configuration.mode != newConfig.mode
        let intervalChanged = configuration.scanInterval != newConfig.scanInterval
        configuration = newConfig

        switch configuration.mode {
        case .scanning:
            if modeChanged || intervalChanged {
                restartScanTimerIfNeeded()
            }
        case .directPhrase:
            if modeChanged {
                stopScanning()
            }
        }
    }

    func initialize() {
        guard !isListening else { return }
        isListening = true
        DebugLog.info(
            "Switch control on — mode=\(configuration.mode.rawValue), keys=\(configuration.activeKeyHIDs)",
            tag: "Switch"
        )
        installKeyboardObservers()
    }

    func shutdown() {
        stopScanning()
        removeKeyboardObservers()
        isListening = false
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedDeviceName = nil
        }
    }

    // MARK: - Phrase list (scanning + direct phrase)

    func setPhraseButtons(_ buttonIds: [String]) {
        let changed = phraseButtonIds != buttonIds
        phraseButtonIds = buttonIds
        scanIndex = min(scanIndex, max(buttonIds.count - 1, 0))
        updateScanHighlight()
        if changed, !buttonIds.isEmpty {
            DebugLog.debug("Phrase buttons updated: \(buttonIds.count)", tag: "Switch")
        }
    }

    func startScanning() {
        guard configuration.mode == .scanning, !phraseButtonIds.isEmpty else { return }
        scanIndex = 0
        updateScanHighlight()
        restartScanTimerIfNeeded()
        DebugLog.info(
            "Scanning started: \(phraseButtonIds.count) phrases, interval=\(configuration.scanInterval)s",
            tag: "Switch"
        )
    }

    func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
        DispatchQueue.main.async {
            self.scanHighlightedButtonId = nil
        }
    }

    // MARK: - Keyboard (Game Controller + UIKit fallback)

    private func installKeyboardObservers() {
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

        if let keyboard = GCKeyboard.coalesced {
            bindKeyboard(keyboard)
            markConnected()
        }

        DebugLog.info("Listening for HID keys: \(configuration.activeKeyHIDs)", tag: "Switch")
    }

    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: .GCKeyboardDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: .GCKeyboardDidDisconnect, object: nil)
        GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = nil
    }

    @objc private func keyboardDidConnect(_ notification: Notification) {
        if let keyboard = GCKeyboard.coalesced {
            bindKeyboard(keyboard)
        }
        markConnected()
    }

    @objc private func keyboardDidDisconnect(_ notification: Notification) {
        DispatchQueue.main.async {
            self.isConnected = GCKeyboard.coalesced != nil
            if !self.isConnected {
                self.connectedDeviceName = nil
            }
        }
    }

    private func bindKeyboard(_ keyboard: GCKeyboard) {
        keyboard.keyboardInput?.keyChangedHandler = { [weak self] _, _, keyCode, pressed in
            self?.handleHIDKey(Int(keyCode.rawValue), pressed: pressed, source: "GCKeyboard")
        }
    }

    func handleUIKitKeyPress(hidUsageCode: Int, pressed: Bool) {
        // Prefer GCKeyboard when available; UIKit is the ESP32 fallback.
        if GCKeyboard.coalesced != nil {
            return
        }
        handleHIDKey(hidUsageCode, pressed: pressed, source: "UIKit")
    }

    /// Returns true if this event should be ignored as a duplicate of a recent one.
    static func isDuplicateHIDEvent(
        code: Int,
        pressed: Bool,
        now: TimeInterval,
        previous: (code: Int, pressed: Bool, time: TimeInterval)?,
        window: TimeInterval = hidDedupeWindow
    ) -> Bool {
        guard let previous else { return false }
        return previous.code == code
            && previous.pressed == pressed
            && now - previous.time < window
    }

    private func handleHIDKey(_ hidCode: Int, pressed: Bool, source: String) {
        guard let switchIndex = configuration.activeKeyHIDs.firstIndex(of: hidCode) else { return }

        let now = CACurrentMediaTime()
        if Self.isDuplicateHIDEvent(code: hidCode, pressed: pressed, now: now, previous: lastHIDKey) {
            DebugLog.debug("Ignoring duplicate HID \(hidCode) from \(source)", tag: "Switch")
            return
        }
        lastHIDKey = (hidCode, pressed, now)

        markConnected()

        let event = SwitchEvent(
            switchIndex: switchIndex,
            isPress: pressed,
            timestamp: now
        )

        let role = roleLabel(for: switchIndex)
        DebugLog.info(
            "\(source): HID=\(hidCode) \(pressed ? "PRESS" : "release") → \(role)",
            tag: "Switch"
        )

        DispatchQueue.main.async {
            self.lastSwitchEvent = event
        }

        guard pressed else { return }

        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        dispatchPress(switchIndex: switchIndex)
    }

    private func dispatchPress(switchIndex: Int) {
        switch configuration.mode {
        case .scanning:
            handleScanningPress(switchIndex: switchIndex)
        case .directPhrase:
            handleDirectPhrasePress(switchIndex: switchIndex)
        }
    }

    private func handleScanningPress(switchIndex: Int) {
        guard switchIndex < SwitchControlConfiguration.scanningSwitchCount else { return }

        let now = CACurrentMediaTime()
        if switchIndex == 0 {
            if now - lastScanSelectTime < Self.scanActionDebounce { return }
            lastScanSelectTime = now
            pauseScanTimerBriefly()
            DispatchQueue.main.async {
                self.selectAction.send()
            }
        } else if switchIndex == 1 {
            DispatchQueue.main.async {
                self.advanceScan(fromUser: true)
            }
        }
    }

    private func handleDirectPhrasePress(switchIndex: Int) {
        guard switchIndex < configuration.clampedPhraseSlotCount,
              switchIndex < phraseButtonIds.count else {
            DebugLog.warn(
                "Direct phrase: slot \(switchIndex + 1) has no phrase (count=\(phraseButtonIds.count))",
                tag: "Switch"
            )
            return
        }
        let buttonId = phraseButtonIds[switchIndex]
        DebugLog.info("Direct phrase: slot \(switchIndex + 1) → \(buttonId)", tag: "Switch")
        DispatchQueue.main.async {
            self.directActivateAction.send(buttonId)
        }
    }

    // MARK: - Scan timer

    private func restartScanTimerIfNeeded() {
        guard configuration.mode == .scanning, !phraseButtonIds.isEmpty else { return }
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: configuration.scanInterval, repeats: true) { [weak self] _ in
            self?.advanceScan(fromUser: false)
        }
    }

    private func pauseScanTimerBriefly() {
        scanTimer?.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.restartScanTimerIfNeeded()
        }
    }

    private func advanceScan(fromUser _: Bool) {
        guard !phraseButtonIds.isEmpty else { return }
        let now = CACurrentMediaTime()
        // Debounce so a dual-path key press (or key + timer) cannot skip a tile.
        if now - lastScanAdvanceTime < Self.scanActionDebounce {
            return
        }
        lastScanAdvanceTime = now
        scanIndex = (scanIndex + 1) % phraseButtonIds.count
        updateScanHighlight()
        restartScanTimerIfNeeded()
    }

    private func updateScanHighlight() {
        guard configuration.mode == .scanning, scanIndex < phraseButtonIds.count else {
            DispatchQueue.main.async { self.scanHighlightedButtonId = nil }
            return
        }
        DispatchQueue.main.async {
            self.scanHighlightedButtonId = self.phraseButtonIds[self.scanIndex]
        }
    }

    // MARK: - Helpers

    private func markConnected() {
        guard !isConnected else { return }
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectedDeviceName = "Switch2GO"
        }
    }

    func roleLabel(for switchIndex: Int) -> String {
        switch configuration.mode {
        case .scanning:
            return switchIndex == 0 ? "Select" : "Next"
        case .directPhrase:
            return "Phrase \(switchIndex + 1)"
        }
    }

    func lastEventDescription(for event: SwitchEvent) -> String {
        guard event.isPress else { return "" }
        return "Last press: \(roleLabel(for: event.switchIndex))"
    }
}

// MARK: - UIKit key interceptor

final class KeyPressInterceptorViewController: UIViewController {
    weak var switchManager: SwitchControlManager?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = becomeFirstResponder()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if handlePresses(presses, pressed: true) { return }
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if handlePresses(presses, pressed: false) { return }
        super.pressesEnded(presses, with: event)
    }

    private func handlePresses(_ presses: Set<UIPress>, pressed: Bool) -> Bool {
        guard let manager = switchManager else { return false }
        var handled = false
        for press in presses {
            guard let key = press.key else { continue }
            let hidCode = Int(key.keyCode.rawValue)
            if manager.configuration.activeKeyHIDs.contains(hidCode) {
                manager.handleUIKitKeyPress(hidUsageCode: hidCode, pressed: pressed)
                handled = true
            }
        }
        return handled
    }
}
