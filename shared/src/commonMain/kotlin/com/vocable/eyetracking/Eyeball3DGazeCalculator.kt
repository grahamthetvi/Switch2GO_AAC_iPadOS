package com.vocable.eyetracking

import com.vocable.eyetracking.models.EyeSelection
import com.vocable.eyetracking.models.LandmarkPoint
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.sqrt

/**
 * 3D Eyeball gaze calculator based on MediaPipe face landmarks.
 *
 * Ported from Android MediaPipe3DEyeballTracker to shared KMP logic.
 */
class Eyeball3DGazeCalculator(
    var sensitivityX: Float = 2.0f,
    var sensitivityY: Float = 2.5f,
    var offsetX: Float = 0.0f,
    var offsetY: Float = 0.0f,
    var headPoseCompensationEnabled: Boolean = true
) {
    companion object {
        // Eyeball anatomical constants (relative to eye width)
        private const val EYEBALL_RADIUS_RATIO = 0.42f
        private const val CORNEA_OFFSET_RATIO = 0.38f
        private const val PUPIL_DEPTH_RATIO = 0.15f

        // Landmark indices
        const val LEFT_EYE_OUTER = 33
        const val LEFT_EYE_INNER = 133
        const val LEFT_EYE_TOP = 159
        const val LEFT_EYE_BOTTOM = 145
        const val LEFT_IRIS_CENTER = 468

        const val RIGHT_EYE_OUTER = 362
        const val RIGHT_EYE_INNER = 263
        const val RIGHT_EYE_TOP = 386
        const val RIGHT_EYE_BOTTOM = 374
        const val RIGHT_IRIS_CENTER = 473

        // Face landmarks for head pose
        const val NOSE_TIP = 1
        const val CHIN = 152
        const val FOREHEAD = 10
        const val LEFT_EAR = 234
        const val RIGHT_EAR = 454
    }

    data class Point3D(val x: Float, val y: Float, val z: Float) {
        operator fun plus(other: Point3D) = Point3D(x + other.x, y + other.y, z + other.z)
        operator fun minus(other: Point3D) = Point3D(x - other.x, y - other.y, z - other.z)
        operator fun times(scalar: Float) = Point3D(x * scalar, y * scalar, z * scalar)

        fun magnitude(): Float = sqrt(x * x + y * y + z * z)

        fun normalized(): Point3D {
            val mag = magnitude()
            return if (mag > 0) Point3D(x / mag, y / mag, z / mag) else this
        }
    }

    data class EyeballModel(
        val center: Point3D,
        val radius: Float,
        val pupilCenter: Point3D,
        val gazeDirection: Point3D,
        val gazeYaw: Float,
        val gazePitch: Float
    )

    fun estimateHeadPose(
        landmarks: List<LandmarkPoint>,
        frameWidth: Float,
        frameHeight: Float
    ): Triple<Float, Float, Float> {
        if (landmarks.size <= maxOf(NOSE_TIP, CHIN, FOREHEAD, LEFT_EAR, RIGHT_EAR, RIGHT_EYE_OUTER)) {
            return Triple(0f, 0f, 0f)
        }

        return try {
            val noseTip = landmarks[NOSE_TIP]
            val chin = landmarks[CHIN]
            val forehead = landmarks[FOREHEAD]
            val leftEar = landmarks[LEFT_EAR]
            val rightEar = landmarks[RIGHT_EAR]

            // Yaw from nose relative to ears
            val earMidX = (leftEar.x + rightEar.x) / 2f
            val yaw = (noseTip.x - earMidX) * 100f

            // Pitch from nose relative to forehead/chin
            val noseY = noseTip.y
            val foreheadY = forehead.y
            val chinY = chin.y
            val faceHeight = chinY - foreheadY
            val noseRelative = if (faceHeight != 0f) (noseY - foreheadY) / faceHeight else 0.45f
            val expectedNosePos = 0.45f
            val pitch = (noseRelative - expectedNosePos) * 150f

            // Roll from eye angle
            val eyeDeltaY = landmarks[RIGHT_EYE_OUTER].y - landmarks[LEFT_EYE_OUTER].y
            val eyeDeltaX = landmarks[RIGHT_EYE_OUTER].x - landmarks[LEFT_EYE_OUTER].x
            val roll = atan2(eyeDeltaY, eyeDeltaX) * (180f / PI.toFloat())

            Triple(
                yaw.coerceIn(-45f, 45f),
                pitch.coerceIn(-45f, 45f),
                roll.coerceIn(-45f, 45f)
            )
        } catch (e: Exception) {
            Triple(0f, 0f, 0f)
        }
    }

    fun buildEyeballModel(
        landmarks: List<LandmarkPoint>,
        eyeOuter: Int,
        eyeInner: Int,
        eyeTop: Int,
        eyeBottom: Int,
        irisCenter: Int,
        frameWidth: Float,
        frameHeight: Float
    ): EyeballModel? {
        if (landmarks.size <= maxOf(eyeOuter, eyeInner, eyeTop, eyeBottom)) return null

        return try {
            val outer = landmarks[eyeOuter]
            val inner = landmarks[eyeInner]
            val top = landmarks[eyeTop]
            val bottom = landmarks[eyeBottom]

            val outerPoint = Point3D(outer.x * frameWidth, outer.y * frameHeight, outer.z * frameWidth)
            val innerPoint = Point3D(inner.x * frameWidth, inner.y * frameHeight, inner.z * frameWidth)
            val topPoint = Point3D(top.x * frameWidth, top.y * frameHeight, top.z * frameWidth)
            val bottomPoint = Point3D(bottom.x * frameWidth, bottom.y * frameHeight, bottom.z * frameWidth)

            val eyeCenter = Point3D(
                (outerPoint.x + innerPoint.x) / 2f,
                (topPoint.y + bottomPoint.y) / 2f,
                (outerPoint.z + innerPoint.z) / 2f
            )

            val eyeWidth = (innerPoint - outerPoint).magnitude()
            if (eyeWidth <= 0f) return null

            val eyeballRadius = eyeWidth * EYEBALL_RADIUS_RATIO
            val corneaOffset = eyeWidth * CORNEA_OFFSET_RATIO

            val eyeballCenter = Point3D(
                eyeCenter.x,
                eyeCenter.y,
                eyeCenter.z + corneaOffset
            )

            val irisPoint = if (landmarks.size > irisCenter) {
                val iris = landmarks[irisCenter]
                Point3D(iris.x * frameWidth, iris.y * frameHeight, iris.z * frameWidth)
            } else {
                eyeCenter
            }

            val pupilDepth = eyeWidth * PUPIL_DEPTH_RATIO
            val pupilCenter = Point3D(irisPoint.x, irisPoint.y, irisPoint.z - pupilDepth)

            val gazeVector = (pupilCenter - eyeballCenter).normalized()
            val gazeYaw = atan2(gazeVector.x, -gazeVector.z) * (180f / PI.toFloat())
            val gazePitch = atan2(
                -gazeVector.y,
                sqrt(gazeVector.x * gazeVector.x + gazeVector.z * gazeVector.z)
            ) * (180f / PI.toFloat())

            EyeballModel(
                center = eyeballCenter,
                radius = eyeballRadius,
                pupilCenter = pupilCenter,
                gazeDirection = gazeVector,
                gazeYaw = gazeYaw,
                gazePitch = gazePitch
            )
        } catch (e: Exception) {
            null
        }
    }

    fun combineGaze(
        leftEye: EyeballModel?,
        rightEye: EyeballModel?,
        headYaw: Float,
        headPitch: Float,
        eyeSelection: EyeSelection
    ): Triple<Float, Float, Float>? {
        val (avgYaw, avgPitch, confidence) = when (eyeSelection) {
            EyeSelection.LEFT_EYE_ONLY -> {
                if (leftEye != null) Triple(leftEye.gazeYaw, leftEye.gazePitch, 1.0f) else return null
            }
            EyeSelection.RIGHT_EYE_ONLY -> {
                if (rightEye != null) Triple(rightEye.gazeYaw, rightEye.gazePitch, 1.0f) else return null
            }
            EyeSelection.BOTH_EYES -> {
                when {
                    leftEye != null && rightEye != null -> Triple(
                        (leftEye.gazeYaw + rightEye.gazeYaw) / 2f,
                        (leftEye.gazePitch + rightEye.gazePitch) / 2f,
                        1.0f
                    )
                    leftEye != null -> Triple(leftEye.gazeYaw, leftEye.gazePitch, 0.7f)
                    rightEye != null -> Triple(rightEye.gazeYaw, rightEye.gazePitch, 0.7f)
                    else -> return null
                }
            }
        }

        val compensatedYaw = if (headPoseCompensationEnabled) avgYaw - headYaw * 0.5f else avgYaw
        val compensatedPitch = if (headPoseCompensationEnabled) avgPitch - headPitch * 0.5f else avgPitch

        // Convert to normalized screen coordinates
        val maxGazeAngle = 30f
        var gazeX = (compensatedYaw / maxGazeAngle) * sensitivityX + offsetX
        var gazeY = (compensatedPitch / maxGazeAngle) * sensitivityY + offsetY

        // Safety bound only: values beyond ±1 are preserved so the caller
        // can detect the gaze going out of bounds (threshold 1.2).
        gazeX = gazeX.coerceIn(-IrisGazeCalculator.RAW_GAZE_LIMIT, IrisGazeCalculator.RAW_GAZE_LIMIT)
        gazeY = gazeY.coerceIn(-IrisGazeCalculator.RAW_GAZE_LIMIT, IrisGazeCalculator.RAW_GAZE_LIMIT)

        return Triple(gazeX, gazeY, confidence)
    }

    /**
     * Blink detection using the distance-invariant Eye Aspect Ratio
     * (eyelid gap / eye width in pixel space). See [IrisGazeCalculator.detectBlink].
     */
    fun detectBlink(
        landmarks: List<LandmarkPoint>,
        eyeTop: Int,
        eyeBottom: Int,
        eyeOuter: Int,
        eyeInner: Int,
        frameWidth: Float,
        frameHeight: Float
    ): Boolean {
        if (landmarks.size <= maxOf(eyeTop, eyeBottom, eyeOuter, eyeInner)) return false
        return try {
            val top = landmarks[eyeTop]
            val bottom = landmarks[eyeBottom]
            val outer = landmarks[eyeOuter]
            val inner = landmarks[eyeInner]

            val heightDx = (top.x - bottom.x) * frameWidth
            val heightDy = (top.y - bottom.y) * frameHeight
            val eyeHeight = sqrt(heightDx * heightDx + heightDy * heightDy)

            val widthDx = (outer.x - inner.x) * frameWidth
            val widthDy = (outer.y - inner.y) * frameHeight
            val eyeWidth = sqrt(widthDx * widthDx + widthDy * widthDy)

            if (eyeWidth < 1f) return false
            (eyeHeight / eyeWidth) < IrisGazeCalculator.BLINK_EAR_THRESHOLD
        } catch (e: Exception) {
            false
        }
    }
}
