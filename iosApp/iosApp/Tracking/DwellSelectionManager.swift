import SwiftUI
import Combine

/// Shared SwiftUI coordinate space for gaze cursor rendering and dwell hit-testing.
enum GazeCoordinateSpace {
    static let name = "gaze"
}

/// Manages dwell-based selection: when the gaze cursor stays on a button
/// long enough, that button is activated.
///
/// Also supports switch-based instant selection and scanning-mode highlighting.
///
/// Usage:
/// 1. Register button frames via `registerButton(id:frame:)`
/// 2. Feed gaze positions via `updateGazePosition(_:)`
/// 3. Observe `hoveredButtonId` and `dwellProgress` for UI
/// 4. Listen to `lastActivation` / `activationToken` for selection events
/// 5. Call `activateHoveredButton()` for instant switch-based selection
///
/// One dwell/switch activation event (token + button id published together).
struct DwellActivation: Equatable {
    let token: UInt64
    let buttonId: String
}

/// Manages dwell-based selection for gaze, switch, and scanning input.
class DwellSelectionManager: ObservableObject {
    /// The button currently being hovered over (nil if none)
    @Published var hoveredButtonId: String?

    /// Dwell progress for the hovered button (0.0 to 1.0)
    @Published var dwellProgress: Double = 0

    /// Whether the current hover has already triggered an activation
    @Published var hasActivatedCurrentDwell: Bool = false

    /// Fires when a button is activated by dwell or switch press
    @Published var activatedButtonId: String?

    /// Increments on every activation so observers reliably receive events even when
    /// `activatedButtonId` repeats or LazyVGrid/TabView recycles child views.
    @Published private(set) var activationToken: UInt64 = 0

    /// Atomic activation snapshot so observers never race `activatedButtonId`
    /// being cleared by a subsequent `startDwell` before they handle the event.
    @Published private(set) var lastActivation: DwellActivation?

    /// The button highlighted in scanning mode (nil if not scanning)
    @Published var scanHighlightedButtonId: String?

    /// Whether dwell selection is enabled
    var isEnabled: Bool = true

    /// When set, only these button IDs participate in hit-testing and activation.
    /// Used during fullscreen media playback to ignore phrase tiles behind the overlay.
    private(set) var allowedButtonIds: Set<String>?

    // Registered button frames (id -> frame in GazeCoordinateSpace)
    private var buttonFrames: [String: CGRect] = [:]

    // Ordered list of button IDs (for scanning mode)
    private var orderedButtonIds: [String] = []

    // Dwell timing
    private var dwellStartTime: TimeInterval?
    private var dwellTimer: Timer?
    private var lastUpdateTime: TimeInterval = 0

    // Configuration — generous values to tolerate gaze jitter (especially at screen edges)
    private let dwellUpdateInterval: TimeInterval = 1.0 / 30.0  // 30 FPS UI updates
    private let exitMargin: CGFloat = 35.0   // Pixels of margin before exiting a button (was 20)
    private let hitTestPadding: CGFloat = 16.0 // Extra padding on hit-test frames for gaze noise (was 8)

    // Cooldown after activation to prevent re-triggering
    private var lastActivationTime: TimeInterval = 0
    private let activationCooldown: TimeInterval = 0.5

    // Grace period: when the cursor briefly leaves a button, don't reset
    // the dwell immediately — gaze jitter can cause momentary exits.
    private var exitGraceTimer: Timer?
    private let exitGracePeriod: TimeInterval = 0.25  // 250ms grace (was 150ms) — helps top-left/edge tiles

    // Switch control integration
    private var switchCancellables = Set<AnyCancellable>()

    // Debug: throttle dwell progress logs
    private var lastDwellDebugTime: TimeInterval = 0

    init() {}

    // MARK: - Button Registration

    /// Restrict hit-testing to a subset of buttons (nil = all registered buttons).
    func setAllowedButtonIds(_ ids: Set<String>?) {
        allowedButtonIds = ids
        if let ids {
            for id in buttonFrames.keys where !ids.contains(id) {
                unregisterButton(id: id)
            }
        }
        if let hovered = hoveredButtonId, !isButtonAllowed(hovered) {
            cancelDwell()
        }
    }

