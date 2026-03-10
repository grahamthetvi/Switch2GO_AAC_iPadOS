import SwiftUI
import Combine
import VocableShared
import UIKit
import MediaPipeTasksVision

/// Manages gaze tracking using the shared KMP module
class GazeTrackingManager: ObservableObject {
    @Published var gazePosition: CGPoint = .zero {
        didSet {
            // Feed gaze position to dwell selection system
            dwellManager.updateGazePosition(gazePosition)
        }
    }
    @Published var isTracking = false
    @Published var isCursorVisible = true
    @Published var isGazeOutOfBounds = false
    @Published var showTrackingError = false
    @Published var calibrationProgress: Double = 0.0

    /// Dwell selection manager for gaze-based button activation
    let dwellManager = DwellSelectionManager()

    /// External USB HID switch control manager
    let switchManager = SwitchControlManager()
    
    // Raw gaze values for calibration (normalized -1 to 1)
    var rawGazeX: Float = 0.0
    var rawGazeY: Float = 0.0
    
    private var gazeTracker: GazeTracker?
    private let cameraManager = CameraManager()
    private let faceLandmarkService = FaceLandmarkService()
    private var cancellables = Set<AnyCancellable>()
    private var lastValidPosition: CGPoint?
    private var lastLandmarkTime: TimeInterval = 0
    private let storage: Storage
    private let logger: Logger
    private var updateTimer: Timer?
    /// Thread-safe flag to prevent concurrent frame processing.
    /// Access synchronized via processingLock.
    private var _isProcessingFrame = false
    private let processingLock = NSLock()
    private var detector: PlatformFaceLandmarkDetector?
    private var lastFrameProcessedTime: TimeInterval = 0
    private var lastProcessingStartTime: TimeInterval = 0
    private let processingTimeout: TimeInterval = 3.0  // Recovery timeout
    private let minFrameInterval: TimeInterval = 1.0 / 20.0  // Max 20 FPS for gaze processing

    // Orientation change debounce timer
    private var orientationDebounceTimer: Timer?

    // Head pose tracker for face/head tracking mode
    private let headPoseTracker = HeadPoseTracker()
    // Head tracking blink detection (separate from eye gaze blink state)
    private var headWasBlinking = false
    private var headBlinkStartTime: TimeInterval = 0
    private var headLastBlinkEndTime: TimeInterval = 0

    // Gaze offset for recentering (applied before screen mapping)
    private var gazeOffsetX: Float = 0.0
    private var gazeOffsetY: Float = 0.0
    private var lastRawGazeX: Float?
    private var lastRawGazeY: Float?

    // Double-blink detection
    private var lastBlinkEndTime: TimeInterval = 0
    private var blinkStartTime: TimeInterval = 0
    private var wasBlinking: Bool = false
    private var lastRecenterTime: TimeInterval = 0

    // Auto-recenter
    private var gazeCenteredStartTime: TimeInterval = 0
    private var isGazeCentered = false
    private var autoRecenterEnabled = true

    // Out-of-bounds tracking
    private var gazeOutOfBoundsStartTime: TimeInterval = 0

    /// When true, tracking must stay stopped (e.g. settings or onboarding sheet is open).
    /// Prevents orientation change from re-enabling tracking while a modal is presented.
    var isModalOpen: Bool = false

    // Constants (mirrors Android)
    private let doubleBlinkWindow: TimeInterval = 0.6
    private let blinkMinDuration: TimeInterval = 0.05
    private let blinkCooldown: TimeInterval = 0.3
    private let centerGazeThreshold: Float = 0.08
    private let autoRecenterDuration: TimeInterval = 1.5
    private let gazeOutOfBoundsThreshold: Float = 1.2
    private let outOfBoundsTimeout: TimeInterval = 0.5
    
    init() {
        self.storage = StorageKt.createStorage()
        self.logger = LoggerKt.createLogger(tag: "GazeTracking")
        setupLandmarkSubscriptions()
        setupSwitchControl()
    }
    
