package com.vocable.eyetracking

import com.vocable.eyetracking.calibration.GazeCalibration
import com.vocable.eyetracking.models.*
import com.vocable.eyetracking.smoothing.AdaptiveKalmanFilter2D
import com.vocable.eyetracking.smoothing.KalmanFilter2D
import com.vocable.platform.FaceLandmarkDetector
import com.vocable.platform.Logger
import com.vocable.platform.Storage

/**
 * Main gaze tracking coordinator for KMP.
 *
 * This class orchestrates the entire gaze tracking pipeline:
 * 1. Face landmark detection (via platform-specific detector)
 * 2. Gaze calculation (pure Kotlin math)
 * 3. Smoothing/filtering (Kalman filters)
 * 4. Calibration application
 * 5. Screen coordinate mapping
 *
 * All the heavy algorithmic work is in shared commonMain code,
 * only camera capture and MediaPipe bindings are platform-specific.
 */
class GazeTracker(
    private val faceLandmarkDetector: FaceLandmarkDetector,
    private var screenWidth: Int,
    private var screenHeight: Int,
    private val storage: Storage,
    private val logger: Logger? = null
) {
    // Gaze calculation
    private val gazeCalculator = IrisGazeCalculator()
    private val eyeball3DCalculator = Eyeball3DGazeCalculator()

    // Smoothing filters
    private val kalmanFilter = KalmanFilter2D()
    private val adaptiveKalmanFilter = AdaptiveKalmanFilter2D()

    // Calibration
    private val calibration = GazeCalibration(
        screenWidth = screenWidth,
        screenHeight = screenHeight,
        logger = { message -> logger?.debug(message) }
    )

    // Configuration
    var smoothingMode: SmoothingMode = SmoothingMode.ADAPTIVE_KALMAN
    var eyeSelection: EyeSelection = EyeSelection.BOTH_EYES
    var trackingMethod: TrackingMethod = TrackingMethod.IRIS_2D

    /**
     * Set the lerp interpolation factor for SIMPLE_LERP and COMBINED modes.
     * Higher = more responsive but more jittery. Lower = smoother but more lag.
     * Typically 0.2 to 0.8. Maps from the user's sensitivity setting.
     */
    fun setLerpFactor(factor: Float) {
        lerpFactor = factor.coerceIn(0.05f, 1.0f)
    }

    /**
     * Set gaze calculator offsets (for camera position compensation).
     * Applied after iris position calculation.
     * @param offsetX Horizontal offset (-1 to 1, negative = shift gaze left)
     * @param offsetY Vertical offset (-1 to 1, positive = shift gaze down)
     */
    fun setGazeOffsets(offsetX: Float, offsetY: Float) {
        gazeCalculator.offsetX = offsetX.coerceIn(-1f, 1f)
        gazeCalculator.offsetY = offsetY.coerceIn(-1f, 1f)
    }

    /**
     * Set gaze calculator sensitivity multipliers.
     */
    fun setGazeSensitivity(sensitivityX: Float, sensitivityY: Float) {
        gazeCalculator.sensitivityX = sensitivityX.coerceIn(0.5f, 5f)
        gazeCalculator.sensitivityY = sensitivityY.coerceIn(0.5f, 5f)
    }

    /**
     * Update screen dimensions after a device orientation change.
     * This updates both the GazeTracker and its internal calibration so
     * that gaze-to-screen mapping uses the correct width/height.
     *
     * Note: saved calibration may not apply after a dimension change
     * (it was calibrated for the previous orientation), so the fallback
     * linear mapping will be used unless the user re-calibrates.
     */
    fun updateScreenDimensions(width: Int, height: Int) {
        if (width == screenWidth && height == screenHeight) return
        logger?.debug("Screen dimensions updated: ${screenWidth}x${screenHeight} -> ${width}x${height}")
        screenWidth = width
        screenHeight = height
        calibration.screenWidth = width
        calibration.screenHeight = height
    }

    /**
     * Check if current smoothing mode uses screen-level lerp (for caller to decide).
     * On Android, only SIMPLE_LERP uses double-layer smoothing (gaze lerp + screen lerp).
     */
    fun usesScreenLerp(): Boolean = smoothingMode == SmoothingMode.SIMPLE_LERP

    // Eye landmark indices (MediaPipe Face Mesh)
    companion object {
        // Left eye
        const val LEFT_EYE_OUTER = 33
        const val LEFT_EYE_INNER = 133
        const val LEFT_IRIS_CENTER = 468
        const val LEFT_EYE_TOP = 159
        const val LEFT_EYE_BOTTOM = 145

        // Right eye
        const val RIGHT_EYE_OUTER = 362
        const val RIGHT_EYE_INNER = 263
        const val RIGHT_IRIS_CENTER = 473
        const val RIGHT_EYE_TOP = 386
        const val RIGHT_EYE_BOTTOM = 374
    }

    /**
     * Process a frame and estimate gaze.
     */
    suspend fun processFrame(): GazeResult? {
        val landmarkResult = faceLandmarkDetector.detectLandmarks() ?: return null

        val landmarks = landmarkResult.landmarks
        val frameWidth = landmarkResult.frameWidth.toFloat()
        val frameHeight = landmarkResult.frameHeight.toFloat()

        val timestampMs = landmarkResult.timestamp
        return when (trackingMethod) {
            TrackingMethod.IRIS_2D -> process2D(landmarks, frameWidth, frameHeight, timestampMs)
            TrackingMethod.EYEBALL_3D -> process3D(landmarks, frameWidth, frameHeight, timestampMs)
        }
    }

    private fun process2D(
        landmarks: List<com.vocable.eyetracking.models.LandmarkPoint>,
        frameWidth: Float,
        frameHeight: Float,
        timestampMs: Long = 0L
    ): GazeResult? {
        // Estimate head pose
        val (headYaw, headPitch, headRoll) = gazeCalculator.estimateHeadPose(landmarks)

        // Detect blinks (EAR-based, distance-invariant)
        val leftBlink = if (landmarks.size > maxOf(LEFT_EYE_TOP, LEFT_EYE_BOTTOM, LEFT_EYE_OUTER, LEFT_EYE_INNER)) {
            gazeCalculator.detectBlink(
                eyeTop = landmarks[LEFT_EYE_TOP],
                eyeBottom = landmarks[LEFT_EYE_BOTTOM],
                eyeOuter = landmarks[LEFT_EYE_OUTER],
                eyeInner = landmarks[LEFT_EYE_INNER],
                frameWidth = frameWidth,
                frameHeight = frameHeight
            )
        } else false

        val rightBlink = if (landmarks.size > maxOf(RIGHT_EYE_TOP, RIGHT_EYE_BOTTOM, RIGHT_EYE_OUTER, RIGHT_EYE_INNER)) {
            gazeCalculator.detectBlink(
                eyeTop = landmarks[RIGHT_EYE_TOP],
                eyeBottom = landmarks[RIGHT_EYE_BOTTOM],
                eyeOuter = landmarks[RIGHT_EYE_OUTER],
                eyeInner = landmarks[RIGHT_EYE_INNER],
                frameWidth = frameWidth,
                frameHeight = frameHeight
            )
        } else false

        // Both eyes blinking: no iris data is available, but the caller still
        // needs a result carrying the blink flags so double-blink recenter can
        // fire. Reuse the last known gaze so the cursor holds position.
        if (leftBlink && rightBlink) {
            return blinkOnlyResult(headYaw, headPitch, headRoll)
        }

        // Calculate iris positions
        var leftGaze: FloatArray? = null
        var leftIrisCenter: Pair<Float, Float>? = null
        var rightGaze: FloatArray? = null
        var rightIrisCenter: Pair<Float, Float>? = null

        val useLeftEye = eyeSelection == EyeSelection.BOTH_EYES || eyeSelection == EyeSelection.LEFT_EYE_ONLY
        if (useLeftEye && !leftBlink && landmarks.size > LEFT_IRIS_CENTER) {
            val (gaze, center) = gazeCalculator.calculateIrisPosition(
                outer = landmarks[LEFT_EYE_OUTER],
                inner = landmarks[LEFT_EYE_INNER],
                irisCenter = landmarks[LEFT_IRIS_CENTER],
                frameWidth = frameWidth,
                frameHeight = frameHeight
            )
            leftGaze = gaze
            leftIrisCenter = center
        }

        val useRightEye = eyeSelection == EyeSelection.BOTH_EYES || eyeSelection == EyeSelection.RIGHT_EYE_ONLY
        if (useRightEye && !rightBlink && landmarks.size > RIGHT_IRIS_CENTER) {
            val (gaze, center) = gazeCalculator.calculateIrisPosition(
                outer = landmarks[RIGHT_EYE_OUTER],
                inner = landmarks[RIGHT_EYE_INNER],
                irisCenter = landmarks[RIGHT_IRIS_CENTER],
                frameWidth = frameWidth,
                frameHeight = frameHeight
            )
            rightGaze = gaze
            rightIrisCenter = center
        }

        // Combine gaze based on eye selection
        val (combinedGaze, confidence) = when (eyeSelection) {
            EyeSelection.LEFT_EYE_ONLY -> {
                if (leftGaze != null) leftGaze to 1.0f else return null
            }
            EyeSelection.RIGHT_EYE_ONLY -> {
                if (rightGaze != null) rightGaze to 1.0f else return null
            }
            EyeSelection.BOTH_EYES -> {
                gazeCalculator.combineGaze(leftGaze, rightGaze)?.let {
                    it.first to it.second
                } ?: return null
            }
        }

        // Apply head pose compensation
        val (compensatedX, compensatedY) = gazeCalculator.applyHeadPoseCompensation(
            combinedGaze[0], combinedGaze[1], headYaw, headPitch
        )

        // Apply smoothing
        val (smoothedX, smoothedY) = applySmoothing(compensatedX, compensatedY, timestampMs)
        lastGazeX = smoothedX
        lastGazeY = smoothedY

        return GazeResult(
            gazeX = smoothedX,
            gazeY = smoothedY,
            leftIrisCenter = leftIrisCenter,
            rightIrisCenter = rightIrisCenter,
            confidence = confidence,
            leftBlink = leftBlink,
            rightBlink = rightBlink,
            headYaw = headYaw,
            headPitch = headPitch,
            headRoll = headRoll
        )
    }

    /**
     * Result emitted while both eyes are closed: carries the blink flags with
     * the last known gaze values (or center if none yet). The Swift side skips
     * cursor movement for these results, so the cursor holds still during the
     * blink instead of jumping.
     */
    private fun blinkOnlyResult(headYaw: Float, headPitch: Float, headRoll: Float): GazeResult {
        return GazeResult(
            gazeX = lastGazeX ?: 0f,
            gazeY = lastGazeY ?: 0f,
            leftIrisCenter = null,
            rightIrisCenter = null,
            confidence = 0f,
            leftBlink = true,
            rightBlink = true,
            headYaw = headYaw,
            headPitch = headPitch,
            headRoll = headRoll
        )
    }

    private fun process3D(
        landmarks: List<com.vocable.eyetracking.models.LandmarkPoint>,
        frameWidth: Float,
        frameHeight: Float,
        timestampMs: Long = 0L
    ): GazeResult? {
        val (headYaw, headPitch, headRoll) = eyeball3DCalculator.estimateHeadPose(
            landmarks,
            frameWidth,
            frameHeight
        )

        val leftBlink = eyeball3DCalculator.detectBlink(
            landmarks,
            Eyeball3DGazeCalculator.LEFT_EYE_TOP,
            Eyeball3DGazeCalculator.LEFT_EYE_BOTTOM,
            Eyeball3DGazeCalculator.LEFT_EYE_OUTER,
            Eyeball3DGazeCalculator.LEFT_EYE_INNER,
            frameWidth,
            frameHeight
        )
        val rightBlink = eyeball3DCalculator.detectBlink(
            landmarks,
            Eyeball3DGazeCalculator.RIGHT_EYE_TOP,
            Eyeball3DGazeCalculator.RIGHT_EYE_BOTTOM,
            Eyeball3DGazeCalculator.RIGHT_EYE_OUTER,
            Eyeball3DGazeCalculator.RIGHT_EYE_INNER,
            frameWidth,
            frameHeight
        )

        // See process2D: surface both-eye blinks instead of returning null.
        if (leftBlink && rightBlink) {
            return blinkOnlyResult(headYaw, headPitch, headRoll)
        }

        val useLeftEye = eyeSelection == EyeSelection.BOTH_EYES || eyeSelection == EyeSelection.LEFT_EYE_ONLY
        val useRightEye = eyeSelection == EyeSelection.BOTH_EYES || eyeSelection == EyeSelection.RIGHT_EYE_ONLY

        val leftEyeModel = if (useLeftEye && !leftBlink) {
            eyeball3DCalculator.buildEyeballModel(
                landmarks,
                Eyeball3DGazeCalculator.LEFT_EYE_OUTER,
                Eyeball3DGazeCalculator.LEFT_EYE_INNER,
                Eyeball3DGazeCalculator.LEFT_EYE_TOP,
                Eyeball3DGazeCalculator.LEFT_EYE_BOTTOM,
                Eyeball3DGazeCalculator.LEFT_IRIS_CENTER,
                frameWidth,
                frameHeight
            )
        } else null

        val rightEyeModel = if (useRightEye && !rightBlink) {
            eyeball3DCalculator.buildEyeballModel(
                landmarks,
                Eyeball3DGazeCalculator.RIGHT_EYE_OUTER,
                Eyeball3DGazeCalculator.RIGHT_EYE_INNER,
                Eyeball3DGazeCalculator.RIGHT_EYE_TOP,
                Eyeball3DGazeCalculator.RIGHT_EYE_BOTTOM,
                Eyeball3DGazeCalculator.RIGHT_IRIS_CENTER,
                frameWidth,
                frameHeight
            )
        } else null

        val combined = eyeball3DCalculator.combineGaze(
            leftEyeModel,
            rightEyeModel,
            headYaw,
            headPitch,
            eyeSelection
        ) ?: return null

        val (smoothedX, smoothedY) = applySmoothing(combined.first, combined.second, timestampMs)
        lastGazeX = smoothedX
        lastGazeY = smoothedY

        val leftIrisCenter = if (landmarks.size > Eyeball3DGazeCalculator.LEFT_IRIS_CENTER) {
            val iris = landmarks[Eyeball3DGazeCalculator.LEFT_IRIS_CENTER]
            Pair(iris.x * frameWidth, iris.y * frameHeight)
        } else null

        val rightIrisCenter = if (landmarks.size > Eyeball3DGazeCalculator.RIGHT_IRIS_CENTER) {
            val iris = landmarks[Eyeball3DGazeCalculator.RIGHT_IRIS_CENTER]
            Pair(iris.x * frameWidth, iris.y * frameHeight)
        } else null

        return GazeResult(
            gazeX = smoothedX,
            gazeY = smoothedY,
            leftIrisCenter = leftIrisCenter,
            rightIrisCenter = rightIrisCenter,
            confidence = combined.third,
            leftBlink = leftBlink,
            rightBlink = rightBlink,
            headYaw = headYaw,
            headPitch = headPitch,
            headRoll = headRoll
        )
    }

    // Simple lerp state for SIMPLE_LERP and COMBINED modes
    private var oldGazeX: Float? = null
    private var oldGazeY: Float? = null
    private var lerpFactor: Float = 0.3f

    // Last successfully computed gaze, reused for blink-only results
    private var lastGazeX: Float? = null
    private var lastGazeY: Float? = null

    // Elapsed-time tracking for dt-aware Kalman (nanoseconds from landmark timestamp
    // when available; otherwise wall-clock via successive processFrame calls).
    private var lastSmoothTimestampNs: Long? = null

    /**
     * Apply smoothing filter to gaze coordinates.
     */
    private fun applySmoothing(gazeX: Float, gazeY: Float, timestampMs: Long? = null): Pair<Float, Float> {
        val dt = computeSmoothDt(timestampMs)
        return when (smoothingMode) {
            SmoothingMode.SIMPLE_LERP -> {
                val ox = oldGazeX
                val oy = oldGazeY
                if (ox == null || oy == null) {
                    oldGazeX = gazeX
                    oldGazeY = gazeY
                    Pair(gazeX, gazeY)
                } else {
                    val nx = ox + lerpFactor * (gazeX - ox)
                    val ny = oy + lerpFactor * (gazeY - oy)
                    oldGazeX = nx
                    oldGazeY = ny
                    Pair(nx, ny)
                }
            }
            SmoothingMode.KALMAN_FILTER -> {
                val filtered = kalmanFilter.update(gazeX, gazeY, dt)
                Pair(filtered[0], filtered[1])
            }
            SmoothingMode.ADAPTIVE_KALMAN -> {
                val filtered = adaptiveKalmanFilter.update(gazeX, gazeY, dt)
                Pair(filtered[0], filtered[1])
            }
            SmoothingMode.COMBINED -> {
                // Adaptive Kalman first, then lerp for additional smoothing
                val filtered = adaptiveKalmanFilter.update(gazeX, gazeY, dt)
                val ox = oldGazeX
                val oy = oldGazeY
                if (ox == null || oy == null) {
                    oldGazeX = filtered[0]
                    oldGazeY = filtered[1]
                    Pair(filtered[0], filtered[1])
                } else {
                    val combinedLerp = (lerpFactor * 1.5f).coerceAtMost(1.0f)
                    val nx = ox + combinedLerp * (filtered[0] - ox)
                    val ny = oy + combinedLerp * (filtered[1] - oy)
                    oldGazeX = nx
                    oldGazeY = ny
                    Pair(nx, ny)
                }
            }
        }
    }

    private fun computeSmoothDt(timestampMs: Long?): Float {
        if (timestampMs == null || timestampMs <= 0L) {
            return KalmanFilter2D.DEFAULT_DT
        }
        val nowNs = timestampMs * 1_000_000L
        val previous = lastSmoothTimestampNs
        lastSmoothTimestampNs = nowNs
        if (previous == null) return KalmanFilter2D.DEFAULT_DT
        val dt = (nowNs - previous).toFloat() / 1_000_000_000f
        return if (dt <= 0f) KalmanFilter2D.DEFAULT_DT else dt
    }

    /**
     * Convert raw gaze to screen coordinates using calibration.
     */
    fun gazeToScreen(gazeResult: GazeResult): Pair<Int, Int> {
        return calibration.gazeToScreen(gazeResult.gazeX, gazeResult.gazeY)
    }

    /**
     * Get calibration manager for calibration operations.
     */
    fun getCalibration(): GazeCalibration = calibration

    /**
     * Get gaze calculator for adjusting parameters.
     */
    fun getGazeCalculator(): IrisGazeCalculator = gazeCalculator

    /**
     * Reset all filters and state.
     */
    fun reset() {
        kalmanFilter.reset()
        adaptiveKalmanFilter.reset()
        oldGazeX = null
        oldGazeY = null
        lastGazeX = null
        lastGazeY = null
        lastSmoothTimestampNs = null
    }

    /**
     * Save current calibration to storage.
     */
    fun saveCalibration(): Boolean {
        val data = calibration.getCalibrationData() ?: return false
        val mode = if (calibration.isPolynomialCalibration()) "polynomial" else "affine"
        return storage.saveCalibrationData(data, mode)
    }

    /**
     * Load calibration from storage.
     */
    fun loadCalibration(): Boolean {
        // Try polynomial first
        val polyData = storage.loadCalibrationData("polynomial")
        if (polyData != null) {
            return calibration.loadCalibrationData(polyData)
        }

        // Fallback to affine
        val affineData = storage.loadCalibrationData("affine")
        if (affineData != null) {
            return calibration.loadCalibrationData(affineData)
        }

        return false
    }
}
