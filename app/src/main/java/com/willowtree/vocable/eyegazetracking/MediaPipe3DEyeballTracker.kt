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
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * 3D Eye Gaze Tracker using MediaPipe's 478 face landmarks.
 *
 * This implementation uses a 3D eyeball model to compute gaze direction:
 * 1. Estimates 3D eye position from face landmarks
 * 2. Calculates pupil/iris center in 3D space
 * 3. Models the eyeball as a sphere with known radius
 * 4. Computes gaze as a ray from the eyeball center through the pupil
 *
 * Advantages over 2D tracking:
 * - More accurate at different head poses
 * - Accounts for eye rotation in 3D space
 * - Better handling of perspective distortion
 * - More robust to head distance changes
 *
 * The eyeball model uses standard anatomical parameters:
 * - Average eyeball radius: ~12mm
 * - Cornea radius: ~7.8mm
 * - Pupil-to-cornea distance: ~3.6mm
 */
class MediaPipe3DEyeballTracker(
    context: Context,
    useGpu: Boolean = false
) {
    companion object {
        private const val MODEL_PATH = "face_landmarker.task"

        // Eyeball anatomical constants (in mm, normalized to eye width)
        private const val EYEBALL_RADIUS_RATIO = 0.42f  // Eyeball radius relative to eye width
        private const val CORNEA_OFFSET_RATIO = 0.38f   // Distance from center to cornea surface
        private const val PUPIL_DEPTH_RATIO = 0.15f     // Depth of pupil from cornea surface

        // MediaPipe face mesh landmark indices
        // Left eye landmarks
        private const val LEFT_EYE_OUTER = 33
        private const val LEFT_EYE_INNER = 133
        private const val LEFT_EYE_TOP = 159
        private const val LEFT_EYE_BOTTOM = 145
        private const val LEFT_IRIS_CENTER = 468
        private val LEFT_IRIS_LANDMARKS = listOf(468, 469, 470, 471, 472)
        private val LEFT_EYE_CONTOUR = listOf(33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246)

        // Right eye landmarks
        private const val RIGHT_EYE_OUTER = 362
        private const val RIGHT_EYE_INNER = 263
        private const val RIGHT_EYE_TOP = 386
        private const val RIGHT_EYE_BOTTOM = 374
        private const val RIGHT_IRIS_CENTER = 473
        private val RIGHT_IRIS_LANDMARKS = listOf(473, 474, 475, 476, 477)
        private val RIGHT_EYE_CONTOUR = listOf(362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398)

        // Face landmarks for head pose estimation
        private const val NOSE_TIP = 1
        private const val CHIN = 152
        private const val FOREHEAD = 10
        private const val LEFT_EAR = 234
        private const val RIGHT_EAR = 454

        // Blink detection threshold
        private const val BLINK_THRESHOLD = 0.015f
    }

    /**
     * 3D point representation.
     */
    data class Point3D(
        val x: Float,
        val y: Float,
        val z: Float
    ) {
        operator fun plus(other: Point3D) = Point3D(x + other.x, y + other.y, z + other.z)
        operator fun minus(other: Point3D) = Point3D(x - other.x, y - other.y, z - other.z)
        operator fun times(scalar: Float) = Point3D(x * scalar, y * scalar, z * scalar)

        fun magnitude(): Float = sqrt(x * x + y * y + z * z)

        fun normalized(): Point3D {
            val mag = magnitude()
            return if (mag > 0) Point3D(x / mag, y / mag, z / mag) else this
        }

        fun dot(other: Point3D): Float = x * other.x + y * other.y + z * other.z

        fun cross(other: Point3D): Point3D = Point3D(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        )
    }

    /**
     * 3D Eyeball model for gaze estimation.
     */
    data class EyeballModel(
        val center: Point3D,           // Center of the eyeball
        val radius: Float,             // Eyeball radius
        val pupilCenter: Point3D,      // Center of the pupil
        val gazeDirection: Point3D,    // Normalized gaze direction vector
        val gazeYaw: Float,            // Horizontal gaze angle (degrees)
        val gazePitch: Float           // Vertical gaze angle (degrees)
    )

    /**
     * Result of 3D gaze estimation.
     */
    data class Gaze3DResult(
        val gazeX: Float,              // Normalized screen X (-1 to 1)
        val gazeY: Float,              // Normalized screen Y (-1 to 1)
        val leftEyeModel: EyeballModel?,
        val rightEyeModel: EyeballModel?,
        val headYaw: Float,            // Head rotation yaw (degrees)
        val headPitch: Float,          // Head rotation pitch (degrees)
        val headRoll: Float,           // Head rotation roll (degrees)
        val confidence: Float,
        val leftBlink: Boolean = false,
        val rightBlink: Boolean = false
    )

    private var faceLandmarker: FaceLandmarker? = null
    private var isInitialized = false
    private var isUsingGpu = false

    // Gaze sensitivity
    var sensitivityX: Float = 2.0f
    var sensitivityY: Float = 2.5f

    // Gaze offsets
    var offsetX: Float = 0.0f
    var offsetY: Float = 0.0f

    // Eye selection - which eye(s) to use for tracking
        var eyeSelection: EyeSelection = EyeSelection.BOTH_EYES

    init {
        try {
            val delegate = if (useGpu) Delegate.GPU else Delegate.CPU

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
                .setOutputFacialTransformationMatrixes(true)
                .build()

            faceLandmarker = FaceLandmarker.createFromOptions(context, options)
            isInitialized = true
            isUsingGpu = useGpu
            Timber.d("MediaPipe 3D Eyeball Tracker initialized (GPU: $useGpu)")
        } catch (e: Exception) {
            if (useGpu) {
                // Fallback to CPU
                Timber.w(e, "GPU init failed, falling back to CPU")
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
                } catch (fallbackEx: Exception) {
                    Timber.e(fallbackEx, "Failed to initialize 3D tracker")
                }
            } else {
                Timber.e(e, "Failed to initialize 3D tracker")
            }
        }
    }

    /**
     * Estimate 3D gaze from camera frame.
     */
    fun estimateGaze(bitmap: Bitmap): Gaze3DResult? {
        if (!isInitialized || faceLandmarker == null) {
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

            // Estimate head pose
            val (headYaw, headPitch, headRoll) = estimateHeadPose(landmarks, frameWidth, frameHeight)

            // Check for blinks
            val leftBlink = detectBlink(landmarks, LEFT_EYE_TOP, LEFT_EYE_BOTTOM)
            val rightBlink = detectBlink(landmarks, RIGHT_EYE_TOP, RIGHT_EYE_BOTTOM)

            // Build 3D eyeball models (only for selected eyes)
            var leftEyeModel: EyeballModel? = null
            var rightEyeModel: EyeballModel? = null

            // Only process left eye if selected and not blinking
            val useLeftEye = eyeSelection == EyeSelection.BOTH_EYES || eyeSelection == EyeSelection.LEFT_EYE_ONLY
            if (useLeftEye && !leftBlink) {
                leftEyeModel = buildEyeballModel(
                    landmarks,
                    LEFT_EYE_OUTER, LEFT_EYE_INNER, LEFT_EYE_TOP, LEFT_EYE_BOTTOM,
                    LEFT_IRIS_CENTER, LEFT_IRIS_LANDMARKS,
                    frameWidth, frameHeight
                )
            }

            // Only process right eye if selected and not blinking
            val useRightEye = eyeSelection == EyeSelection.BOTH_EYES || eyeSelection == EyeSelection.RIGHT_EYE_ONLY
            if (useRightEye && !rightBlink) {
                rightEyeModel = buildEyeballModel(
                    landmarks,
                    RIGHT_EYE_OUTER, RIGHT_EYE_INNER, RIGHT_EYE_TOP, RIGHT_EYE_BOTTOM,
                    RIGHT_IRIS_CENTER, RIGHT_IRIS_LANDMARKS,
                    frameWidth, frameHeight
                )
            }

            // Combine gaze based on eye selection
            val (gazeX, gazeY, confidence) = combineGaze(leftEyeModel, rightEyeModel, headYaw, headPitch)

            Gaze3DResult(
                gazeX = gazeX,
                gazeY = gazeY,
                leftEyeModel = leftEyeModel,
                rightEyeModel = rightEyeModel,
                headYaw = headYaw,
                headPitch = headPitch,
                headRoll = headRoll,
                confidence = confidence,
                leftBlink = leftBlink,
                rightBlink = rightBlink
            )
        } catch (e: Exception) {
            Timber.e(e, "Error in 3D gaze estimation")
            null
        }
    }

    /**
     * Build a 3D eyeball model from landmarks.
     */
    private fun buildEyeballModel(
        landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>,
        eyeOuter: Int, eyeInner: Int, eyeTop: Int, eyeBottom: Int,
        irisCenter: Int, irisLandmarks: List<Int>,
        frameWidth: Float, frameHeight: Float
    ): EyeballModel? {
        return try {
            // Get eye corner positions
            val outer = landmarks[eyeOuter]
            val inner = landmarks[eyeInner]
            val top = landmarks[eyeTop]
            val bottom = landmarks[eyeBottom]

            // Convert to 3D points (using z from landmarks)
            val outerPoint = Point3D(outer.x() * frameWidth, outer.y() * frameHeight, outer.z() * frameWidth)
            val innerPoint = Point3D(inner.x() * frameWidth, inner.y() * frameHeight, inner.z() * frameWidth)
            val topPoint = Point3D(top.x() * frameWidth, top.y() * frameHeight, top.z() * frameWidth)
            val bottomPoint = Point3D(bottom.x() * frameWidth, bottom.y() * frameHeight, bottom.z() * frameWidth)

            // Calculate eye center and dimensions
            val eyeCenter = Point3D(
                (outerPoint.x + innerPoint.x) / 2f,
                (topPoint.y + bottomPoint.y) / 2f,
                (outerPoint.z + innerPoint.z) / 2f
            )

            val eyeWidth = (innerPoint - outerPoint).magnitude()
            val eyeHeight = abs(bottomPoint.y - topPoint.y)

            // Calculate eyeball parameters
            val eyeballRadius = eyeWidth * EYEBALL_RADIUS_RATIO
            val corneaOffset = eyeWidth * CORNEA_OFFSET_RATIO

            // Estimate eyeball center (behind the visible eye surface)
            val eyeballCenter = Point3D(
                eyeCenter.x,
                eyeCenter.y,
                eyeCenter.z + corneaOffset  // Eyeball center is behind the surface
            )

            // Get iris/pupil position
            val irisPt = if (irisCenter < landmarks.size) {
                val iris = landmarks[irisCenter]
                Point3D(iris.x() * frameWidth, iris.y() * frameHeight, iris.z() * frameWidth)
            } else {
                eyeCenter  // Fallback to eye center
            }

            // Calculate pupil center with depth estimate
            val pupilDepth = eyeWidth * PUPIL_DEPTH_RATIO
            val pupilCenter = Point3D(irisPt.x, irisPt.y, irisPt.z - pupilDepth)

            // Calculate gaze direction as ray from eyeball center through pupil
            val gazeVector = (pupilCenter - eyeballCenter).normalized()

            // Convert gaze vector to yaw/pitch angles
            val gazeYaw = atan2(gazeVector.x, -gazeVector.z) * (180f / Math.PI.toFloat())
            val gazePitch = atan2(-gazeVector.y, sqrt(gazeVector.x * gazeVector.x + gazeVector.z * gazeVector.z)) *
                    (180f / Math.PI.toFloat())

            EyeballModel(
                center = eyeballCenter,
                radius = eyeballRadius,
                pupilCenter = pupilCenter,
                gazeDirection = gazeVector,
                gazeYaw = gazeYaw,
                gazePitch = gazePitch
            )
        } catch (e: Exception) {
            Timber.e(e, "Error building eyeball model")
            null
        }
    }

    /**
     * Combine gaze from both eyes and convert to screen coordinates.
     */
    private fun combineGaze(
        leftEye: EyeballModel?,
        rightEye: EyeballModel?,
        headYaw: Float,
        headPitch: Float
    ): Triple<Float, Float, Float> {
        // Get gaze angles based on eye selection
        val (avgYaw, avgPitch, confidence) = when (eyeSelection) {
            EyeSelection.LEFT_EYE_ONLY -> {
                // Only use left eye
                if (leftEye != null) {
                    Triple(leftEye.gazeYaw, leftEye.gazePitch, 1.0f)
                } else {
                    return Triple(0f, 0f, 0f)
                }
            }
            EyeSelection.RIGHT_EYE_ONLY -> {
                // Only use right eye
                if (rightEye != null) {
                    Triple(rightEye.gazeYaw, rightEye.gazePitch, 1.0f)
                } else {
                    return Triple(0f, 0f, 0f)
                }
            }
            EyeSelection.BOTH_EYES -> {
                // Use both eyes - average if both available, fallback to single eye
                when {
                    leftEye != null && rightEye != null -> {
                        Triple(
                            (leftEye.gazeYaw + rightEye.gazeYaw) / 2f,
                            (leftEye.gazePitch + rightEye.gazePitch) / 2f,
                            1.0f
                        )
                    }
                    leftEye != null -> Triple(leftEye.gazeYaw, leftEye.gazePitch, 0.7f)
                    rightEye != null -> Triple(rightEye.gazeYaw, rightEye.gazePitch, 0.7f)
                    else -> return Triple(0f, 0f, 0f)
                }
            }
        }

        // Compensate for head pose
        // When head is turned, the gaze relative to the world changes
        val compensatedYaw = avgYaw - headYaw * 0.5f
        val compensatedPitch = avgPitch - headPitch * 0.5f

        // Convert to normalized screen coordinates
        // Typical eye rotation range is about ±30 degrees
        val maxGazeAngle = 30f

        var gazeX = (compensatedYaw / maxGazeAngle) * sensitivityX + offsetX
        var gazeY = (compensatedPitch / maxGazeAngle) * sensitivityY + offsetY

        // Clamp to valid range
        gazeX = gazeX.coerceIn(-1f, 1f)
        gazeY = gazeY.coerceIn(-1f, 1f)

        return Triple(gazeX, gazeY, confidence)
    }

    /**
     * Estimate head pose from face landmarks.
     */
    private fun estimateHeadPose(
        landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>,
        frameWidth: Float,
        frameHeight: Float
    ): Triple<Float, Float, Float> {
        try {
            val noseTip = landmarks[NOSE_TIP]
            val chin = landmarks[CHIN]
            val forehead = landmarks[FOREHEAD]
            val leftEar = landmarks[LEFT_EAR]
            val rightEar = landmarks[RIGHT_EAR]

            // Yaw: horizontal rotation
            val earMidX = (leftEar.x() + rightEar.x()) / 2f
            val yaw = (noseTip.x() - earMidX) * 100f

            // Pitch: vertical rotation
            val noseY = noseTip.y()
            val foreheadY = forehead.y()
            val chinY = chin.y()
            val faceHeight = chinY - foreheadY
            val noseRelative = (noseY - foreheadY) / faceHeight
            val expectedNosePos = 0.45f  // Expected nose position in frontal view
            val pitch = (noseRelative - expectedNosePos) * 150f

            // Roll: head tilt
            val eyeDeltaY = landmarks[RIGHT_EYE_OUTER].y() - landmarks[LEFT_EYE_OUTER].y()
            val eyeDeltaX = landmarks[RIGHT_EYE_OUTER].x() - landmarks[LEFT_EYE_OUTER].x()
            val roll = atan2(eyeDeltaY, eyeDeltaX) * (180f / Math.PI.toFloat())

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
     * Detect if an eye is blinking.
     */
    private fun detectBlink(
        landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>,
        eyeTop: Int,
        eyeBottom: Int
    ): Boolean {
        return try {
            val top = landmarks[eyeTop]
            val bottom = landmarks[eyeBottom]
            val eyeHeight = abs(bottom.y() - top.y())
            eyeHeight < BLINK_THRESHOLD
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Set sensitivity for gaze mapping.
     */
    fun setSensitivity(x: Float? = null, y: Float? = null) {
        x?.let { sensitivityX = it.coerceIn(0.5f, 5.0f) }
        y?.let { sensitivityY = it.coerceIn(0.5f, 5.0f) }
    }

    /**
     * Set gaze offset.
     */
    fun setOffset(x: Float? = null, y: Float? = null) {
        x?.let { offsetX = it.coerceIn(-1f, 1f) }
        y?.let { offsetY = it.coerceIn(-1f, 1f) }
    }

    /**
     * Check if tracker is ready.
     */
    fun isReady(): Boolean = isInitialized

    /**
     * Check if using GPU.
     */
    fun isUsingGpu(): Boolean = isUsingGpu

    /**
     * Release resources.
     */
    fun close() {
        try {
            faceLandmarker?.close()
        } catch (e: Exception) {
            Timber.e(e, "Error closing 3D tracker")
        }
        isInitialized = false
    }
}