    func startTracking() {
        // Set isTracking immediately to prevent re-entrant calls from
        // orientation change notifications that fire during setup.
        guard !isTracking else {
            DebugLog.debug("startTracking() skipped — already tracking", tag: "Tracking")
            return
        }
        isTracking = true

        // Clean up any stale state from a previous session that wasn't
        // fully torn down (e.g., orientation change during init).
        faceLandmarkService.close()
        detector?.close()
        detector = nil
        gazeTracker = nil

        let settings = AppSettings.shared
        let screenBounds = currentScreenBounds()
        
        // Create face landmark detector and bridge to Swift
        let detector = PlatformFaceLandmarkDetector()
        detector.setSwiftBridge(bridge: faceLandmarkService)
        faceLandmarkService.attachDetector(detector)
        self.detector = detector
        
        // Create gaze tracker with settings
        gazeTracker = GazeTracker(
            faceLandmarkDetector: detector,
            screenWidth: Int32(screenBounds.width),
            screenHeight: Int32(screenBounds.height),
            storage: storage,
            logger: logger
        )
        
        // Configure based on settings
        gazeTracker?.eyeSelection = mapEyeSelection(settings.eyeSelection)
        gazeTracker?.smoothingMode = mapSmoothingMode(settings.smoothingMode)
        gazeTracker?.trackingMethod = mapTrackingMethod(settings.trackingMode)
        gazeTracker?.setLerpFactor(factor: mapSensitivityToLerp(settings.sensitivity))
        applyGazeCameraOffset(settings)
        _ = gazeTracker?.loadCalibration()

        // Configure head pose tracker from saved settings
        headPoseTracker.sensitivityX = Float(settings.headSensitivityX)
        headPoseTracker.sensitivityY = Float(settings.headSensitivityY)
        headPoseTracker.cameraOffsetYaw = Float(settings.headCameraOffsetYaw)
        headPoseTracker.cameraOffsetPitch = Float(settings.headCameraOffsetPitch)

        // Initialize MediaPipe via the bridge (KMP -> Swift)
        let initialized = detector.initialize(useGpu: settings.useGPU)
        if !initialized {
            DebugLog.error("Face landmark service failed to initialize", tag: "Tracking")
            isTracking = false
            return
        }

        cameraManager.frameHandler = { [weak self] sampleBuffer in
            self?.handleFrame(sampleBuffer)
        }

        // When the camera detects an orientation change, update the gaze tracker's
        // screen dimensions so gaze-to-screen mapping stays correct.
        cameraManager.orientationDidChange = { [weak self] in
            self?.handleOrientationChange()
        }

        cameraManager.start()

        frameCountSinceStart = 0
        gazeResultLogCount = 0
        // Reset eye tracking diagnostics
        eyeFrameCount = 0
        eyeSuccessCount = 0
        eyeNullCount = 0
        eyeErrorCount = 0
        eyeSkippedCount = 0

        let mode = settings.selectionMode
        DebugLog.info("Started — mode=\(mode), screen=\(Int(screenBounds.width))x\(Int(screenBounds.height)), GPU=\(settings.useGPU)", tag: "Tracking")
        DebugLog.info("gazeTracker=\(gazeTracker != nil), detector=\(self.detector != nil)", tag: "Tracking")
        logger.info(message: "Gaze tracking started (mode: \(mode))")
    }
    
    func stopTracking() {
        let wasTracking = isTracking
        isTracking = false
        if wasTracking {
            DebugLog.info("Stopping tracking", tag: "Tracking")
        }
        updateTimer?.invalidate()
        updateTimer = nil
        processingLock.lock()
        _isProcessingFrame = false
        processingLock.unlock()
        cameraManager.stop()
        faceLandmarkService.close()
        detector?.close()
        detector = nil
        gazeTracker = nil
        isCursorVisible = true
        isGazeOutOfBounds = false
        showTrackingError = false
        logger.info(message: "Gaze tracking stopped")
    }
    
    func recenter() {
        recenterCursor()
    }
    
