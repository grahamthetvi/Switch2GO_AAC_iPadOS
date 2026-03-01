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
    private let leftEyeCorner = 33
    private let rightEyeCorner = 263
    private let leftEar = 234
    private let rightEar = 454
    private let leftEyeTop = 159
    private let leftEyeBottom = 145
    private let rightEyeTop = 386
    private let rightEyeBottom = 374

    // MARK: - Smoothing state

    private var kalmanX = SimpleKalmanFilter1D()
    private var kalmanY = SimpleKalmanFilter1D()
    private var oldSmoothedX: Float?
    private var oldSmoothedY: Float?

    // MARK: - Calibration state

    private var calibrationSamples: [(yaw: Float, pitch: Float)] = []

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
        let maxIdx = max(noseTip, chin, forehead, leftEyeCorner, rightEyeCorner, leftEar, rightEar)
        guard landmarks.count > maxIdx else { return nil }

        let nose = landmarks[noseTip]
        let chinLm = landmarks[chin]
        let foreheadLm = landmarks[forehead]
        let leftEarLm = landmarks[leftEar]
        let rightEarLm = landmarks[rightEar]
        let leftEye = landmarks[leftEyeCorner]
        let rightEye = landmarks[rightEyeCorner]

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

        normalizedX = clamp(normalizedX, -1, 1)
        normalizedY = clamp(normalizedY, -1, 1)

        // 3. Apply smoothing
        let (smoothedX, smoothedY) = applySmoothing(
            x: normalizedX,
            y: normalizedY,
            mode: smoothingMode,
            lerpFactor: lerpFactor
        )

        // 4. Map to screen coordinates (center-based)
        let screenX = clamp((smoothedX + 1) / 2 * screenWidth, 0, screenWidth)
        let screenY = clamp((smoothedY + 1) / 2 * screenHeight, 0, screenHeight)

        // 5. Out-of-bounds check (raw, pre-smoothing)
        let isOutOfBounds = abs(normalizedX) > 1.1 || abs(normalizedY) > 1.1

        return TrackingResult(
            screenX: screenX,
            screenY: screenY,
            headPose: pose,
            isOutOfBounds: isOutOfBounds
        )
    }

    // MARK: - Blink detection

    /// Detect if both eyes are blinking based on eyelid distance.
    func detectBlink(landmarks: [NormalizedLandmark]) -> Bool {
        let maxIdx = max(leftEyeTop, leftEyeBottom, rightEyeTop, rightEyeBottom)
        guard landmarks.count > maxIdx else { return false }

        let leftHeight = abs(landmarks[leftEyeBottom].y - landmarks[leftEyeTop].y)
        let rightHeight = abs(landmarks[rightEyeBottom].y - landmarks[rightEyeTop].y)

        // Both eyes must be nearly closed
        return leftHeight < 0.015 && rightHeight < 0.015
    }

    // MARK: - Neutral pose calibration

    /// Begin collecting samples for neutral pose calibration.
    /// User should look at the center of the screen.
    func beginNeutralPoseCalibration() {
        calibrationSamples.removeAll()
    }

    /// Add a calibration sample from the current landmarks.
    func addCalibrationSample(landmarks: [NormalizedLandmark]) {
        guard let pose = estimateHeadPose(landmarks: landmarks) else { return }
        calibrationSamples.append((yaw: pose.yaw, pitch: pose.pitch))
    }

    /// Finish calibration by averaging collected samples.
    /// Returns true if enough samples were collected (at least 10).
    func finishNeutralPoseCalibration() -> Bool {
        guard calibrationSamples.count >= 10 else { return false }

        // Use median-trimmed mean for robustness against outliers
        let sortedYaw = calibrationSamples.map(\.yaw).sorted()
        let sortedPitch = calibrationSamples.map(\.pitch).sorted()

        // Trim 20% from each end
        let trimCount = max(1, calibrationSamples.count / 5)
        let trimmedYaw = Array(sortedYaw[trimCount..<(sortedYaw.count - trimCount)])
        let trimmedPitch = Array(sortedPitch[trimCount..<(sortedPitch.count - trimCount)])

        guard !trimmedYaw.isEmpty, !trimmedPitch.isEmpty else { return false }

        cameraOffsetYaw = trimmedYaw.reduce(0, +) / Float(trimmedYaw.count)
        cameraOffsetPitch = trimmedPitch.reduce(0, +) / Float(trimmedPitch.count)

        return true
    }

    /// Quick recenter: set current head pose as the new neutral.
    func recenter(landmarks: [NormalizedLandmark]) {
        guard let pose = estimateHeadPose(landmarks: landmarks) else { return }
        cameraOffsetYaw = pose.yaw
        cameraOffsetPitch = pose.pitch
    }

    /// Reset calibration to defaults.
    func resetCalibration() {
        cameraOffsetYaw = 0
        cameraOffsetPitch = 0
        calibrationSamples.removeAll()
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
    }

    // MARK: - Smoothing

    private func applySmoothing(
        x: Float, y: Float,
        mode: String,
        lerpFactor: Float
    ) -> (Float, Float) {
        switch mode {
        case "none":
            oldSmoothedX = x
            oldSmoothedY = y
            return (x, y)

        case "simple":
            return applyLerp(x: x, y: y, alpha: lerpFactor)

        case "kalman":
            let fx = kalmanX.update(measurement: x)
            let fy = kalmanY.update(measurement: y)
            oldSmoothedX = fx
            oldSmoothedY = fy
            return (fx, fy)

        case "adaptive":
            let fx = kalmanX.updateAdaptive(measurement: x)
            let fy = kalmanY.updateAdaptive(measurement: y)
            oldSmoothedX = fx
            oldSmoothedY = fy
            return (fx, fy)

        case "combined":
            // Kalman first, then lerp for responsiveness
            let fx = kalmanX.updateAdaptive(measurement: x)
            let fy = kalmanY.updateAdaptive(measurement: y)
            return applyLerp(x: fx, y: fy, alpha: min(lerpFactor * 1.5, 1.0))

        default:
            let fx = kalmanX.updateAdaptive(measurement: x)
            let fy = kalmanY.updateAdaptive(measurement: y)
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
class SimpleKalmanFilter1D {
    private var estimate: Float = 0
    private var errorEstimate: Float = 1
    private var lastEstimate: Float = 0
    private var isInitialized = false

    // Tuning parameters
    private let processNoise: Float = 0.0001
    private let measurementNoise: Float = 0.01

    // Adaptive thresholds
    private let lowVelocityThreshold: Float = 0.02
    private let highVelocityThreshold: Float = 0.15

    func update(measurement: Float) -> Float {
        if !isInitialized {
            estimate = measurement
            lastEstimate = measurement
            isInitialized = true
            return measurement
        }

        // Predict
        let prediction = estimate
        errorEstimate += processNoise

        // Update
        let kalmanGain = errorEstimate / (errorEstimate + measurementNoise)
        estimate = prediction + kalmanGain * (measurement - prediction)
        errorEstimate = (1 - kalmanGain) * errorEstimate

        lastEstimate = estimate
        return estimate
    }

    /// Adaptive mode: lower noise during fast movement (responsive),
    /// higher noise during stillness (smooth).
    func updateAdaptive(measurement: Float) -> Float {
        if !isInitialized {
            estimate = measurement
            lastEstimate = measurement
            isInitialized = true
            return measurement
        }

        let velocity = abs(measurement - lastEstimate)
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
        errorEstimate += processNoise

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