    /// Register a button's frame for hit-testing.
    /// Call this from a GeometryReader in each button's overlay.
    /// Ignores zero-size frames (layout not yet complete).
    func registerButton(id: String, frame: CGRect) {
        guard frame.width > 1 && frame.height > 1 else { return }
        guard isButtonAllowed(id) else {
            if buttonFrames[id] != nil {
                unregisterButton(id: id)
            }
            return
        }
        let isNew = buttonFrames[id] == nil
        buttonFrames[id] = frame
        if isNew {
            orderedButtonIds.append(id)
        }
    }

    /// Remove a button's registration (e.g., when view disappears).
    func unregisterButton(id: String) {
        buttonFrames.removeValue(forKey: id)
        orderedButtonIds.removeAll { $0 == id }
        if hoveredButtonId == id {
            cancelDwell()
        }
    }

    /// Clear all registered buttons (e.g., when leaving a screen).
    func clearAllButtons() {
        buttonFrames.removeAll()
        orderedButtonIds.removeAll()
        cancelDwell()
    }

    /// Remove buttons whose IDs start with the given prefix (e.g. "cat_" when opening phrases).
    func unregisterButtons(withPrefix prefix: String) {
        for id in buttonFrames.keys where id.hasPrefix(prefix) {
            unregisterButton(id: id)
        }
    }

    /// Reset in-progress dwell after orientation changes without clearing registered frames.
    /// Frames update in place via each button's GeometryReader as SwiftUI relayouts.
    func cancelDwellForLayoutChange() {
        cancelDwell()
    }

    // MARK: - Gaze Position Updates

    /// Update with the current gaze cursor position.
    /// Call this whenever gazePosition changes.
    func updateGazePosition(_ position: CGPoint) {
        guard isEnabled else {
            if hoveredButtonId != nil { cancelDwell() }
            return
        }

        let now = CACurrentMediaTime()

        // Cooldown after activation — only block re-activation, not hover tracking.
        let inActivationCooldown = now - lastActivationTime < activationCooldown

        // Walk registration order (matches web) so overlapping padded regions pick predictably.
        let hitButtonId = orderedButtonIds.first { id in
            guard isButtonAllowed(id), let frame = buttonFrames[id] else { return false }
            return frame.insetBy(dx: -hitTestPadding, dy: -hitTestPadding).contains(position)
        }

        if let hitId = hitButtonId {
            // Cursor is on a button — cancel any pending exit grace timer
            exitGraceTimer?.invalidate()
            exitGraceTimer = nil

            if hitId == hoveredButtonId {
                // Still on the same button — update progress
                if !inActivationCooldown || !hasActivatedCurrentDwell {
                    updateDwellProgress(now: now)
                }
            } else {
                // Moved to a different button
                DebugLog.debug("Dwell: entered \(hitId)", tag: "Dwell")
                startDwell(buttonId: hitId, now: now)
            }
        } else {
            // Not directly on any button
            if let currentId = hoveredButtonId,
               let frame = buttonFrames[currentId] {
                // Check with a larger exit margin to avoid flicker at edges
                let expandedFrame = frame.insetBy(dx: -exitMargin, dy: -exitMargin)
                if expandedFrame.contains(position) {
                    // Still within exit margin — keep dwelling, don't reset
                    if !inActivationCooldown || !hasActivatedCurrentDwell {
                        updateDwellProgress(now: now)
                    }
                } else if exitGraceTimer == nil {
                    // Just exited — start grace period before cancelling.
                    // This prevents jitter-caused resets: if the cursor returns
                    // within grace period the dwell continues uninterrupted.
                    exitGraceTimer = Timer.scheduledTimer(withTimeInterval: exitGracePeriod, repeats: false) { [weak self] _ in
                        self?.exitGraceTimer = nil
                        DebugLog.debug("Dwell: cancelled (exited outside margin)", tag: "Dwell")
                        self?.cancelDwell()
                    }
                }
                // else: grace timer already running, just wait
            } else {
                cancelDwell()
            }
        }
    }

    // MARK: - Dwell Logic

    private func startDwell(buttonId: String, now: TimeInterval) {
        hoveredButtonId = buttonId
        dwellStartTime = now
        dwellProgress = 0
        hasActivatedCurrentDwell = false
        activatedButtonId = nil  // Clear previous activation
    }

