package com.willowtree.vocable.eyegazetracking

import android.content.Context
import android.graphics.Bitmap
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import timber.log.Timber
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Eye gaze tracker using MediaPipe FaceLandmarker with Iris landmarks.
 *
 * This implementation uses MediaPipe's iris landmarks (468-477) to calculate
 * gaze direction based on iris position relative to eye corners. Combined with
 * Kalman filtering for smooth, stable gaze tracking.
 *
 * Based on: "MediaPipe Iris and Kalman Filter for Robust Eye Gaze Tracking"
 *
 * Key features:
 * - Real-time iris detection using landmarks 468-477
 * - Gaze vector calculation from iris position relative to eye corners
 * - Head pose compensation for improved accuracy
 * - Configurable sensitivity and offset for calibration
 * - Blink detection to avoid false readings during blinks
 * - Optional GPU acceleration
 */
class MediaPipeIrisGazeTracker(
    context: Context,
    useGpu: Boolean = false
) {

    companion object {
        // Model file path in assets
        private const val MODEL_PATH = "face_landmarker.task"

        // MediaPipe Face Mesh landmark indices for eyes
        // Left eye landmarks (from user's perspective - actually right side of image)
        private const val LEFT_EYE_OUTER = 33
        private const val LEFT_EYE_INNER = 133
        private const val LEFT_IRIS_CENTER = 468
        private val LEFT_IRIS_LANDMARKS = listOf(468, 469, 470, 471, 472)
        private const val LEFT_EYE_TOP = 159
        private const val LEFT_EYE_BOTTOM = 145

        // Right eye landmarks (from user's perspective - actually left side of image)
        private const val RIGHT_EYE_OUTER = 362
        private const val RIGHT_EYE_INNER = 263
        private const val RIGHT_IRIS_CENTER = 473
        private val RIGHT_IRIS_LANDMARKS = listOf(473, 474, 475, 476, 477)
        private const val RIGHT_EYE_TOP = 386
        private const val RIGHT_EYE_BOTTOM = 374

        // Blink detection threshold (eye aspect ratio)
        private const val BLINK_THRESHOLD = 0.015f

        // Head pose landmarks for compensation
        private const val NOSE_TIP = 1
        private const val CHIN = 152
        private const val LEFT_EYE_CORNER = 33
        private const val RIGHT_EYE_CORNER = 263
        private const val LEFT_EAR = 234
        private const val RIGHT_EAR = 454
    }

    /**
     * Result of gaze estimation containing normalized gaze coordinates.
     *
     * @param gazeX Horizontal gaze position (-1 = left, +1 = right)
     * @param gazeY Vertical gaze position (-1 = up, +1 = down)
     * @param leftIrisCenter Pixel coordinates of left iris center
     * @param rightIrisCenter Pixel coordinates of right iris center
     * @param confidence Detection confidence (0-1)
     * @param leftBlink Whether left eye is blinking
     * @param rightBlink Whether right eye is blinking
     * @param headYaw Head rotation around vertical axis (degrees, positive = right)
     * @param headPitch Head rotation around horizontal axis (degrees, positive = up)
     * @param headRoll Head rotation around forward axis (degrees, positive = tilt right)
     */
    data class GazeResult(
        val gazeX: Float,
        val gazeY: Float,
        val leftIrisCenter: Pair<Float, Float>? = null,
        val rightIrisCenter: Pair<Float, Float>? = null,
        val confidence: Float = 1.0f,
        val leftBlink: Boolean = false,
        val rightBlink: Boolean = false,
        val headYaw: Float = 0f,
        val headPitch: Float = 0f,
        val headRoll: Float = 0f
    )

    private var faceLandmarker: FaceLandmarker? = null
    private var isInitialized = false
    private var isUsingGpu = false

    // Gaze sensitivity multipliers (how much eye movement translates to cursor movement)
    var sensitivityX: Float = 2.5f
    var sensitivityY: Float = 3.0f

    // Gaze offsets (for correcting camera angle / head position bias)
    var offsetX: Float = 0.0f
    var offsetY: Float = 0.3f  // Default positive offset to shift gaze down (compensate for upward bias)

    // Head pose compensation enabled
    var headPoseCompensationEnabled: Boolean = true

    // Head pose compensation factors (how much head pose affects gaze correction)
    var headYawCompensation: Float = 0.3f
    var headPitchCompensation: Float = 0.25f

    // Eye selection - which eye(s) to use for tracking
    var eyeSelection: EyeSelection = EyeSelection.BOTH_EYES

    init {
        try {
            val delegate = if (useGpu) {
                Timber.d("Attempting to use GPU delegate for MediaPipe")
                Delegate.GPU
            } else {
                Delegate.CPU
            }

            val baseOptions = BaseOptions.builder()
                .setModelAssetPath(MODEL_PATH)
                .setDelegate(delegate)
                .build()

            val options = FaceLandmarker.FaceLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setRunningMode(RunningMode.IMAGE)
                .setNumFaces(1)
                .setMinFaceDetectionConfidence(0.5f)
                .setMinFacePresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setOutputFaceBlendshapes(false)
                .setOutputFacialTransformationMatrixes(true)  // Enable for head pose estimation
                .build()

            faceLandmarker = FaceLandmarker.createFromOptions(context, options)
            isInitialized = true
            isUsingGpu = useGpu
            Timber.d("MediaPipe Iris GazeTracker initialized successfully (GPU: $useGpu)")
        } catch (e: Exception) {
            if (useGpu) {
                // Fallback to CPU if GPU fails
                Timber.w(e, "GPU initialization failed, falling back to CPU")
                try {
                    val baseOptions = BaseOptions.builder()
                        .setModelAssetPath(MODEL_PATH)
                        .setDelegate(Delegate.CPU)
                        .build()

                    val options = FaceLandmarker.FaceLandmarkerOptions.builder()
                        .setBaseOptions(baseOptions)
                        .setRunningMode(RunningMode.IMAGE)
                        .setNumFaces(1)
                        .setMinFaceDetectionConfidence(0.5f)
                        .setMinFacePresenceConfidence(0.5f)
                        .setMinTrackingConfidence(0.5f)
                        .setOutputFaceBlendshapes(false)
                        .setOutputFacialTransformationMatrixes(true)
                        .build()

                    faceLandmarker = FaceLandmarker.createFromOptions(context, options)
                    isInitialized = true
                    isUsingGpu = false
                    Timber.d("MediaPipe Iris GazeTracker initialized with CPU fallback")
                } catch (fallbackEx: Exception) {
                    Timber.e(fallbackEx, "Failed to initialize MediaPipe Iris GazeTracker")
                }
            } else {
                Timber.e(e, "Failed to initialize MediaPipe Iris GazeTracker")
            }
        }
    }

    /**
     * Check if GPU acceleration is being used.
     */
    fun isUsingGpu(): Boolean = isUsingGpu

    /**
     * Process a camera frame and estimate gaze direction.
     *
     * @param bitmap Camera frame (will be processed as-is, caller should handle mirroring)
     * @return GazeResult with normalized gaze coordinates, or null if no face detected
     */
    fun estimateGaze(bitmap: Bitmap): GazeResult? {
        if (!isInitialized || faceLandmarker == null) {
            Timber.w("MediaPipe Iris GazeTracker not initialized")
            return null
        }

        return try {
            val mpImage = BitmapImageBuilder(bitmap).build()
            val result = faceLandmarker?.detect(mpImage)

            if (result == null || result.faceLandmarks().isEmpty()) {
                return null
            }

            val landmarks = result.faceLandmarks()[0]
            val frameWidth = bitmap.width.toFloat()
            val frameHeight = bitmap.height.toFloat()

            // Estimate head pose from landmarks
            val (headYaw, headPitch, headRoll) = estimateHeadPose(landmarks, frameWidth, frameHeight)

            // Check for blinks
            val leftBlink = detectBlink(landmarks, LEFT_EYE_TOP, LEFT_EYE_BOTTOM, frameHeight)
            val rightBlink = detectBlink(landmarks, RIGHT_EYE_TOP, RIGHT_EYE_BOTTOM, frameHeight)

            // Get iris positions for each eye (skip if blinking or not selected)
            var leftGaze: FloatArray? = null
            var leftIrisCenter: Pair<Float, Float>? = null
            var rightGaze: FloatArray? = null
            var rightIrisCenter: Pair<Float, Float>? = null

            // Only process left eye if selected and not blinking
            val useLeftEye = eyeSelection == EyeSelection.BOTH_EYES || eyeSelection == EyeSelection.LEFT_EYE_ONLY
            if (useLeftEye && !leftBlink) {
                val (gaze, center) = getIrisPosition(
                    landmarks,
                    LEFT_EYE_OUTER,
                    LEFT_EYE_INNER,
                    LEFT_IRIS_CENTER,
                    frameWidth,
                    frameHeight
                )
                leftGaze = gaze
                leftIrisCenter = center
            }

            // Only process right eye if selected and not blinking
            val useRightEye = eyeSelection == EyeSelection.BOTH_EYES || eyeSelection == EyeSelection.RIGHT_EYE_ONLY
            if (useRightEye && !rightBlink) {
                val (gaze, center) = getIrisPosition(
                    landmarks,
                    RIGHT_EYE_OUTER,
                    RIGHT_EYE_INNER,
                    RIGHT_IRIS_CENTER,
                    frameWidth,
                    frameHeight
                )
                rightGaze = gaze
                rightIrisCenter = center
            }

            // Combine gaze based on eye selection
            val (combinedGaze, confidence) = when (eyeSelection) {
                EyeSelection.LEFT_EYE_ONLY -> {
                    // Only use left eye
                    if (leftGaze != null) leftGaze to 1.0f else return null
                }
                EyeSelection.RIGHT_EYE_ONLY -> {
                    // Only use right eye
                    if (rightGaze != null) rightGaze to 1.0f else return null
                }
                EyeSelection.BOTH_EYES -> {
                    // Use both eyes - average if both available, fallback to single eye
                    when {
                        leftGaze != null && rightGaze != null -> {
                            val avgX = (leftGaze[0] + rightGaze[0]) / 2f
                            val avgY = (leftGaze[1] + rightGaze[1]) / 2f
                            floatArrayOf(avgX, avgY) to 1.0f
                        }
                        leftGaze != null -> leftGaze to 0.7f
                        rightGaze != null -> rightGaze to 0.7f
                        else -> return null
                    }
                }
            }

            // Apply head pose compensation
            val (compensatedX, compensatedY) = if (headPoseCompensationEnabled) {
                applyHeadPoseCompensation(combinedGaze[0], combinedGaze[1], headYaw, headPitch)
            } else {
                Pair(combinedGaze[0], combinedGaze[1])
            }

            GazeResult(
                gazeX = compensatedX,
                gazeY = compensatedY,
                leftIrisCenter = leftIrisCenter,
                rightIrisCenter = rightIrisCenter,
                confidence = confidence,
                leftBlink = leftBlink,
                rightBlink = rightBlink,
                headYaw = headYaw,
                headPitch = headPitch,
                headRoll = headRoll
            )
        } catch (e: Exception) {
            Timber.e(e, "Error estimating gaze")
            null
        }
    }

    /**
     * Estimate head pose (yaw, pitch, roll) from face landmarks.
     *
     * Uses key facial landmarks to approximate head orientation.
     * This is a simplified estimation; for more accuracy, use the
     * facial transformation matrix from MediaPipe when available.
     *
     * @return Triple of (yaw, pitch, roll) in degrees
     */
    private fun estimateHeadPose(
        landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>,
        frameWidth: Float,
        frameHeight: Float
    ): Triple<Float, Float, Float> {
        try {
            // Get key landmarks for head pose estimation
            val noseTip = landmarks[NOSE_TIP]
            val chin = landmarks[CHIN]
            val leftEye = landmarks[LEFT_EYE_CORNER]
            val rightEye = landmarks[RIGHT_EYE_CORNER]

            // Calculate yaw (horizontal rotation) from eye positions
            val eyeMidX = (leftEye.x() + rightEye.x()) / 2f
            val noseTipX = noseTip.x()
            // If nose is to the left of eye midpoint, head is turned left (negative yaw)
            // Scale to approximate degrees (-30 to +30 typical range)
            val yaw = (noseTipX - eyeMidX) * 100f

            // Calculate pitch (vertical rotation) from nose-chin relationship
            val noseY = noseTip.y()
            val chinY = chin.y()
            val eyeMidY = (leftEye.y() + rightEye.y()) / 2f
            // If nose is higher relative to chin, head is tilted up (positive pitch)
            val noseToEyeY = noseY - eyeMidY
            val noseToChinY = chinY - noseY
            // Ratio changes with head pitch
            val expectedRatio = 0.6f  // typical frontal ratio
            val actualRatio = if (noseToChinY > 0.01f) noseToEyeY / noseToChinY else expectedRatio
            val pitch = (actualRatio - expectedRatio) * 150f

            // Calculate roll (tilt) from eye angle
            val eyeDeltaY = rightEye.y() - leftEye.y()
            val eyeDeltaX = rightEye.x() - leftEye.x()
            val roll = if (eyeDeltaX > 0.01f) {
                kotlin.math.atan2(eyeDeltaY, eyeDeltaX) * (180f / Math.PI.toFloat())
            } else {
                0f
            }

            return Triple(
                yaw.coerceIn(-45f, 45f),
                pitch.coerceIn(-45f, 45f),
                roll.coerceIn(-45f, 45f)
            )
        } catch (e: Exception) {
            Timber.e(e, "Error estimating head pose")
            return Triple(0f, 0f, 0f)
        }
    }

    /**
     * Apply head pose compensation to raw gaze coordinates.
     *
     * When the head is turned, the iris appears to shift within the eye socket
     * even when looking at the same point. This compensation corrects for that.
     */
    private fun applyHeadPoseCompensation(
        gazeX: Float,
        gazeY: Float,
        headYaw: Float,
        headPitch: Float
    ): Pair<Float, Float> {
        // Convert head angles to compensation offsets
        // When head turns right (positive yaw), gaze appears to shift left
        // We need to add a correction in the opposite direction
        val yawCorrection = -headYaw / 45f * headYawCompensation
        val pitchCorrection = -headPitch / 45f * headPitchCompensation

        val compensatedX = (gazeX + yawCorrection).coerceIn(-1f, 1f)
        val compensatedY = (gazeY + pitchCorrection).coerceIn(-1f, 1f)

        return Pair(compensatedX, compensatedY)
    }

    /**
     * Calculate normalized iris position within the eye.
     *
     * @return Pair of (gaze vector [x, y], iris center [x, y]) or (null, null) if failed
     */
    private fun getIrisPosition(
        landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>,
        eyeOuterIdx: Int,
        eyeInnerIdx: Int,
        irisCenterIdx: Int,
        frameWidth: Float,
        frameHeight: Float
    ): Pair<FloatArray?, Pair<Float, Float>?> {
        return try {
            val outer = landmarks[eyeOuterIdx]
            val inner = landmarks[eyeInnerIdx]

            // Convert normalized coordinates to pixel coordinates
            val outerPx = floatArrayOf(outer.x() * frameWidth, outer.y() * frameHeight)
            val innerPx = floatArrayOf(inner.x() * frameWidth, inner.y() * frameHeight)

            // Calculate eye width
            val eyeWidth = kotlin.math.sqrt(
                (innerPx[0] - outerPx[0]) * (innerPx[0] - outerPx[0]) +
                (innerPx[1] - outerPx[1]) * (innerPx[1] - outerPx[1])
            )

            if (eyeWidth < 1f) {
                return Pair(null, null)
            }

            val eyeCenter = floatArrayOf(
                (outerPx[0] + innerPx[0]) / 2f,
                (outerPx[1] + innerPx[1]) / 2f
            )

            // Get iris center position
            val irisPx = if (irisCenterIdx < landmarks.size) {
                val iris = landmarks[irisCenterIdx]
                floatArrayOf(iris.x() * frameWidth, iris.y() * frameHeight)
            } else {
                // Fallback: use eye center if iris landmarks not available
                eyeCenter
            }

            // Calculate normalized gaze position (-1 to 1 range)
            // Apply sensitivity multipliers to reduce required eye movement
            var gazeX = ((irisPx[0] - eyeCenter[0]) / (eyeWidth / 2f)) * sensitivityX
            var gazeY = ((irisPx[1] - eyeCenter[1]) / (eyeWidth / 4f)) * sensitivityY

            // Apply offset correction (helps with camera angle / head position bias)
            gazeX += offsetX
            gazeY += offsetY

            // Clamp to valid range
            gazeX = gazeX.coerceIn(-1f, 1f)
            gazeY = gazeY.coerceIn(-1f, 1f)

            Pair(floatArrayOf(gazeX, gazeY), Pair(irisPx[0], irisPx[1]))
        } catch (e: Exception) {
            Timber.e(e, "Error getting iris position")
            Pair(null, null)
        }
    }

    /**
     * Detect if an eye is blinking based on eye aspect ratio.
     */
    private fun detectBlink(
        landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>,
        eyeTopIdx: Int,
        eyeBottomIdx: Int,
        frameHeight: Float
    ): Boolean {
        return try {
            val top = landmarks[eyeTopIdx]
            val bottom = landmarks[eyeBottomIdx]

            val eyeHeight = abs(bottom.y() - top.y())
            eyeHeight < BLINK_THRESHOLD
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Set sensitivity for gaze-to-cursor mapping.
     *
     * @param x Horizontal sensitivity (higher = less eye movement needed)
     * @param y Vertical sensitivity (higher = less eye movement needed)
     */
    fun setSensitivity(x: Float? = null, y: Float? = null) {
        x?.let { sensitivityX = it.coerceIn(0.5f, 5.0f) }
        y?.let { sensitivityY = it.coerceIn(0.5f, 5.0f) }
    }

    /**
     * Set offset for gaze correction.
     *
     * @param x Horizontal offset (-1 to 1, positive = shift right)
     * @param y Vertical offset (-1 to 1, positive = shift down)
     */
    fun setOffset(x: Float? = null, y: Float? = null) {
        x?.let { offsetX = it.coerceIn(-1.0f, 1.0f) }
        y?.let { offsetY = it.coerceIn(-1.0f, 1.0f) }
    }

    /**
     * Check if the tracker is properly initialized.
     */
    fun isReady(): Boolean = isInitialized

    /**
     * Release resources.
     */
    fun close() {
        try {
            faceLandmarker?.close()
        } catch (e: Exception) {
            Timber.e(e, "Error closing MediaPipe Iris GazeTracker")
        }
        isInitialized = false
    }
}

