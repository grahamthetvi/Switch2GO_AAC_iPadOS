package com.vocable.platform

import com.vocable.eyetracking.models.LandmarkPoint
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * iOS implementation of FaceLandmarkDetector.
 *
 * This implementation uses a bridge pattern where the actual MediaPipe
 * detection is performed in Swift code. The Swift side sets a delegate
 * that provides the detection results back to Kotlin.
 *
 * Usage from Swift:
 * ```swift
 * let detector = PlatformFaceLandmarkDetector()
 * detector.setSwiftBridge(mySwiftBridge)
 * detector.initialize(useGpu: true)
 * ```
 */
actual class PlatformFaceLandmarkDetector : FaceLandmarkDetector {

    private var isInitialized = false
    private var usingGpu = false
    private var swiftBridge: IOSFaceLandmarkBridge? = null

    // Pending result for async detection
    private var pendingResult: FaceLandmarkResult? = null
    private var resultCallback: ((FaceLandmarkResult?) -> Unit)? = null

    /**
     * Set the Swift bridge that handles actual MediaPipe detection.
     * Must be called from Swift before using the detector.
     */
    fun setSwiftBridge(bridge: IOSFaceLandmarkBridge) {
        this.swiftBridge = bridge
    }

    override fun initialize(useGpu: Boolean): Boolean {
        val bridge = swiftBridge ?: run {
            println("ERROR: Swift bridge not set. Call setSwiftBridge() first.")
            return false
        }

        usingGpu = useGpu
        isInitialized = bridge.initialize(useGpu)
        return isInitialized
    }

    override suspend fun detectLandmarks(): FaceLandmarkResult? {
        val bridge = swiftBridge ?: return null
        if (!isInitialized) return null

        return suspendCancellableCoroutine { continuation ->
            // Request detection from Swift side
            // Swift will call onLandmarksDetected when ready
            resultCallback = { result ->
                if (continuation.isActive) {
                    continuation.resume(result)
                }
                resultCallback = null
            }

            // Trigger detection on Swift side
            bridge.requestDetection()
        }
    }

    /**
     * Called from Swift when landmarks are detected.
     * This bridges the async result back to Kotlin coroutines.
     */
    fun onLandmarksDetected(result: FaceLandmarkResult?) {
        resultCallback?.invoke(result)
    }

    /**
     * Called from Swift to provide landmark data.
     * Convenience method for Swift to pass raw data without creating Kotlin objects.
     */
    fun onLandmarksDetectedRaw(
        landmarks: List<FloatArray>,  // Each array is [x, y, z]
        frameWidth: Int,
        frameHeight: Int,
        timestamp: Long
    ) {
        val landmarkPoints = landmarks.map { arr ->
            LandmarkPoint(
                x = arr.getOrElse(0) { 0f },
                y = arr.getOrElse(1) { 0f },
                z = arr.getOrElse(2) { 0f }
            )
        }

        val result = FaceLandmarkResult(
            landmarks = landmarkPoints,
            frameWidth = frameWidth,
            frameHeight = frameHeight,
            timestamp = timestamp
        )

        onLandmarksDetected(result)
    }

    /**
     * Called from Swift when no face is detected.
     */
    fun onNoFaceDetected() {
        onLandmarksDetected(null)
    }

    override fun isReady(): Boolean = isInitialized && swiftBridge != null

    override fun isUsingGpu(): Boolean = usingGpu

    override fun close() {
        swiftBridge?.close()
        isInitialized = false
        resultCallback = null
    }
}

/**
 * Interface that Swift code must implement to provide MediaPipe functionality.
 *
 * Swift implementation example:
 * ```swift
 * class SwiftFaceLandmarkBridge: IOSFaceLandmarkBridge {
 *     private var faceLandmarker: FaceLandmarker?
 *     private weak var detector: PlatformFaceLandmarkDetector?
 *
 *     func setDetector(_ detector: PlatformFaceLandmarkDetector) {
 *         self.detector = detector
 *     }
 *
 *     func initialize(useGpu: Bool) -> Bool {
 *         // Initialize MediaPipe FaceLandmarker
 *         return true
 *     }
 *
 *     func requestDetection() {
 *         // Process current frame and call detector.onLandmarksDetected()
 *     }
 *
 *     func close() {
 *         faceLandmarker = nil
 *     }
 * }
 * ```
 */
interface IOSFaceLandmarkBridge {
    /**
     * Initialize the MediaPipe FaceLandmarker.
     * @param useGpu Whether to use GPU acceleration
     * @return true if successful
     */
    fun initialize(useGpu: Boolean): Boolean

    /**
     * Request detection on the current camera frame.
     * When detection is complete, call PlatformFaceLandmarkDetector.onLandmarksDetected()
     */
    fun requestDetection()

    /**
     * Release resources.
     */
    fun close()
}
