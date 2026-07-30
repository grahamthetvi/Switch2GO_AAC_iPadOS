import Foundation
import MediaPipeTasksVision

/// Robust head pose tracker using MediaPipe face landmarks.
///
/// Improvements over simple nose-tip mapping:
/// 1. Uses head pose estimation (yaw/pitch/roll) instead of raw landmark position
/// 2. Camera-offset calibration for off-center cameras (iPad left-side camera)
/// 3. Kalman filter smoothing (standard and adaptive modes)
/// 4. Blink detection for double-blink recenter
/// 5. Out-of-bounds detection
/// 6. Drift correction via auto-recenter
class HeadPoseTracker {

    // MARK: - Configuration

    /// Base sensitivity multipliers for pose-to-screen mapping.
    /// Higher = less head movement needed to reach screen edges.
    var sensitivityX: Float = 2.0
    var sensitivityY: Float = 2.5

    /// Camera offset: the head pose recorded when the user looks straight at screen center.
    /// Compensates for off-center cameras (e.g. iPad landscape left-side camera).
    var cameraOffsetYaw: Float = 0
    var cameraOffsetPitch: Float = 0

    // MARK: - Landmark indices (MediaPipe Face Mesh)

    private let noseTip = 1
    private let chin = 152
    private let forehead = 10
    private let leftEyeOuter = 33
    private let leftEyeInner = 133
    private let rightEyeOuter = 263
    private let rightEyeInner = 362
    private let leftEar = 234
    private let rightEar = 454
    private let leftEyeTop = 159
    private let leftEyeBottom = 145
    private let rightEyeTop = 386
    private let rightEyeBottom = 374

    /// Eye Aspect Ratio threshold (eyelid gap / eye width). Matches Kotlin BLINK_EAR_THRESHOLD.
    private let blinkEARThreshold: Float = 0.2

    // MARK: - Smoothing state

    private var kalmanX = SimpleKalmanFilter1D()
    private var kalmanY = SimpleKalmanFilter1D()
    private var oldSmoothedX: Float?
    private var oldSmoothedY: Float?
    private var lastSmoothTime: TimeInterval?

    // MARK: - Result types

    struct HeadPose {
        let yaw: Float    // -45..+45, positive = right
        let pitch: Float  // -45..+45, positive = down
        let roll: Float   // -45..+45, positive = tilt right
    }

    struct TrackingResult {
        let screenX: Float
        let screenY: Float
        let headPose: HeadPose
        let isOutOfBounds: Bool
    }

    // MARK: - Head pose estimation

    /// Estimate head orientation from face landmarks.
    /// Uses nose, ears, chin, forehead, and eye corners for robust estimation.
    func estimateHeadPose(landmarks: [NormalizedLandmark]) -> HeadPose? {
        let maxIdx = max(noseTip, chin, forehead, leftEyeOuter, rightEyeOuter, leftEar, rightEar)
        guard landmarks.count > maxIdx else { return nil }

        let nose = landmarks[noseTip]
        let chinLm = landmarks[chin]
        let foreheadLm = landmarks[forehead]
        let leftEarLm = landmarks[leftEar]
        let rightEarLm = landmarks[rightEar]
        let leftEye = landmarks[leftEyeOuter]
        let rightEye = landmarks[rightEyeOuter]

        // Yaw: nose position relative to ear midpoint
        // More robust than eye midpoint, especially with off-center cameras
        let earMidX = (leftEarLm.x + rightEarLm.x) / 2.0
        let rawYaw = (nose.x - earMidX) * 100.0

        // Pitch: nose vertical position relative to forehead-chin axis
        let faceHeight = chinLm.y - foreheadLm.y
        guard faceHeight > 0.01 else { return nil }
        let noseRelative = (nose.y - foreheadLm.y) / faceHeight
        let expectedNosePos: Float = 0.45
        let rawPitch = (noseRelative - expectedNosePos) * 150.0

        // Roll: angle between eye corners
        let eyeDeltaY = rightEye.y - leftEye.y
        let eyeDeltaX = rightEye.x - leftEye.x
        let rawRoll: Float = eyeDeltaX > 0.01
            ? atan2(eyeDeltaY, eyeDeltaX) * (180.0 / .pi)
            : 0

        return HeadPose(
            yaw: clamp(rawYaw, -45, 45),
            pitch: clamp(rawPitch, -45, 45),
            roll: clamp(rawRoll, -45, 45)
        )
    }

    // MARK: - Full processing pipeline

