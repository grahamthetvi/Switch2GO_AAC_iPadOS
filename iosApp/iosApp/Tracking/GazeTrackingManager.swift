import SwiftUI
import Combine
import AVFoundation
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
    /// User-enabled tracking intent. Stays true while tracking is supposed to run,
    /// even if the face is temporarily lost — so recovery remains reachable.
    @Published var isTracking = false
    /// Whether a face/gaze is currently detected. Independent of [isTracking].
    @Published var isFaceDetected = false
    @Published var isCursorVisible = true
    @Published var isGazeOutOfBounds = false
    @Published var showTrackingError = false
    @Published var calibrationProgress: Double = 0.0
    @Published var armState = ArmRaiseState(leftRaised: false, rightRaised: false)
    @Published var handState = HandGestureState(leftPose: nil, rightPose: nil)
    @Published var bodyTrackingErrorMessage: String?

    let armRaiseActivation = PassthroughSubject<ArmSide, Never>()
    let handGestureActivation = PassthroughSubject<HandSide, Never>()

    /// Dwell selection manager for gaze-based button activation
    let dwellManager = DwellSelectionManager()

    /// External HID switch control (USB or Bluetooth keyboard)
    let switchManager = SwitchControlManager()

    /// iPad → ESP32 switch OUTPUT (PowerLink pulse). Independent of HID input.
    let switchOutputManager = ESP32SwitchOutputManager()
    
    // Raw gaze values for calibration (normalized -1 to 1)
    var rawGazeX: Float = 0.0
    var rawGazeY: Float = 0.0
    
    private var gazeTracker: GazeTracker?
    let cameraManager = CameraManager()
    private let faceLandmarkService = FaceLandmarkService()
    private let poseLandmarkService = PoseLandmarkService()
    private let gestureRecognizerService = GestureRecognizerService()
    private let armRaiseDetector = ArmRaiseDetector()
    private let handGestureDetector = HandGestureDetector()
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
    private let minBodyFrameInterval: TimeInterval = 1.0 / 15.0  // Max 15 FPS for body gesture modes
    private let armRaiseMargin: Float = 0.08
    private let armRaiseCooldownMs: Double = 1200
    private let handGestureMinScore: Float = 0.55
    private let handGestureStableFrames = 3
    private let handGestureCooldownMs: Double = 1200

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

    /// Bumped on every `stopTracking()` and on each `startTracking()` attempt so async gaze
    /// completions cannot resurrect `isTracking` after the camera has stopped.
    private var trackingEpoch: UInt64 = 0

    // Reliability improvements
    private var trackingStartTime: TimeInterval = 0
    private let warmupDuration: TimeInterval = 1.5
    private let watchdogTimeout: TimeInterval = 5.0
    private let trackingLossResetThreshold: TimeInterval = 1.0
    private let reinitializeCooldown: TimeInterval = 20.0
    private var lastSuccessfulDetectionTime: TimeInterval = 0
    private var lastReinitializeTime: TimeInterval = 0
    private var isRecovering: Bool = false
    private var lastKnownOrientation: UIInterfaceOrientation = .unknown

    // Lightweight diagnostics (enabled via debug setting)
    private var diagnosticsTimer: Timer?
    private var diagnosticsStartTime: TimeInterval = 0
    private var diagnosticsInputFrameCount: Int = 0
    private var diagnosticsProcessedFrameCount: Int = 0
    private var diagnosticsThrottledFrameCount: Int = 0
    private var diagnosticsSuccessCount: Int = 0
    private var diagnosticsMissCount: Int = 0
    private var diagnosticsWatchdogReinitCount: Int = 0
    private var diagnosticsOrientationReinitCount: Int = 0
    private var diagnosticsEyeLatencyTotalMs: Double = 0
    private var diagnosticsEyeLatencyMaxMs: Double = 0
    private var diagnosticsEyeLatencySamples: Int = 0

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
        setupBodyGestureCallbacks()
        setupSwitchControl()
        // Only spin up Core Bluetooth if this iPad already paired ESP32 output.
        // Creating CBCentralManager always prompts for Bluetooth permission.
        if AppSettings.shared.switchOutputPeripheralUUID != nil {
            switchOutputManager.start()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DebugCameraRotationChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let mode = AppSettings.shared.selectionMode
            if Self.isBodyGestureMode(mode) {
                if mode == "armRaise" {
                    self.poseLandmarkService.reinitialize()
                } else {
                    self.gestureRecognizerService.reinitialize()
                }
            } else {
                self.faceLandmarkService.reinitialize()
            }
        }
    }

    static func isBodyGestureMode(_ mode: String) -> Bool {
        mode == "armRaise" || mode == "handGesture"
    }
    
    func startTracking() {
        // Recover from stale state: async callbacks can leave isTracking true after the camera stopped.
        if isTracking && !cameraManager.captureSession.isRunning {
            DebugLog.warn("Recovering inconsistent tracking state (isTracking=true, camera not running)", tag: "Tracking")
            stopTracking()
        }
        guard !isTracking else {
            DebugLog.debug("startTracking() skipped — already tracking", tag: "Tracking")
            return
        }

        trackingEpoch += 1
        isTracking = true
        isFaceDetected = false

        let settings = AppSettings.shared
        let mode = settings.selectionMode
        applySelectionModeBehavior(settings)

        guard initializeTrackingBackend(for: mode, settings: settings) else {
            trackingEpoch += 1
            isTracking = false
            isFaceDetected = false
            return
        }

        cameraManager.frameHandler = { [weak self] sampleBuffer in
            self?.handleFrame(sampleBuffer)
        }

        cameraManager.orientationDidChange = { [weak self] in
            self?.handleOrientationChange()
        }

        cameraManager.onCaptureInterrupted = { [weak self] in
            self?.handleCaptureInterrupted()
        }

        cameraManager.onCaptureResumed = { [weak self] in
            self?.handleCaptureResumed()
        }

        cameraManager.onCaptureRuntimeError = { [weak self] in
            self?.handleCaptureRuntimeError()
        }

        cameraManager.start()

        let now = CACurrentMediaTime()
        trackingStartTime = now
        lastSuccessfulDetectionTime = now
        isRecovering = false
        lastKnownOrientation = currentInterfaceOrientation()

        frameCountSinceStart = 0
        gazeResultLogCount = 0
        eyeFrameCount = 0
        eyeSuccessCount = 0
        eyeNullCount = 0
        eyeErrorCount = 0
        eyeSkippedCount = 0

        configureDiagnosticsIfNeeded()

        let screenBounds = currentScreenBounds()
        DebugLog.info("Started — mode=\(mode), screen=\(Int(screenBounds.width))x\(Int(screenBounds.height)), GPU=\(settings.useGPU)", tag: "Tracking")
        logger.info(message: "Tracking started (mode: \(mode))")
    }

    private func initializeTrackingBackend(for mode: String, settings: AppSettings) -> Bool {
        let screenBounds = currentScreenBounds()

        if Self.isBodyGestureMode(mode) {
            faceLandmarkService.close()
            gazeTracker = nil
            detector = nil

            if mode == "armRaise" {
                gestureRecognizerService.close()
                armRaiseDetector.reset()
                armState = ArmRaiseState(leftRaised: false, rightRaised: false)
                guard poseLandmarkService.initialize(useGpu: settings.useGPU) else {
                    DebugLog.error("PoseLandmarker failed to initialize", tag: "Tracking")
                    return false
                }
            } else {
                poseLandmarkService.close()
                handGestureDetector.reset()
                handState = HandGestureState(leftPose: nil, rightPose: nil)
                guard gestureRecognizerService.initialize(useGpu: settings.useGPU) else {
                    DebugLog.error("GestureRecognizer failed to initialize", tag: "Tracking")
                    return false
                }
            }

            bodyTrackingErrorMessage = nil
            showTrackingError = false
            isCursorVisible = false
            return true
        }

        poseLandmarkService.close()
        gestureRecognizerService.close()
        armRaiseDetector.reset()
        handGestureDetector.reset()
        armState = ArmRaiseState(leftRaised: false, rightRaised: false)
        handState = HandGestureState(leftPose: nil, rightPose: nil)
        bodyTrackingErrorMessage = nil

        if detector == nil {
            let detector = PlatformFaceLandmarkDetector()
            detector.setSwiftBridge(bridge: faceLandmarkService)
            faceLandmarkService.attachDetector(detector)
            self.detector = detector
        }

        if gazeTracker == nil {
            gazeTracker = GazeTracker(
                faceLandmarkDetector: detector!,
                screenWidth: Int32(screenBounds.width),
                screenHeight: Int32(screenBounds.height),
                storage: storage,
                logger: logger
            )
        } else {
            gazeTracker?.updateScreenDimensions(width: Int32(screenBounds.width), height: Int32(screenBounds.height))
            gazeTracker?.reset()
        }

        gazeTracker?.eyeSelection = mapEyeSelection(settings.eyeSelection)
        gazeTracker?.smoothingMode = mapSmoothingMode(settings.smoothingMode)
        gazeTracker?.trackingMethod = mapTrackingMethod(settings.trackingMode)
        gazeTracker?.setLerpFactor(factor: mapSensitivityToLerp(settings.sensitivity))
        applyGazeCameraOffset(settings)
        _ = gazeTracker?.loadCalibration()

        headPoseTracker.sensitivityX = Float(settings.headSensitivityX)
        headPoseTracker.sensitivityY = Float(settings.headSensitivityY)
        headPoseTracker.cameraOffsetYaw = Float(settings.headCameraOffsetYaw)
        headPoseTracker.cameraOffsetPitch = Float(settings.headCameraOffsetPitch)

        guard detector!.initialize(useGpu: settings.useGPU) else {
            DebugLog.error("Face landmark service failed to initialize", tag: "Tracking")
            return false
        }

        isCursorVisible = true
        return true
    }

    private func applySelectionModeBehavior(_ settings: AppSettings) {
        let bodyMode = Self.isBodyGestureMode(settings.selectionMode)
        dwellManager.isEnabled = !bodyMode && settings.selectionMode != "none"
        if bodyMode {
            isCursorVisible = false
        }
    }
    
    func stopTracking() {
        trackingEpoch += 1
        let wasTracking = isTracking
        isTracking = false
        isFaceDetected = false
        if wasTracking {
            DebugLog.info("Stopping tracking", tag: "Tracking")
        }
        updateTimer?.invalidate()
        updateTimer = nil
        processingLock.lock()
        _isProcessingFrame = false
        processingLock.unlock()
        cameraManager.stop()
        
        faceLandmarkService.resetProcessingState()
        poseLandmarkService.resetProcessingState()
        gestureRecognizerService.resetProcessingState()
        
        armState = ArmRaiseState(leftRaised: false, rightRaised: false)
        handState = HandGestureState(leftPose: nil, rightPose: nil)
        bodyTrackingErrorMessage = nil
        isCursorVisible = true
        isGazeOutOfBounds = false
        showTrackingError = false
        stopDiagnostics()
        logger.info(message: "Gaze tracking stopped")
    }
    
    func recenter() {
        recenterCursor()
    }
    
    private func setupBodyGestureCallbacks() {
        poseLandmarkService.onPoseDetected = { [weak self] landmarks in
            self?.handleArmRaiseLandmarks(landmarks)
        }
        poseLandmarkService.onNoPoseDetected = { [weak self] in
            self?.handleNoBodyDetection(isArmRaise: true)
        }
        gestureRecognizerService.onGesturesDetected = { [weak self] hands in
            self?.handleHandGestures(hands)
        }
        gestureRecognizerService.onNoGesturesDetected = { [weak self] in
            self?.handleNoBodyDetection(isArmRaise: false)
        }
    }

    private func handleArmRaiseLandmarks(_ landmarks: [LandmarkPoint]) {
        let settings = AppSettings.shared
        guard settings.selectionMode == "armRaise", isTracking else { return }

        let now = CACurrentMediaTime()
        if now - lastSuccessfulDetectionTime > trackingLossResetThreshold {
            armRaiseDetector.reset()
        }
        lastSuccessfulDetectionTime = now

        let nowMs = now * 1000

        let config = ArmRaiseDetectorConfig(
            margin: armRaiseMargin,
            holdMs: settings.dwellTime * 1000,
            cooldownMs: armRaiseCooldownMs,
            flipMediaPipeLaterality: true
        )
        let result = armRaiseDetector.process(
            landmarks: landmarks,
            visibilities: nil,
            now: nowMs,
            config: config
        )

        DispatchQueue.main.async { [weak self] in
            guard let self, AppSettings.shared.selectionMode == "armRaise" else { return }
            self.armState = result.state
            self.bodyTrackingErrorMessage = nil
            self.showTrackingError = false
            if let side = result.activation {
                self.armRaiseActivation.send(side)
            }
        }
    }

    private func handleHandGestures(_ hands: [DetectedHandGesture]) {
        let settings = AppSettings.shared
        guard settings.selectionMode == "handGesture", isTracking else { return }

        let now = CACurrentMediaTime()
        if now - lastSuccessfulDetectionTime > trackingLossResetThreshold {
            handGestureDetector.reset()
        }
        lastSuccessfulDetectionTime = now

        let nowMs = now * 1000

        let config = HandGestureDetectorConfig(
            minScore: handGestureMinScore,
            stableFrames: handGestureStableFrames,
            cooldownMs: handGestureCooldownMs
        )
        let result = handGestureDetector.process(
            hands: hands,
            now: nowMs,
            config: config
        )

        DispatchQueue.main.async { [weak self] in
            guard let self, AppSettings.shared.selectionMode == "handGesture" else { return }
            self.handState = result.state
            self.bodyTrackingErrorMessage = nil
            self.showTrackingError = false
            if let side = result.activation {
                self.handGestureActivation.send(side)
            }
        }
    }

    private func handleNoBodyDetection(isArmRaise: Bool) {
        let settings = AppSettings.shared
        let expectedMode = isArmRaise ? "armRaise" : "handGesture"
        guard settings.selectionMode == expectedMode, isTracking else { return }

        let now = CACurrentMediaTime()
        let isWarmingUp = (now - trackingStartTime) < warmupDuration

        DispatchQueue.main.async { [weak self] in
            guard let self, AppSettings.shared.selectionMode == expectedMode else { return }
            if isArmRaise {
                self.armState = ArmRaiseState(leftRaised: false, rightRaised: false)
            } else {
                self.handState = HandGestureState(leftPose: nil, rightPose: nil)
            }

            if isWarmingUp {
                self.bodyTrackingErrorMessage = nil
                self.showTrackingError = false
            } else if settings.showTrackingErrorBanner {
                self.bodyTrackingErrorMessage = isArmRaise
                    ? "Body not detected — step back so your shoulders are visible"
                    : "Hands not detected — hold your hands in view of the camera"
                self.showTrackingError = true
            } else {
                self.bodyTrackingErrorMessage = nil
                self.showTrackingError = false
            }
        }
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
        // Keep user intent (`isTracking`); face loss must not disable recovery.
        guard isTracking, cameraManager.captureSession.isRunning else { return }

        let now = CACurrentMediaTime()
        let isWarmingUp = (now - trackingStartTime) < warmupDuration

        guard let landmarks, !landmarks.isEmpty else {
            if AppSettings.shared.enableTrackingDiagnostics {
                diagnosticsMissCount += 1
            }
            if let last = lastValidPosition, (now - lastLandmarkTime) < 0.5 {
                gazePosition = last
                isFaceDetected = true
                showTrackingError = false
            } else {
                isFaceDetected = false
                isCursorVisible = false
                showTrackingError = isWarmingUp ? false : settings.showTrackingErrorBanner
            }
            return
        }

        if now - lastSuccessfulDetectionTime > trackingLossResetThreshold {
            headPoseTracker.reset()
            lastValidPosition = nil
        }
        lastSuccessfulDetectionTime = now
        isRecovering = false
        if AppSettings.shared.enableTrackingDiagnostics {
            diagnosticsSuccessCount += 1
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

        // Blink detection for double-blink recenter in head tracking mode
        if settings.enableDoubleBlinkRecenter {
            let isBlinking = headPoseTracker.detectBlink(landmarks: landmarks)
            processHeadBlinkDetection(isBlinking: isBlinking, landmarks: landmarks, now: now)
        }

        // Out-of-bounds handling
        let outOfBounds = result.isOutOfBounds && settings.enableOutOfBoundsHiding

        let target = CGPoint(x: CGFloat(result.screenX), y: CGFloat(result.screenY))
        
        isFaceDetected = true
        showTrackingError = false
        lastLandmarkTime = now
        isGazeOutOfBounds = result.isOutOfBounds
        
        if isWarmingUp {
            isCursorVisible = false
        } else {
            gazePosition = target
            isCursorVisible = !outOfBounds
            lastValidPosition = target
        }
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
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let scene else { return .zero }
        if let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            return window.bounds
        }
        return scene.screen.bounds
    }

    private func currentInterfaceOrientation() -> UIInterfaceOrientation {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            return .unknown
        }
        if #available(iOS 18.0, *) {
            return scene.effectiveGeometry.interfaceOrientation
        }
        return scene.interfaceOrientation
    }

    private func configureDiagnosticsIfNeeded() {
        stopDiagnostics()
        guard AppSettings.shared.enableTrackingDiagnostics else { return }

        diagnosticsStartTime = CACurrentMediaTime()
        diagnosticsInputFrameCount = 0
        diagnosticsProcessedFrameCount = 0
        diagnosticsThrottledFrameCount = 0
        diagnosticsSuccessCount = 0
        diagnosticsMissCount = 0
        diagnosticsWatchdogReinitCount = 0
        diagnosticsOrientationReinitCount = 0
        diagnosticsEyeLatencyTotalMs = 0
        diagnosticsEyeLatencyMaxMs = 0
        diagnosticsEyeLatencySamples = 0

        diagnosticsTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.logDiagnosticsSnapshot()
        }
        DebugLog.info("Tracking diagnostics enabled", tag: "Tracking")
    }

    private func stopDiagnostics() {
        diagnosticsTimer?.invalidate()
        diagnosticsTimer = nil
    }

    private func logDiagnosticsSnapshot() {
        guard AppSettings.shared.enableTrackingDiagnostics else { return }

        let elapsed = max(CACurrentMediaTime() - diagnosticsStartTime, 0.001)
        let inputFps = Double(diagnosticsInputFrameCount) / elapsed
        let processedFps = Double(diagnosticsProcessedFrameCount) / elapsed
        let successRate = diagnosticsProcessedFrameCount > 0
            ? (Double(diagnosticsSuccessCount) / Double(diagnosticsProcessedFrameCount)) * 100.0
            : 0.0
        let avgEyeMs = diagnosticsEyeLatencySamples > 0
            ? diagnosticsEyeLatencyTotalMs / Double(diagnosticsEyeLatencySamples)
            : 0.0

        DebugLog.info(
            """
            Diagnostics: inputFps=\(String(format: "%.1f", inputFps)) processedFps=\(String(format: "%.1f", processedFps)) \
            throttled=\(diagnosticsThrottledFrameCount) successRate=\(String(format: "%.1f", successRate))% \
            misses=\(diagnosticsMissCount) reinit(watchdog/orientation)=\(diagnosticsWatchdogReinitCount)/\(diagnosticsOrientationReinitCount) \
            eyeLatency(avg/max)=\(String(format: "%.1f", avgEyeMs))/\(String(format: "%.1f", diagnosticsEyeLatencyMaxMs))ms
            """,
            tag: "Tracking"
        )
    }

    private var frameCountSinceStart = 0

    private func handleFrame(_ sampleBuffer: CMSampleBuffer) {
        // Allow runtime toggling of diagnostics without restarting tracking.
        if AppSettings.shared.enableTrackingDiagnostics {
            if diagnosticsTimer == nil {
                configureDiagnosticsIfNeeded()
            }
        } else if diagnosticsTimer != nil {
            stopDiagnostics()
        }

        // Frame rate throttling to reduce jitter
        let now = CACurrentMediaTime()
        if AppSettings.shared.enableTrackingDiagnostics {
            diagnosticsInputFrameCount += 1
        }
        
        // Watchdog timer check: if we haven't seen a detection for a while, recover
        // MediaPipe and restart capture if the session died (watchdog used to only
        // reinit MediaPipe, leaving a dead capture session stuck).
        if (now - lastSuccessfulDetectionTime) > watchdogTimeout {
            reinitializeIfAllowed(reason: "watchdog")
            if !cameraManager.captureSession.isRunning && isTracking && !isModalOpen {
                DebugLog.warn("Watchdog: capture session not running — restarting camera", tag: "Tracking")
                cameraManager.start()
            }
            lastSuccessfulDetectionTime = now
            return
        }

        let settings = AppSettings.shared
        let frameInterval = Self.isBodyGestureMode(settings.selectionMode) ? minBodyFrameInterval : minFrameInterval

        guard now - lastFrameProcessedTime >= frameInterval else {
            if AppSettings.shared.enableTrackingDiagnostics {
                diagnosticsThrottledFrameCount += 1
            }
            return
        }
        lastFrameProcessedTime = now
        if AppSettings.shared.enableTrackingDiagnostics {
            diagnosticsProcessedFrameCount += 1
        }

        // Use the camera manager's tracked orientation rather than hardcoding
        let orientation = cameraManager.mediaPipeSampleBufferOrientation

        applyCurrentSettings(settings)
        applySelectionModeBehavior(settings)

        if settings.selectionMode == "armRaise" {
            poseLandmarkService.updateLatestSampleBuffer(sampleBuffer, orientation: orientation)
        } else if settings.selectionMode == "handGesture" {
            gestureRecognizerService.updateLatestSampleBuffer(sampleBuffer, orientation: orientation)
        } else {
            faceLandmarkService.updateLatestSampleBuffer(sampleBuffer, orientation: orientation)
        }

        frameCountSinceStart += 1
        // Log the first few frames to confirm which path is taken
        if frameCountSinceStart <= 3 {
            DebugLog.debug("Frame #\(frameCountSinceStart): mode=\(settings.selectionMode), imgOrientation=\(orientation.rawValue)", tag: "Camera")
        }

        if settings.selectionMode == "face" {
            faceLandmarkService.requestDetection()
        } else if settings.selectionMode == "eyeGaze" {
            processGazeFrame()
        } else if settings.selectionMode == "armRaise" {
            poseLandmarkService.requestDetection()
        } else if settings.selectionMode == "handGesture" {
            gestureRecognizerService.requestDetection()
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
        let frameEpoch = trackingEpoch
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
                self.handleNoGaze(epoch: frameEpoch)
                self.logEyeDiagnostics()
                return
            }

            guard let result = result else {
                self.eyeNullCount += 1
                self.handleNoGaze(epoch: frameEpoch)
                self.logEyeDiagnostics()
                return
            }

            self.eyeSuccessCount += 1
            self.logEyeDiagnostics()
            self.handleGazeResult(result, gazeTracker: gazeTracker, epoch: frameEpoch)
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

    private func handleNoGaze(epoch: UInt64) {
        guard epoch == trackingEpoch else { return }
        if AppSettings.shared.enableTrackingDiagnostics {
            diagnosticsMissCount += 1
        }
        // Hop to main early — MediaPipe/Kotlin callbacks are off-main.
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.handleNoGaze(epoch: epoch)
            }
            return
        }
        guard epoch == trackingEpoch else { return }

        let now = CACurrentMediaTime()
        let isWarmingUp = (now - trackingStartTime) < warmupDuration

        if let last = lastValidPosition, (now - lastLandmarkTime) < 0.5 {
            gazePosition = last
            isFaceDetected = true
            showTrackingError = false
        } else {
            // Hold tracking intent so recovery works when gaze returns.
            isFaceDetected = false
            isCursorVisible = false
            showTrackingError = isWarmingUp ? false : AppSettings.shared.showTrackingErrorBanner
        }
    }

    private var gazeResultLogCount = 0

    private func handleGazeResult(_ result: GazeResult, gazeTracker: GazeTracker, epoch: UInt64) {
        guard epoch == trackingEpoch else { return }

        // Funnel all shared-state mutation onto the main queue early (~20 Hz).
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.handleGazeResult(result, gazeTracker: gazeTracker, epoch: epoch)
            }
            return
        }
        guard epoch == trackingEpoch else { return }

        gazeResultLogCount += 1
        if gazeResultLogCount <= 5 {
            DebugLog.info("Result #\(gazeResultLogCount): gazeX=\(String(format: "%.3f", result.gazeX)) gazeY=\(String(format: "%.3f", result.gazeY)) conf=\(String(format: "%.2f", result.confidence)) blink=\(result.leftBlink)/\(result.rightBlink)", tag: "EyeGaze")
        }

        let now = CACurrentMediaTime()
        let isWarmingUp = (now - trackingStartTime) < warmupDuration

        if now - lastSuccessfulDetectionTime > trackingLossResetThreshold {
            gazeTracker.reset()
            lastValidPosition = nil
        }
        // Face is present even during both-eyes blink — keep recovery healthy.
        lastSuccessfulDetectionTime = now
        isRecovering = false
        isFaceDetected = true
        showTrackingError = false
        if AppSettings.shared.enableTrackingDiagnostics {
            diagnosticsSuccessCount += 1
            let latencyMs = (now - lastProcessingStartTime) * 1000.0
            diagnosticsEyeLatencyTotalMs += latencyMs
            diagnosticsEyeLatencyMaxMs = max(diagnosticsEyeLatencyMaxMs, latencyMs)
            diagnosticsEyeLatencySamples += 1
        }

        // Blink detection: both eyes must blink. Skip cursor motion while closed
        // so iris-less blink frames cannot jump the pointer.
        let isBlinking = result.leftBlink && result.rightBlink
        processBlinkDetection(isBlinking: isBlinking, now: now)

        if isBlinking {
            lastLandmarkTime = now
            return
        }

        let rawX = result.gazeX
        let rawY = result.gazeY

        lastRawGazeX = rawX
        lastRawGazeY = rawY
        rawGazeX = rawX
        rawGazeY = rawY

        // Auto-recenter
        processAutoRecenter(rawX: rawX, rawY: rawY, now: now)

        // OOB from unclamped adjusted gaze BEFORE clamping to [-1, 1]
        let adjustedXUnclamped = rawX - gazeOffsetX
        let adjustedYUnclamped = rawY - gazeOffsetY
        updateGazeOutOfBoundsState(
            gazeX: adjustedXUnclamped,
            gazeY: adjustedYUnclamped,
            now: now,
            isWarmingUp: isWarmingUp
        )

        let adjustedX = adjustedXUnclamped.coerceIn(min: -1, max: 1)
        let adjustedY = adjustedYUnclamped.coerceIn(min: -1, max: 1)

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

        guard epoch == trackingEpoch else { return }

        lastLandmarkTime = now

        if isWarmingUp {
            // Hide during warmup; do not let OOB async races leave cursor stuck hidden.
            isCursorVisible = false
        } else {
            gazePosition = finalPosition
            lastValidPosition = finalPosition
            // Visibility already set synchronously in updateGazeOutOfBoundsState
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

    private func reinitializeIfAllowed(reason: String) {
        let now = CACurrentMediaTime()
        let elapsedSinceLast = now - lastReinitializeTime
        guard elapsedSinceLast >= reinitializeCooldown else {
            DebugLog.debug(
                "Skipped reinitialize (\(reason)); cooldown \(String(format: "%.1f", reinitializeCooldown - elapsedSinceLast))s remaining",
                tag: "Tracking"
            )
            return
        }

        lastReinitializeTime = now
        isRecovering = true
        if AppSettings.shared.enableTrackingDiagnostics {
            if reason == "watchdog" {
                diagnosticsWatchdogReinitCount += 1
            } else if reason == "orientation" {
                diagnosticsOrientationReinitCount += 1
            }
        }

        let mode = AppSettings.shared.selectionMode
        if mode == "armRaise" {
            poseLandmarkService.reinitialize()
        } else if mode == "handGesture" {
            gestureRecognizerService.reinitialize()
        } else {
            faceLandmarkService.reinitialize()
        }
    }

    private func applyOrientationChange() {
        let supported = CameraManager.isTrackingSupportedOrientation
        let settings = AppSettings.shared
        let currentOrientation = currentInterfaceOrientation()
        let orientationChanged = currentOrientation != .unknown && currentOrientation != lastKnownOrientation

        if supported && settings.selectionMode != "none" && !isModalOpen {
            if orientationChanged {
                DebugLog.info("Orientation changed — reinitializing tracking", tag: "Orientation")
                reinitializeIfAllowed(reason: "orientation")
                lastKnownOrientation = currentOrientation
            }

            let screenBounds = currentScreenBounds()
            if screenBounds.width > 0, screenBounds.height > 0 {
                gazeTracker?.updateScreenDimensions(
                    width: Int32(screenBounds.width),
                    height: Int32(screenBounds.height)
                )
                _ = gazeTracker?.loadCalibration()
            }

            if orientationChanged {
                dwellManager.cancelDwellForLayoutChange()
            }

            if !Self.isBodyGestureMode(settings.selectionMode) {
                headPoseTracker.reset()
                lastValidPosition = nil
                lastRawGazeX = nil
                lastRawGazeY = nil
                gazeOffsetX = 0
                gazeOffsetY = 0
            } else {
                armRaiseDetector.reset()
                handGestureDetector.reset()
            }
            
            if !isTracking || !cameraManager.captureSession.isRunning {
                startTracking()
            }
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

        if settings.switchControlEnabled {
            switchManager.initialize()
        }
    }

    /// Apply current settings to the switch control manager.
    func applySwitchSettings(_ settings: AppSettings) {
        switchManager.apply(configuration: settings.switchControlConfiguration())
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
        // Users rely on this button to recenter the cursor. Clearing calibration
        // math alone left gazeOffsetX/Y untouched — also run the double-blink path.
        recenterCursor()
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
        } else {
            gazeOffsetX = 0
            gazeOffsetY = 0
        }

        gazeTracker?.reset()

        let bounds = currentScreenBounds()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if Thread.isMainThread {
            gazePosition = center
            lastValidPosition = center
            isCursorVisible = true
            isGazeOutOfBounds = false
        } else {
            DispatchQueue.main.async {
                self.gazePosition = center
                self.lastValidPosition = center
                self.isCursorVisible = true
                self.isGazeOutOfBounds = false
            }
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

    private func updateGazeOutOfBoundsState(
        gazeX: Float,
        gazeY: Float,
        now: TimeInterval,
        isWarmingUp: Bool
    ) {
        // Called on main — mutate synchronously so warmup cannot race async visibility.
        guard AppSettings.shared.enableOutOfBoundsHiding else {
            isGazeOutOfBounds = false
            if !isWarmingUp {
                isCursorVisible = true
            }
            return
        }

        let isOutOfBounds = abs(gazeX) > gazeOutOfBoundsThreshold || abs(gazeY) > gazeOutOfBoundsThreshold

        if isOutOfBounds {
            if gazeOutOfBoundsStartTime == 0 {
                gazeOutOfBoundsStartTime = now
            } else if now - gazeOutOfBoundsStartTime > outOfBoundsTimeout {
                isGazeOutOfBounds = true
                if !isWarmingUp {
                    isCursorVisible = false
                }
            }
        } else {
            gazeOutOfBoundsStartTime = 0
            isGazeOutOfBounds = false
            if !isWarmingUp {
                isCursorVisible = true
            }
        }
    }

    // MARK: - Capture interruption / background recovery

    /// Call from the app when scene moves to background/inactive.
    func handleScenePhase(_ phase: String) {
        switch phase {
        case "background", "inactive":
            if isTracking {
                DebugLog.info("Scene \(phase) — pausing capture", tag: "Tracking")
                cameraManager.stop()
                processingLock.lock()
                _isProcessingFrame = false
                processingLock.unlock()
                faceLandmarkService.resetProcessingState()
                poseLandmarkService.resetProcessingState()
                gestureRecognizerService.resetProcessingState()
            }
        case "active":
            if isTracking && !isModalOpen && !cameraManager.captureSession.isRunning {
                DebugLog.info("Scene active — resuming capture", tag: "Tracking")
                lastSuccessfulDetectionTime = CACurrentMediaTime()
                trackingStartTime = CACurrentMediaTime()
                cameraManager.start()
            }
        default:
            break
        }
    }

    private func handleCaptureInterrupted() {
        DebugLog.warn("Capture session interrupted", tag: "Tracking")
        processingLock.lock()
        _isProcessingFrame = false
        processingLock.unlock()
    }

    private func handleCaptureResumed() {
        DebugLog.info("Capture session interruption ended", tag: "Tracking")
        lastSuccessfulDetectionTime = CACurrentMediaTime()
        if isTracking && !isModalOpen && !cameraManager.captureSession.isRunning {
            cameraManager.start()
        }
    }

    private func handleCaptureRuntimeError() {
        DebugLog.error("Capture runtime error / media services reset — restarting session", tag: "Tracking")
        processingLock.lock()
        _isProcessingFrame = false
        processingLock.unlock()
        guard isTracking, !isModalOpen else { return }
        cameraManager.stop()
        faceLandmarkService.reinitialize()
        poseLandmarkService.reinitialize()
        gestureRecognizerService.reinitialize()
        lastSuccessfulDetectionTime = CACurrentMediaTime()
        cameraManager.start()
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
