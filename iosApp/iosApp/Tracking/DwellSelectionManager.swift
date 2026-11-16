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
    private let postActivationBorderInset: CGFloat = 14.0 // Border band that releases hover after activation when repeat dwell is off

    // Cooldown after activation to prevent re-triggering
    private var lastActivationTime: TimeInterval = 0
    private let activationCooldown: TimeInterval = 0.5

    // Grace period: when the cursor briefly leaves a button, don't reset
    // the dwell immediately — gaze jitter can cause momentary exits.
    private var exitGraceTimer: Timer?
    private let exitGracePeriod: TimeInterval = 0.25  // 250ms grace (was 150ms) — helps top-left/edge tiles

    // Tracks a button whose hover was released while in its outer border / padded halo
    // after activation (with repeat dwell disabled), requiring re-entry into its interior
    // before starting a new dwell on that same button.
    private var releasedAfterActivationButtonId: String?

    // Switch control integration
    private var switchCancellables = Set<AnyCancellable>()

    // Debug: throttle dwell progress logs
    private var lastDwellDebugTime: TimeInterval = 0

    init() {}

    deinit {
        dwellTimer?.invalidate()
        exitGraceTimer?.invalidate()
    }

    // MARK: - Button Registration

    /// Restrict hit-testing to a subset of buttons (nil = all registered buttons).
    /// Preserves underlying button registrations and ordering so dismissing an overlay
    /// immediately restores phrase hit-testing and switch scanning order.
    func setAllowedButtonIds(_ ids: Set<String>?) {
        allowedButtonIds = ids
        if let hovered = hoveredButtonId, !isButtonAllowed(hovered) {
            cancelDwell()
        }
    }

    /// Register a button's frame for hit-testing.
    /// Call this from a GeometryReader in each button's overlay.
    /// Ignores zero-size frames (layout not yet complete).
    func registerButton(id: String, frame: CGRect) {
        guard frame.width > 1 && frame.height > 1 else { return }
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
        if releasedAfterActivationButtonId == id {
            releasedAfterActivationButtonId = nil
        }
        if hoveredButtonId == id {
            cancelDwell()
        }
    }

    /// Clear all registered buttons (e.g., when leaving a screen).
    func clearAllButtons() {
        buttonFrames.removeAll()
        orderedButtonIds.removeAll()
        releasedAfterActivationButtonId = nil
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
        releasedAfterActivationButtonId = nil
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
        let hitButtonId = resolveHitButtonId(at: position)

        if let hitId = hitButtonId {
            // Cursor is on a button — cancel any pending exit grace timer
            exitGraceTimer?.invalidate()
            exitGraceTimer = nil

            if hitId == hoveredButtonId {
                // Still on the same button — update progress
                updateDwellProgress(now: now)
            } else {
                // Moved to a different button (or re-entered interior after look-away)
                releasedAfterActivationButtonId = nil
                DebugLog.debug("Dwell: entered \(hitId)", tag: "Dwell")
                startDwell(buttonId: hitId, now: now)
            }
        } else {
            // Not directly on any button
            if let currentId = hoveredButtonId,
               isButtonAllowed(currentId),
               let frame = buttonFrames[currentId] {
                // If already activated and repeat dwell is disabled, release hover
                // quickly once the cursor leaves the tile's interior core so the user
                // can glance toward any screen edge or inter-tile gap (even on 1-tile
                // and 2-tile CVI grids with 12pt outer margins) and look back to repeat.
                let holdWithExitMargin = !hasActivatedCurrentDwell || AppSettings.shared.enableRepeatDwell
                let retentionFrame = holdWithExitMargin
                    ? frame.insetBy(dx: -exitMargin, dy: -exitMargin)
                    : postActivationRetentionFrame(for: frame)
                if holdWithExitMargin && retentionFrame.contains(position) {
                    // Returned within exit margin — cancel any pending exit grace timer
                    // and continue dwelling uninterrupted.
                    exitGraceTimer?.invalidate()
                    exitGraceTimer = nil
                    updateDwellProgress(now: now)
                } else if exitGraceTimer == nil {
                    // Just exited — start grace period before cancelling.
                    // This prevents jitter-caused resets: if the cursor returns
                    // within grace period the dwell continues uninterrupted.
                    let grace = holdWithExitMargin ? exitGracePeriod : 0.08
                    let releasingPostActivationId = holdWithExitMargin ? nil : currentId
                    let timer = Timer(timeInterval: grace, repeats: false) { [weak self] _ in
                        guard let self else { return }
                        self.exitGraceTimer = nil
                        if let releasingPostActivationId {
                            self.releasedAfterActivationButtonId = releasingPostActivationId
                        }
                        DebugLog.debug("Dwell: cancelled (exited outside margin)", tag: "Dwell")
                        self.cancelDwell()
                    }
                    RunLoop.main.add(timer, forMode: .common)
                    exitGraceTimer = timer
                }
                // else: grace timer already running, just wait
            } else {
                cancelDwell()
            }
        }
    }

    private func postActivationRetentionFrame(for frame: CGRect) -> CGRect {
        let insetX = min(postActivationBorderInset, max(0, frame.width * 0.15))
        let insetY = min(postActivationBorderInset, max(0, frame.height * 0.15))
        return frame.insetBy(dx: insetX, dy: insetY)
    }

    /// Resolves which button is hit by `position`, applying hysteresis so adjacent
    /// buttons with overlapping `hitTestPadding` (16pt padding vs 12pt grid spacing)
    /// cannot steal focus from the currently hovered button or from an unpadded interior hit.
    private func resolveHitButtonId(at position: CGPoint) -> String? {
        let isPostActivationSingleDwell = hasActivatedCurrentDwell && !AppSettings.shared.enableRepeatDwell

        // 1. Hysteresis for the currently hovered button:
        //    - While actively dwelling (or when repeat dwell is enabled), keep focus on
        //      the hovered button if the cursor is inside its unpadded frame, or inside
        //      its padded frame without having penetrated into another button's core.
        //    - Once activated with repeat dwell disabled, shrink the retention region to
        //      the button's interior (`postActivationRetentionFrame`) so glancing to the
        //      12pt screen border or inter-tile gap releases hover cleanly.
        if let currentId = hoveredButtonId,
           isButtonAllowed(currentId),
           let currentFrame = buttonFrames[currentId] {
            if isPostActivationSingleDwell {
                let interiorFrame = postActivationRetentionFrame(for: currentFrame)
                if interiorFrame.contains(position) {
                    return currentId
                }
            } else {
                if currentFrame.contains(position) {
                    return currentId
                }
                let currentPadded = currentFrame.insetBy(dx: -hitTestPadding, dy: -hitTestPadding)
                if currentPadded.contains(position) {
                    let coreInset: CGFloat = hasActivatedCurrentDwell ? 0 : 6.0
                    let enteredOtherCore = orderedButtonIds.contains { otherId in
                        guard otherId != currentId,
                              isButtonAllowed(otherId),
                              let otherFrame = buttonFrames[otherId] else { return false }
                        let coreFrame = otherFrame.width > coreInset * 2 && otherFrame.height > coreInset * 2
                            ? otherFrame.insetBy(dx: coreInset, dy: coreInset)
                            : otherFrame
                        return coreFrame.contains(position)
                    }
                    if !enteredOtherCore {
                        return currentId
                    }
                }
            }
        }

        // 2. Exact hit inside any allowed button's unpadded frame.
        if let exactHit = orderedButtonIds.first(where: { id in
            guard isButtonAllowed(id), let frame = buttonFrames[id] else { return false }
            if (isPostActivationSingleDwell && id == hoveredButtonId) || id == releasedAfterActivationButtonId {
                return postActivationRetentionFrame(for: frame).contains(position)
            }
            return frame.contains(position)
        }) {
            return exactHit
        }

        // 3. Padded hit: if multiple buttons' padded frames overlap in the inter-tile gap,
        //    pick the button whose unpadded frame is closest to `position`.
        var bestId: String?
        var bestDistanceSquared: CGFloat = .greatestFiniteMagnitude
        for id in orderedButtonIds {
            guard isButtonAllowed(id), let frame = buttonFrames[id] else { continue }
            if (isPostActivationSingleDwell && id == hoveredButtonId) || id == releasedAfterActivationButtonId {
                continue
            }
            guard frame.insetBy(dx: -hitTestPadding, dy: -hitTestPadding).contains(position) else { continue }
            let clampedX = min(max(position.x, frame.minX), frame.maxX)
            let clampedY = min(max(position.y, frame.minY), frame.maxY)
            let dx = position.x - clampedX
            let dy = position.y - clampedY
            let distSq = dx * dx + dy * dy
            if distSq < bestDistanceSquared {
                bestDistanceSquared = distSq
                bestId = id
            }
        }
        return bestId
    }

    // MARK: - Dwell Logic

    private func startDwell(buttonId: String, now: TimeInterval) {
        hoveredButtonId = buttonId
        dwellStartTime = now
        dwellProgress = 0
        hasActivatedCurrentDwell = false
        activatedButtonId = nil  // Clear previous activation
        startDwellTimer()
    }

    private func startDwellTimer() {
        dwellTimer?.invalidate()
        let timer = Timer(timeInterval: dwellUpdateInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.isEnabled,
                  let currentId = self.hoveredButtonId,
                  self.isButtonAllowed(currentId),
                  self.exitGraceTimer == nil else { return }
            self.updateDwellProgress(now: CACurrentMediaTime())
        }
        RunLoop.main.add(timer, forMode: .common)
        dwellTimer = timer
    }

    private func updateDwellProgress(now: TimeInterval) {
        guard let startTime = dwellStartTime else { return }

        if hasActivatedCurrentDwell && !AppSettings.shared.enableRepeatDwell {
            if dwellProgress != 1.0 {
                dwellProgress = 1.0
            }
            return
        }

        let dwellTime = max(0.1, AppSettings.shared.dwellTime)
        let repeatTime = max(AppSettings.shared.repeatDwellDelay, activationCooldown)
        let elapsed = max(0, now - startTime)

        // If we've already activated and repeat is enabled, we use the repeat delay instead
        let targetTime = hasActivatedCurrentDwell ? repeatTime : dwellTime
        let progress = min(elapsed / targetTime, 1.0)

        if abs(dwellProgress - progress) > 0.0001 || progress == 0 || progress == 1.0 {
            if dwellProgress != progress {
                dwellProgress = progress
            }
        }

        // Debug: log progress every 1s while dwelling (helps diagnose jitter vs hit-test issues)
        if now - lastDwellDebugTime >= 1.0 {
            lastDwellDebugTime = now
            DebugLog.debug("Dwell: progress=\(String(format: "%.0f", progress * 100))% on \(hoveredButtonId ?? "?")", tag: "Dwell")
        }

        if progress >= 1.0 {
            if !hasActivatedCurrentDwell {
                // First activation — only advance state once cooldown permits activation
                if activateCurrentButton(now: now) {
                    hasActivatedCurrentDwell = true
                    if AppSettings.shared.enableRepeatDwell {
                        // Reset start time to now to start the repeat delay countdown
                        dwellStartTime = now
                        dwellProgress = 0
                    }
                }
            } else if AppSettings.shared.enableRepeatDwell {
                // Repeat activation — only reset timer if activation actually fired
                if activateCurrentButton(now: now) {
                    dwellStartTime = now
                    dwellProgress = 0
                }
            }
        }
    }

    @discardableResult
    private func activateCurrentButton(now: TimeInterval = CACurrentMediaTime()) -> Bool {
        guard let buttonId = hoveredButtonId, isButtonAllowed(buttonId) else { return false }
        guard now - lastActivationTime >= activationCooldown else { return false }

        publishActivation(buttonId: buttonId, hapticStyle: .medium, now: now)
        return true
    }

    /// Record an activation and notify observers (haptic optional).
    private func publishActivation(
        buttonId: String,
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle?,
        now: TimeInterval = CACurrentMediaTime()
    ) {
        activationToken &+= 1
        let activation = DwellActivation(token: activationToken, buttonId: buttonId)
        DebugLog.debug("Dwell: activated \(buttonId) (token=\(activation.token))", tag: "Dwell")
        // Keep legacy fields for existing observers, then publish the atomic
        // snapshot last so `$lastActivation` subscribers always see a matching id.
        activatedButtonId = buttonId
        lastActivation = activation
        lastActivationTime = now

        if let hapticStyle {
            let generator = UIImpactFeedbackGenerator(style: hapticStyle)
            generator.impactOccurred()
        }
    }

    func cancelDwell() {
        dwellTimer?.invalidate()
        dwellTimer = nil
        exitGraceTimer?.invalidate()
        exitGraceTimer = nil
        hoveredButtonId = nil
        dwellStartTime = nil
        dwellProgress = 0
        hasActivatedCurrentDwell = false
    }

    // MARK: - Reset

    func reset() {
        releasedAfterActivationButtonId = nil
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
              let id = scanHighlightedButtonId,
              isButtonAllowed(id) else { return }

        publishActivation(buttonId: id, hapticStyle: .heavy, now: now)
        
        if id == hoveredButtonId {
            hasActivatedCurrentDwell = true
            dwellStartTime = now
            dwellProgress = AppSettings.shared.enableRepeatDwell ? 0 : 1.0
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

        publishActivation(buttonId: buttonId, hapticStyle: .heavy, now: now)
        
        if buttonId == hoveredButtonId {
            hasActivatedCurrentDwell = true
            dwellStartTime = now
            dwellProgress = AppSettings.shared.enableRepeatDwell ? 0 : 1.0
        }
    }

    /// Instantly activate the currently hovered button (for external callers).
    func activateHoveredButton() {
        let now = CACurrentMediaTime()
        guard now - lastActivationTime >= activationCooldown else { return }
        guard let buttonId = hoveredButtonId, isButtonAllowed(buttonId) else { return }

        publishActivation(buttonId: buttonId, hapticStyle: .heavy, now: now)
        hasActivatedCurrentDwell = true
        dwellStartTime = now
        dwellProgress = AppSettings.shared.enableRepeatDwell ? 0 : 1.0
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