    /// Process landmarks through the full head tracking pipeline:
    /// pose estimation -> camera offset -> smoothing -> screen mapping -> out-of-bounds.
    func processLandmarks(
        landmarks: [NormalizedLandmark],
        screenWidth: Float,
        screenHeight: Float,
        smoothingMode: String,
        lerpFactor: Float
    ) -> TrackingResult? {
        guard let pose = estimateHeadPose(landmarks: landmarks) else { return nil }

        // 1. Apply camera offset (neutral pose calibration)
        let adjustedYaw = pose.yaw - cameraOffsetYaw
        let adjustedPitch = pose.pitch - cameraOffsetPitch

        // 2. Map head pose to normalized coordinates (-1 to 1)
        let maxAngle: Float = 30.0  // typical usable head rotation range
        var normalizedX = (adjustedYaw / maxAngle) * sensitivityX
        var normalizedY = (adjustedPitch / maxAngle) * sensitivityY

        // Out-of-bounds must use pre-clamp values (clamping then checking >1.1 is dead).
        let isOutOfBounds = abs(normalizedX) > 1.1 || abs(normalizedY) > 1.1

        normalizedX = clamp(normalizedX, -1, 1)
        normalizedY = clamp(normalizedY, -1, 1)

        // 3. Apply smoothing
        let now = CACurrentMediaTime()
        let dt: Float
        if let last = lastSmoothTime {
            let elapsed = Float(now - last)
            dt = elapsed > 0 ? min(max(elapsed, 1.0 / 120.0), 0.25) : (1.0 / 20.0)
        } else {
            dt = 1.0 / 20.0
        }
        lastSmoothTime = now

        let (smoothedX, smoothedY) = applySmoothing(
            x: normalizedX,
            y: normalizedY,
            mode: smoothingMode,
            lerpFactor: lerpFactor,
            dt: dt
        )

        // 4. Map to screen coordinates (center-based)
        let screenX = clamp((smoothedX + 1) / 2 * screenWidth, 0, screenWidth)
        let screenY = clamp((smoothedY + 1) / 2 * screenHeight, 0, screenHeight)

        return TrackingResult(
            screenX: screenX,
            screenY: screenY,
            headPose: pose,
            isOutOfBounds: isOutOfBounds
        )
    }

    // MARK: - Blink detection

    /// Detect if both eyes are blinking using Eye Aspect Ratio (EAR).
    /// EAR = eyelid gap / eye width — distance-invariant, matches Kotlin IrisGazeCalculator.
    func detectBlink(landmarks: [NormalizedLandmark]) -> Bool {
        let maxIdx = max(
            leftEyeTop, leftEyeBottom, leftEyeOuter, leftEyeInner,
            rightEyeTop, rightEyeBottom, rightEyeOuter, rightEyeInner
        )
        guard landmarks.count > maxIdx else { return false }

        let leftEAR = eyeAspectRatio(
            top: landmarks[leftEyeTop],
            bottom: landmarks[leftEyeBottom],
            outer: landmarks[leftEyeOuter],
            inner: landmarks[leftEyeInner]
        )
        let rightEAR = eyeAspectRatio(
            top: landmarks[rightEyeTop],
            bottom: landmarks[rightEyeBottom],
            outer: landmarks[rightEyeOuter],
            inner: landmarks[rightEyeInner]
        )

        return leftEAR < blinkEARThreshold && rightEAR < blinkEARThreshold
    }

    private func eyeAspectRatio(
        top: NormalizedLandmark,
        bottom: NormalizedLandmark,
        outer: NormalizedLandmark,
        inner: NormalizedLandmark
    ) -> Float {
        let eyeHeight = hypot(top.x - bottom.x, top.y - bottom.y)
        let eyeWidth = hypot(outer.x - inner.x, outer.y - inner.y)
        guard eyeWidth > 1e-6 else { return 1.0 }
        return eyeHeight / eyeWidth
    }

    /// Quick recenter: set current head pose as the new neutral.
    func recenter(landmarks: [NormalizedLandmark]) {
        guard let pose = estimateHeadPose(landmarks: landmarks) else { return }
        cameraOffsetYaw = pose.yaw
        cameraOffsetPitch = pose.pitch
    }

    /// Apply a pre-set camera position offset for common device layouts.
    func applyCameraPositionPreset(_ position: String) {
        switch position {
        case "left":
            // iPad landscape: camera on left side
            // User looking at center appears ~3-5 degrees right from camera's perspective
            cameraOffsetYaw = 4.0
            cameraOffsetPitch = 0.0
        case "right":
            cameraOffsetYaw = -4.0
            cameraOffsetPitch = 0.0
        case "center":
            cameraOffsetYaw = 0.0
            cameraOffsetPitch = 0.0
        default:
            break  // "custom" - keep current offsets
        }
    }

    // MARK: - Reset

    func reset() {
        kalmanX.reset()
        kalmanY.reset()
        oldSmoothedX = nil
        oldSmoothedY = nil
        lastSmoothTime = nil
    }

    // MARK: - Smoothing