    private func setupLandmarkSubscriptions() {
        faceLandmarkService.$currentLandmarks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] landmarks in
                self?.updateGazePosition(from: landmarks)
            }
            .store(in: &cancellables)
    }

    private func updateGazePosition(from landmarks: [NormalizedLandmark]?) {
        let settings = AppSettings.shared
        guard settings.selectionMode == "face" else { return }

        guard let landmarks, !landmarks.isEmpty else {
            let now = CACurrentMediaTime()
            if let last = lastValidPosition, (now - lastLandmarkTime) < 0.5 {
                gazePosition = last
                isTracking = true
                showTrackingError = false
            } else {
                isTracking = false
                showTrackingError = settings.showTrackingErrorBanner
            }
            return
        }

        let bounds = currentScreenBounds()
        guard bounds.width > 0, bounds.height > 0 else { return }

        // Map sensitivity setting (0=low, 1=medium, 2=high) to lerp factor
        let lerpFactor: Float
        switch settings.sensitivity {
        case 0: lerpFactor = 0.3
        case 2: lerpFactor = 0.8
        default: lerpFactor = 0.5
        }

        // Apply current head tracking settings
        headPoseTracker.sensitivityX = Float(settings.headSensitivityX)
        headPoseTracker.sensitivityY = Float(settings.headSensitivityY)

        guard let result = headPoseTracker.processLandmarks(
            landmarks: landmarks,
            screenWidth: Float(bounds.width),
            screenHeight: Float(bounds.height),
            smoothingMode: settings.smoothingMode,
            lerpFactor: lerpFactor
        ) else {
            return
        }

        let now = CACurrentMediaTime()

        // Blink detection for double-blink recenter in head tracking mode
        if settings.enableDoubleBlinkRecenter {
            let isBlinking = headPoseTracker.detectBlink(landmarks: landmarks)
            processHeadBlinkDetection(isBlinking: isBlinking, landmarks: landmarks, now: now)
        }

        // Out-of-bounds handling
        let outOfBounds = result.isOutOfBounds && settings.enableOutOfBoundsHiding

        let target = CGPoint(x: CGFloat(result.screenX), y: CGFloat(result.screenY))
        gazePosition = target
        isTracking = true
        isCursorVisible = !outOfBounds
        isGazeOutOfBounds = result.isOutOfBounds
        showTrackingError = false
        lastValidPosition = target
        lastLandmarkTime = now
    }

    private func pointForLandmark(index: Int, landmarks: [NormalizedLandmark], bounds: CGRect) -> CGPoint {
        guard index < landmarks.count else {
            return CGPoint(x: bounds.midX, y: bounds.midY)
        }
        let landmark = landmarks[index]
        let mirroredX = 1.0 - CGFloat(landmark.x)
        return CGPoint(x: mirroredX * bounds.width, y: CGFloat(landmark.y) * bounds.height)
    }

    private func clampPoint(_ point: CGPoint, bounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    private func currentScreenBounds() -> CGRect {
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            return scene.screen.bounds
        }
        return .zero
    }

    private var frameCountSinceStart = 0

    private func handleFrame(_ sampleBuffer: CMSampleBuffer) {
        // Frame rate throttling to reduce jitter
        let now = CACurrentMediaTime()
        guard now - lastFrameProcessedTime >= minFrameInterval else { return }
        lastFrameProcessedTime = now

        // Use the camera manager's tracked orientation rather than hardcoding
        let orientation = cameraManager.currentImageOrientation
        faceLandmarkService.updateLatestSampleBuffer(sampleBuffer, orientation: orientation)

        let settings = AppSettings.shared
        applyCurrentSettings(settings)

        frameCountSinceStart += 1
        // Log the first few frames to confirm which path is taken
        if frameCountSinceStart <= 3 {
            DebugLog.debug("Frame #\(frameCountSinceStart): mode=\(settings.selectionMode), imgOrientation=\(orientation.rawValue)", tag: "Camera")
        }

        if settings.selectionMode == "face" {
            faceLandmarkService.requestDetection()
        } else if settings.selectionMode == "eyeGaze" {
            processGazeFrame()
        }
        // selectionMode == "none" → don't process (tracking should be stopped anyway)
    }

    // Diagnostic counter for eye tracking pipeline (logged every 60 frames)
    private var eyeFrameCount = 0
    private var eyeSuccessCount = 0
    private var eyeNullCount = 0
    private var eyeErrorCount = 0
    private var eyeSkippedCount = 0

    private func processGazeFrame() {
        guard let gazeTracker else {
            if eyeFrameCount == 0 {
                DebugLog.warn("gazeTracker is nil — processGazeFrame skipped", tag: "EyeGaze")
            }
            return
        }

        // Thread-safe check-and-set for isProcessingFrame
        processingLock.lock()
        let now = CACurrentMediaTime()
        // Recovery: if processing has been stuck for too long, reset the flag
        if _isProcessingFrame && (now - lastProcessingStartTime) > processingTimeout {
            logger.warn(message: "Frame processing timed out — resetting processing state")
            _isProcessingFrame = false
        }
        guard !_isProcessingFrame else {
            processingLock.unlock()
            eyeSkippedCount += 1
            return
        }
        _isProcessingFrame = true
        lastProcessingStartTime = now
        processingLock.unlock()

        eyeFrameCount += 1

        gazeTracker.processFrame { [weak self] result, error in
            guard let self else { return }
            defer {
                self.processingLock.lock()
                self._isProcessingFrame = false
                self.processingLock.unlock()
            }

            if let error = error {
                self.eyeErrorCount += 1
                self.logger.error(message: "Gaze processing failed", throwable: KotlinError(error: error))
                self.handleNoGaze()
                self.logEyeDiagnostics()
                return
            }

            guard let result = result else {
                self.eyeNullCount += 1
                self.handleNoGaze()
                self.logEyeDiagnostics()
                return
            }

            self.eyeSuccessCount += 1
            self.logEyeDiagnostics()
            self.handleGazeResult(result, gazeTracker: gazeTracker)
        }
    }

    private func logEyeDiagnostics() {
        let total = eyeFrameCount
        guard total > 0, total % 60 == 0 else { return }
        let msg = "After \(total) frames: success=\(eyeSuccessCount) null=\(eyeNullCount) error=\(eyeErrorCount) skipped=\(eyeSkippedCount)"
        if eyeSuccessCount == 0 {
            DebugLog.warn(msg, tag: "EyeGaze")
        } else {
            DebugLog.info(msg, tag: "EyeGaze")
        }
    }

    private func handleNoGaze() {
        DispatchQueue.main.async {
            let now = CACurrentMediaTime()
            if let last = self.lastValidPosition, (now - self.lastLandmarkTime) < 0.5 {
                self.gazePosition = last
                self.isTracking = true
                self.showTrackingError = false
            } else {
                self.isTracking = false
                self.showTrackingError = AppSettings.shared.showTrackingErrorBanner
            }
        }
    }

    private var gazeResultLogCount = 0

    private func handleGazeResult(_ result: GazeResult, gazeTracker: GazeTracker) {
        gazeResultLogCount += 1
        if gazeResultLogCount <= 5 {
            DebugLog.info("Result #\(gazeResultLogCount): gazeX=\(String(format: "%.3f", result.gazeX)) gazeY=\(String(format: "%.3f", result.gazeY)) conf=\(String(format: "%.2f", result.confidence)) blink=\(result.leftBlink)/\(result.rightBlink)", tag: "EyeGaze")
        }

        let rawX = result.gazeX
        let rawY = result.gazeY

        lastRawGazeX = rawX
        lastRawGazeY = rawY
        rawGazeX = rawX
        rawGazeY = rawY

        let now = CACurrentMediaTime()

        // Blink detection: both eyes must blink
        let isBlinking = result.leftBlink && result.rightBlink
        processBlinkDetection(isBlinking: isBlinking, now: now)

        // Auto-recenter
        processAutoRecenter(rawX: rawX, rawY: rawY, now: now)

        // Apply gaze offset from recentering
        let adjustedX = (rawX - gazeOffsetX).coerceIn(min: -1, max: 1)
        let adjustedY = (rawY - gazeOffsetY).coerceIn(min: -1, max: 1)

        updateGazeOutOfBoundsState(gazeX: adjustedX, gazeY: adjustedY, now: now)

        let amplification = Float(AppSettings.shared.gazeAmplification)
        let amplifiedX = (adjustedX * amplification).coerceIn(min: -1, max: 1)
        let amplifiedY = (adjustedY * amplification).coerceIn(min: -1, max: 1)

        let adjustedResult = GazeResult(
            gazeX: amplifiedX,
            gazeY: amplifiedY,
            leftIrisCenter: result.leftIrisCenter,
            rightIrisCenter: result.rightIrisCenter,
            confidence: result.confidence,
            leftBlink: result.leftBlink,
            rightBlink: result.rightBlink,
            headYaw: result.headYaw,
            headPitch: result.headPitch,
            headRoll: result.headRoll
        )

        let screenPair = gazeTracker.gazeToScreen(gazeResult: adjustedResult)
        let screenX = screenPair.first?.int32Value ?? 0
        let screenY = screenPair.second?.int32Value ?? 0

        let bounds = currentScreenBounds()
        let rawTarget = CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
        let clampedTarget = clampPoint(rawTarget, bounds: bounds)

        // Screen-level lerp: only for SIMPLE_LERP mode (matches Android's double-layer smoothing)
        // For Kalman modes, the KMP-level smoothing is sufficient
        let finalPosition: CGPoint
        if gazeTracker.usesScreenLerp(), let lastPos = lastValidPosition {
            let screenLerp = CGFloat(mapSensitivityToLerp(AppSettings.shared.sensitivity))
            let smoothed = CGPoint(
                x: lastPos.x + screenLerp * (clampedTarget.x - lastPos.x),
                y: lastPos.y + screenLerp * (clampedTarget.y - lastPos.y)
            )
            finalPosition = clampPoint(smoothed, bounds: bounds)
        } else {
            finalPosition = clampedTarget
        }

        DispatchQueue.main.async {
            self.gazePosition = finalPosition
            self.isTracking = true
            self.showTrackingError = false
            self.lastValidPosition = finalPosition
            self.lastLandmarkTime = CACurrentMediaTime()
        }
    }
    
    // MARK: - Orientation Change Handling

    /// Notification posted when the device orientation changes.
    /// The `object` is a `Bool` — true if tracking is supported in the new orientation.
    static let orientationTrackingChanged = Notification.Name("OrientationTrackingChanged")

    /// Called when the camera manager detects a device orientation change.
    /// Tracking is only supported in landscape right (home button RIGHT, camera LEFT).
    /// In all other orientations tracking is stopped and only touch/switch input works.
    private func handleOrientationChange() {
        orientationDebounceTimer?.invalidate()
        orientationDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.applyOrientationChange()
        }
    }

    private func applyOrientationChange() {
        let supported = CameraManager.isTrackingSupportedOrientation
        let settings = AppSettings.shared

        if supported && settings.selectionMode != "none" && !isTracking && !isModalOpen {
            // Returned to landscape right (home button right) — restart tracking
            // Skip if a modal is open; tracking will resume when it closes.
            DebugLog.info("Landscape right detected — starting tracking", tag: "Orientation")
            headPoseTracker.reset()
            lastValidPosition = nil
            lastRawGazeX = nil
            lastRawGazeY = nil
            gazeOffsetX = 0
            gazeOffsetY = 0
            startTracking()
        } else if !supported && isTracking {
            DebugLog.info("Non-tracking orientation — stopping tracking", tag: "Orientation")
            stopTracking()
        } else {
            DebugLog.debug("Orientation check: supported=\(supported), mode=\(settings.selectionMode), tracking=\(isTracking)", tag: "Orientation")
        }

        // Post notification so ContentView can show the orientation banner
        NotificationCenter.default.post(
            name: Self.orientationTrackingChanged,
            object: supported
        )
    }

    // MARK: - Switch Control

    private func setupSwitchControl() {
        let settings = AppSettings.shared

        // Bind switch manager to dwell manager so switch presses trigger selection
        dwellManager.bindSwitchControl(switchManager)

        // Apply saved settings to switch manager
        applySwitchSettings(settings)

        // Initialize BLE if switch control is enabled
        if settings.switchControlEnabled {
            switchManager.initialize()
        }

        // Listen for back action to post a notification (views can subscribe)
        switchManager.backAction
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                _ = self  // keep reference alive
                NotificationCenter.default.post(name: .switchBackAction, object: nil)
            }
            .store(in: &cancellables)
    }

    /// Apply current settings to the switch control manager.
    func applySwitchSettings(_ settings: AppSettings) {
        switchManager.controlMode = SwitchControlMode(rawValue: settings.switchControlMode) ?? .direct
        switchManager.scanInterval = settings.switchScanInterval
        switchManager.autoReconnect = settings.switchAutoReconnect

        // Map switch action strings to enums
        let action1 = SwitchAction(rawValue: settings.switchAction1) ?? .select
        let action2 = SwitchAction(rawValue: settings.switchAction2) ?? .next
        let action3 = SwitchAction(rawValue: settings.switchAction3) ?? .previous
        let action4 = SwitchAction(rawValue: settings.switchAction4) ?? .back
        switchManager.switchActions = [action1, action2, action3, action4]

        // Apply USB HID key mappings
        switchManager.switchKeyHIDCodes = [
            settings.switchKey1,
            settings.switchKey2,
            settings.switchKey3,
            settings.switchKey4
        ]
    }

    /// Enable or disable switch control. Call when the setting changes.
    func setSwitchControlEnabled(_ enabled: Bool) {
        if enabled {
            switchManager.initialize()
        } else {
            switchManager.shutdown()
        }
    }

    // MARK: - Settings Mapping
    
    private func mapEyeSelection(_ mode: String) -> EyeSelection {
        switch mode {
        case "left": return .leftEyeOnly
        case "right": return .rightEyeOnly
        default: return .bothEyes
        }
    }
    
    private func mapSmoothingMode(_ mode: String) -> SmoothingMode {
        switch mode {
        case "simple": return .simpleLerp
        case "kalman": return .kalmanFilter
        case "adaptive": return .adaptiveKalman
        case "combined": return .combined
        default: return .adaptiveKalman
        }
    }

    private func mapTrackingMethod(_ mode: String) -> TrackingMethod {
        switch mode {
        case "3D": return .eyeball3d
        default: return .iris2d
        }
    }

    func resetGazeCalibration() {
        gazeTracker?.getCalibration().resetCalibration()
        gazeTracker?.reset()
    }

    private func applyCurrentSettings(_ settings: AppSettings) {
        guard let gazeTracker else { return }
        gazeTracker.eyeSelection = mapEyeSelection(settings.eyeSelection)
        gazeTracker.smoothingMode = mapSmoothingMode(settings.smoothingMode)
        gazeTracker.trackingMethod = mapTrackingMethod(settings.trackingMode)
        gazeTracker.setLerpFactor(factor: mapSensitivityToLerp(settings.sensitivity))
    }

    /// Map the integer sensitivity setting (0/1/2) to a lerp factor (0-1).
    /// Matches Android's VocableSharedPreferences behavior.
    private func mapSensitivityToLerp(_ sensitivity: Int) -> Float {
        switch sensitivity {
        case 0: return 0.25   // Low: smooth, less responsive
        case 2: return 0.8    // High: responsive, more jittery
        default: return 0.5   // Medium: balanced (Android default)
        }
    }

    /// Apply camera position offset to eye gaze calculator.
    /// Compensates for off-center cameras (iPad left-side camera).
    private func applyGazeCameraOffset(_ settings: AppSettings) {
        guard let gazeTracker else { return }

        // Base offsets from IrisGazeCalculator defaults
        var offsetX: Float = 0.0
        let offsetY: Float = 0.3  // Default downward bias from Android

        // Adjust horizontal offset based on camera position
        switch settings.headCameraPosition {
        case "left":
            // iPad landscape: camera on left side
            // Gaze appears slightly right-shifted; compensate with negative offset
            offsetX = -0.05
        case "right":
            offsetX = 0.05
        case "custom":
            // Use the calibrated head offset as a proxy for gaze offset
            // The head offset yaw roughly indicates how much the camera is off-center
            let headYawOffset = Float(settings.headCameraOffsetYaw)
            offsetX = -(headYawOffset / 45.0) * 0.15  // Scale head yaw to gaze offset
        default:
            offsetX = 0.0
        }

        gazeTracker.setGazeOffsets(offsetX: offsetX, offsetY: offsetY)
    }

    // MARK: - Head Tracking Blink Detection

    private func processHeadBlinkDetection(isBlinking: Bool, landmarks: [NormalizedLandmark], now: TimeInterval) {
        if isBlinking && !headWasBlinking {
            headBlinkStartTime = now
        } else if !isBlinking && headWasBlinking {
            let duration = now - headBlinkStartTime
            if duration >= blinkMinDuration {
                let timeSinceLast = now - headLastBlinkEndTime
                if timeSinceLast <= doubleBlinkWindow && headLastBlinkEndTime > 0 {
                    // Double blink detected — recenter head tracking
                    headLastBlinkEndTime = 0
                    headPoseTracker.recenter(landmarks: landmarks)
                    saveHeadCalibration()
                    headPoseTracker.reset()
                } else {
                    headLastBlinkEndTime = now
                }
            }
        }

        headWasBlinking = isBlinking

        if headLastBlinkEndTime > 0 && now - headLastBlinkEndTime > doubleBlinkWindow {
            headLastBlinkEndTime = 0
        }
    }

    private func saveHeadCalibration() {
        let settings = AppSettings.shared
        settings.headCameraOffsetYaw = Double(headPoseTracker.cameraOffsetYaw)
        settings.headCameraOffsetPitch = Double(headPoseTracker.cameraOffsetPitch)
        settings.headCameraPosition = "custom"
    }

    /// Apply a camera position preset (center, left, right).
    func applyHeadCameraPreset(_ position: String) {
        headPoseTracker.applyCameraPositionPreset(position)
        let settings = AppSettings.shared
        settings.headCameraPosition = position
        settings.headCameraOffsetYaw = Double(headPoseTracker.cameraOffsetYaw)
        settings.headCameraOffsetPitch = Double(headPoseTracker.cameraOffsetPitch)
        headPoseTracker.reset()
    }

    private func recenterCursor() {
        let now = CACurrentMediaTime()

        if lastRecenterTime > 0, now - lastRecenterTime < blinkCooldown {
            return
        }

        if let rawX = lastRawGazeX, let rawY = lastRawGazeY {
            gazeOffsetX = rawX
            gazeOffsetY = rawY
        }

        gazeTracker?.reset()

        let bounds = currentScreenBounds()
        DispatchQueue.main.async {
            self.gazePosition = CGPoint(x: bounds.midX, y: bounds.midY)
        }

        lastRecenterTime = now
    }

    private func processBlinkDetection(isBlinking: Bool, now: TimeInterval) {
        guard AppSettings.shared.enableDoubleBlinkRecenter else { return }

        if isBlinking && !wasBlinking {
            blinkStartTime = now
        } else if !isBlinking && wasBlinking {
            let blinkDuration = now - blinkStartTime
            if blinkDuration >= blinkMinDuration {
                let timeSinceLastBlink = now - lastBlinkEndTime
                if timeSinceLastBlink <= doubleBlinkWindow && lastBlinkEndTime > 0 {
                    lastBlinkEndTime = 0
                    recenterCursor()
                } else {
                    lastBlinkEndTime = now
                }
            }
        }

        wasBlinking = isBlinking

        if lastBlinkEndTime > 0 && now - lastBlinkEndTime > doubleBlinkWindow {
            lastBlinkEndTime = 0
        }
    }

    private func processAutoRecenter(rawX: Float, rawY: Float, now: TimeInterval) {
        guard AppSettings.shared.enableAutoRecenter && autoRecenterEnabled else { return }

        let adjustedX = rawX - gazeOffsetX
        let adjustedY = rawY - gazeOffsetY
        let isNearCenter = abs(adjustedX) <= centerGazeThreshold && abs(adjustedY) <= centerGazeThreshold

        if isNearCenter {
            if !isGazeCentered {
                gazeCenteredStartTime = now
                isGazeCentered = true
            } else if now - gazeCenteredStartTime >= autoRecenterDuration {
                recenterCursor()
                isGazeCentered = false
                gazeCenteredStartTime = 0
            }
        } else {
            isGazeCentered = false
            gazeCenteredStartTime = 0
        }
    }

    private func updateGazeOutOfBoundsState(gazeX: Float, gazeY: Float, now: TimeInterval) {
        guard AppSettings.shared.enableOutOfBoundsHiding else {
            DispatchQueue.main.async {
                self.isGazeOutOfBounds = false
                self.isCursorVisible = true
            }
            return
        }

        let isOutOfBounds = abs(gazeX) > gazeOutOfBoundsThreshold || abs(gazeY) > gazeOutOfBoundsThreshold

        if isOutOfBounds {
            if !isGazeOutOfBounds {
                gazeOutOfBoundsStartTime = now
            } else if now - gazeOutOfBoundsStartTime > outOfBoundsTimeout {
                DispatchQueue.main.async {
                    self.isGazeOutOfBounds = true
                    self.isCursorVisible = false
                }
            }
        } else {
            gazeOutOfBoundsStartTime = 0
            DispatchQueue.main.async {
                self.isGazeOutOfBounds = false
                self.isCursorVisible = true
            }
        }
    }
}

private extension Float {
    func coerceIn(min: Float, max: Float) -> Float {
        if self < min { return min }
        if self > max { return max }
        return self
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the "back" switch action fires.
    static let switchBackAction = Notification.Name("SwitchBackAction")
}

// Helper to wrap errors for Kotlin
class KotlinError: KotlinThrowable {
    let error: Error
    
    init(error: Error) {
        self.error = error
        super.init()
    }
    
    override var message: String? {
        error.localizedDescription
    }
}