    private func updateDwellProgress(now: TimeInterval) {
        guard let startTime = dwellStartTime else { return }

        let dwellTime = AppSettings.shared.dwellTime
        let elapsed = now - startTime
        
        // If we've already activated and repeat is enabled, we use the repeat delay instead
        let targetTime = hasActivatedCurrentDwell ? AppSettings.shared.repeatDwellDelay : dwellTime
        let progress = min(elapsed / targetTime, 1.0)
        
        dwellProgress = progress

        // Debug: log progress every 1s while dwelling (helps diagnose jitter vs hit-test issues)
        if now - lastDwellDebugTime >= 1.0 {
            lastDwellDebugTime = now
            DebugLog.debug("Dwell: progress=\(String(format: "%.0f", progress * 100))% on \(hoveredButtonId ?? "?")", tag: "Dwell")
        }

        if progress >= 1.0 {
            if !hasActivatedCurrentDwell {
                // First activation
                hasActivatedCurrentDwell = true
                activateCurrentButton()
                
                if AppSettings.shared.enableRepeatDwell {
                    // Reset start time to now to start the repeat delay countdown
                    dwellStartTime = now
                    dwellProgress = 0
                }
            } else if AppSettings.shared.enableRepeatDwell {
                // Repeat activation
                activateCurrentButton()
                // Reset start time to now to start the next repeat delay countdown
                dwellStartTime = now
                dwellProgress = 0
            }
        }
    }

    private func activateCurrentButton() {
        guard let buttonId = hoveredButtonId else { return }

        let now = CACurrentMediaTime()
        guard now - lastActivationTime >= activationCooldown else { return }

        publishActivation(buttonId: buttonId, hapticStyle: .medium)
    }

    /// Record an activation and notify observers (haptic optional).
    private func publishActivation(buttonId: String, hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle?) {
        activationToken &+= 1
        let activation = DwellActivation(token: activationToken, buttonId: buttonId)
        DebugLog.debug("Dwell: activated \(buttonId) (token=\(activation.token))", tag: "Dwell")
        // Keep legacy fields for existing observers, then publish the atomic
        // snapshot last so `$lastActivation` subscribers always see a matching id.
        activatedButtonId = buttonId
        lastActivation = activation
        lastActivationTime = CACurrentMediaTime()

        if let hapticStyle {
            let generator = UIImpactFeedbackGenerator(style: hapticStyle)
            generator.impactOccurred()
        }
    }

    private func cancelDwell() {
        exitGraceTimer?.invalidate()
        exitGraceTimer = nil
        hoveredButtonId = nil
        dwellStartTime = nil
        dwellProgress = 0
        hasActivatedCurrentDwell = false
    }

    // MARK: - Reset

    func reset() {
        cancelDwell()
        activatedButtonId = nil
        lastActivationTime = 0
    }

    // MARK: - Switch Control Integration
    /// Scanning mode: select switch activates the scan-highlighted phrase.
    /// Direct phrase mode: each switch activates a phrase by grid position.
    func bindSwitchControl(_ switchManager: SwitchControlManager) {
        switchCancellables.removeAll()

        // Scanning mode: select switch activates highlighted phrase
        switchManager.selectAction
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.activateFromSwitch(switchManager: switchManager)
            }
            .store(in: &switchCancellables)