    private func applySmoothing(
        x: Float, y: Float,
        mode: String,
        lerpFactor: Float,
        dt: Float
    ) -> (Float, Float) {
        switch mode {
        case "none":
            oldSmoothedX = x
            oldSmoothedY = y
            return (x, y)

        case "simple":
            return applyLerp(x: x, y: y, alpha: lerpFactor)

        case "kalman":
            let fx = kalmanX.update(measurement: x, dt: dt)
            let fy = kalmanY.update(measurement: y, dt: dt)
            oldSmoothedX = fx
            oldSmoothedY = fy
            return (fx, fy)

        case "adaptive":
            let fx = kalmanX.updateAdaptive(measurement: x, dt: dt)
            let fy = kalmanY.updateAdaptive(measurement: y, dt: dt)
            oldSmoothedX = fx
            oldSmoothedY = fy
            return (fx, fy)

        case "combined":
            // Kalman first, then lerp for responsiveness
            let fx = kalmanX.updateAdaptive(measurement: x, dt: dt)
            let fy = kalmanY.updateAdaptive(measurement: y, dt: dt)
            return applyLerp(x: fx, y: fy, alpha: min(lerpFactor * 1.5, 1.0))

        default:
            let fx = kalmanX.updateAdaptive(measurement: x, dt: dt)
            let fy = kalmanY.updateAdaptive(measurement: y, dt: dt)
            oldSmoothedX = fx
            oldSmoothedY = fy
            return (fx, fy)
        }
    }

    private func applyLerp(x: Float, y: Float, alpha: Float) -> (Float, Float) {
        let a = clamp(alpha, 0.05, 1.0)
        if let ox = oldSmoothedX, let oy = oldSmoothedY {
            let nx = ox + a * (x - ox)
            let ny = oy + a * (y - oy)
            oldSmoothedX = nx
            oldSmoothedY = ny
            return (nx, ny)
        } else {
            oldSmoothedX = x
            oldSmoothedY = y
            return (x, y)
        }
    }

    private func clamp(_ value: Float, _ lo: Float, _ hi: Float) -> Float {
        return Swift.min(Swift.max(value, lo), hi)
    }
}

// MARK: - Simple 1D Kalman Filter

/// Lightweight Kalman filter for smoothing a single axis.
/// Supports both standard and adaptive (velocity-aware) modes.
/// Velocity is expressed in units/second when `dt` is supplied.
class SimpleKalmanFilter1D {
    private var estimate: Float = 0
    private var errorEstimate: Float = 1
    private var lastEstimate: Float = 0
    private var isInitialized = false

    // Tuning parameters
    private let processNoise: Float = 0.0001
    private let measurementNoise: Float = 0.01

    // Adaptive thresholds in units/second (were ~per-frame at 20 FPS)
    private let lowVelocityThreshold: Float = 0.4
    private let highVelocityThreshold: Float = 3.0

    func update(measurement: Float, dt: Float = 1.0 / 20.0) -> Float {
        if !isInitialized {
            estimate = measurement
            lastEstimate = measurement
            isInitialized = true
            return measurement
        }

        // Predict (constant-position model; dt scales process noise modestly)
        let clampedDt = min(max(dt, 1.0 / 120.0), 0.25)
        let prediction = estimate
        errorEstimate += processNoise * (clampedDt * 20.0)

        // Update
        let kalmanGain = errorEstimate / (errorEstimate + measurementNoise)
        estimate = prediction + kalmanGain * (measurement - prediction)
        errorEstimate = (1 - kalmanGain) * errorEstimate

        lastEstimate = estimate
        return estimate
    }

    /// Adaptive mode: lower noise during fast movement (responsive),
    /// higher noise during stillness (smooth).
    func updateAdaptive(measurement: Float, dt: Float = 1.0 / 20.0) -> Float {
        if !isInitialized {
            estimate = measurement
            lastEstimate = measurement
            isInitialized = true
            return measurement
        }

        let clampedDt = min(max(dt, 1.0 / 120.0), 0.25)
        let velocity = abs(measurement - lastEstimate) / clampedDt
        let adaptiveNoise: Float
        if velocity < lowVelocityThreshold {
            // Dwelling: trust the prediction more (smoother)
            adaptiveNoise = measurementNoise * 3.0
        } else if velocity > highVelocityThreshold {
            // Rapid movement: trust measurements more (responsive)
            adaptiveNoise = measurementNoise * 0.3
        } else {
            adaptiveNoise = measurementNoise
        }

        // Predict
        let prediction = estimate
        errorEstimate += processNoise * (clampedDt * 20.0)

        // Update
        let kalmanGain = errorEstimate / (errorEstimate + adaptiveNoise)
        estimate = prediction + kalmanGain * (measurement - prediction)
        errorEstimate = (1 - kalmanGain) * errorEstimate

        lastEstimate = estimate
        return estimate
    }

    func reset() {
        estimate = 0
        errorEstimate = 1
        lastEstimate = 0
        isInitialized = false
    }
}