        // Scanning mode highlight sync
        switchManager.$scanHighlightedButtonId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] buttonId in
                self?.scanHighlightedButtonId = buttonId
            }
            .store(in: &switchCancellables)

        // Direct mapping mode → activate a specific button by ID
        switchManager.directActivateAction
            .receive(on: DispatchQueue.main)
            .sink { [weak self] buttonId in
                self?.activateButtonById(buttonId)
            }
            .store(in: &switchCancellables)
    }

    /// Unbind from a switch control manager.
    func unbindSwitchControl() {
        switchCancellables.removeAll()
        scanHighlightedButtonId = nil
    }

    /// Instantly activate a button from a switch press.
    private func activateFromSwitch(switchManager: SwitchControlManager) {
        let now = CACurrentMediaTime()
        guard now - lastActivationTime >= activationCooldown else { return }

        guard switchManager.controlMode == .scanning,
              let id = scanHighlightedButtonId else { return }

        publishActivation(buttonId: id, hapticStyle: .heavy)
        
        if id == hoveredButtonId {
            hasActivatedCurrentDwell = true
        }
    }

    /// Instantly activate a specific button by ID (for direct mapping mode).
    private func activateButtonById(_ buttonId: String) {
        let now = CACurrentMediaTime()
        guard now - lastActivationTime >= activationCooldown else { return }
        // Only activate if this button is actually registered on screen
        guard buttonFrames[buttonId] != nil, isButtonAllowed(buttonId) else {
            DebugLog.debug("Button \(buttonId) not on screen — ignoring direct activate", tag: "Dwell")
            return
        }

        publishActivation(buttonId: buttonId, hapticStyle: .heavy)
        
        if buttonId == hoveredButtonId {
            hasActivatedCurrentDwell = true
        }
    }

    /// Instantly activate the currently hovered button (for external callers).
    func activateHoveredButton() {
        let now = CACurrentMediaTime()
        guard now - lastActivationTime >= activationCooldown else { return }
        guard let buttonId = hoveredButtonId, isButtonAllowed(buttonId) else { return }

        publishActivation(buttonId: buttonId, hapticStyle: .heavy)
        hasActivatedCurrentDwell = true
    }

    /// Get the ordered list of registered button IDs (for scanning mode).
    func getOrderedButtonIds() -> [String] {
        if let allowedButtonIds {
            return orderedButtonIds.filter { allowedButtonIds.contains($0) }
        }
        return orderedButtonIds
    }

    private func isButtonAllowed(_ id: String) -> Bool {
        guard let allowedButtonIds else { return true }
        return allowedButtonIds.contains(id)
    }
}

// MARK: - Dwell Selection View Modifier

/// Attach this to any button to make it dwell-selectable.
/// It registers the button's frame and shows dwell progress.
///
/// Uses a short retry timer on appear to handle lazy containers (e.g. TabView)
/// where the frame may be zero on the initial layout pass.
struct DwellSelectableModifier: ViewModifier {
    let id: String
    @ObservedObject var dwellManager: DwellSelectionManager
    var isActive: Bool = true
    let onActivate: () -> Void

    private var isHovered: Bool { dwellManager.hoveredButtonId == id }
    private var isScanHighlighted: Bool { dwellManager.scanHighlightedButtonId == id }

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            registerIfValid(geo: geo)
                        }
                        .onChange(of: geo.frame(in: .named(GazeCoordinateSpace.name))) { _, newFrame in
                            guard isActive else { return }
                            dwellManager.registerButton(id: id, frame: newFrame)
                        }
                        .onChange(of: isActive) { _, active in
                            if active {
                                registerIfValid(geo: geo)
                            } else {
                                dwellManager.unregisterButton(id: id)
                            }
                        }
                        .onReceive(
                            Timer.publish(every: 0.1, on: .main, in: .common)
                                .autoconnect()
                        ) { _ in
                            if isActive {
                                registerIfValid(geo: geo)
                            }
                        }
                }
            )
            .overlay(
                ZStack {
                    // Dwell progress ring (gaze-based dwell)
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            Color.blue,
                            lineWidth: isHovered ? 4 : 0
                        )
                        .opacity(isHovered ? dwellManager.dwellProgress : 0)
                        .animation(.easeInOut(duration: 0.1), value: isHovered)

                    // Scanning mode highlight ring
                    if isScanHighlighted {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.orange, lineWidth: 4)
                            .animation(.easeInOut(duration: 0.2), value: isScanHighlighted)
                    }
                }
            )
            .scaleEffect((isHovered || isScanHighlighted) ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered || isScanHighlighted)
            .onChange(of: dwellManager.lastActivation) { _, activation in
                guard let activation, activation.buttonId == id else { return }
                onActivate()
            }
            .onDisappear {
                dwellManager.unregisterButton(id: id)
            }
    }

    private func registerIfValid(geo: GeometryProxy) {
        guard isActive else { return }
        let frame = geo.frame(in: .named(GazeCoordinateSpace.name))
        if frame.width > 1 && frame.height > 1 {
            dwellManager.registerButton(id: id, frame: frame)
        }
    }
}

extension View {
    /// Make a view dwell-selectable with the given ID.
    func dwellSelectable(
        id: String,
        manager: DwellSelectionManager,
        isActive: Bool = true,
        onActivate: @escaping () -> Void
    ) -> some View {
        modifier(
            DwellSelectableModifier(
                id: id,
                dwellManager: manager,
                isActive: isActive,
                onActivate: onActivate
            )
        )
    }
}
