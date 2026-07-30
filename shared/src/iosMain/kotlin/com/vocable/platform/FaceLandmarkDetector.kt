package com.vocable.platform

import com.vocable.eyetracking.models.LandmarkPoint
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.concurrent.AtomicLong
import kotlin.concurrent.AtomicReference
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

    /**
     * In-flight detection callback. Written by the caller's coroutine and
     * consumed (atomically exchanged) by the MediaPipe detection queue, so it
     * must be an atomic reference — a plain var could double-resume the
     * continuation or drop a result under concurrent access.
     *
     * Pair is (requestGeneration, callback). Late MediaPipe results for a
     * superseded request are ignored via the generation check.
     */
    private val resultCallback =
        AtomicReference<Pair<Long, (FaceLandmarkResult?) -> Unit>?>(null)

    /** Monotonic request id so late callbacks cannot resume a newer wait. */
    private val requestGeneration = AtomicLong(0)

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

        // Timeout prevents permanent hang if Swift bridge never calls back
        // (e.g., if MediaPipe fails silently or the detection queue stalls).
        // 2 seconds is generous — normal detection takes ~20-50ms.
        val generation = requestGeneration.addAndGet(1)
        return withTimeoutOrNull(2000L) {
            suspendCancellableCoroutine { continuation ->
                val callback: (FaceLandmarkResult?) -> Unit = { result ->
                    if (continuation.isActive) {
                        continuation.resume(result)
                    }
                }
                resultCallback.value = generation to callback

                continuation.invokeOnCancellation {
                    // Only clear if this request is still the active one
                    val current = resultCallback.value
                    if (current != null && current.first == generation) {
                        resultCallback.compareAndSet(current, null)
                    }
                }

                // Trigger detection on Swift side
                bridge.requestDetection()
            }
        }.also {
            // Timeout / completion: drop callback if still ours so a late
            // MediaPipe result cannot resume a finished continuation.
            val current = resultCallback.value
            if (current != null && current.first == generation) {
                resultCallback.compareAndSet(current, null)
            }
        }
    }

    /**
     * Called from Swift when landmarks are detected.
     * This bridges the async result back to Kotlin coroutines.
     */
    fun onLandmarksDetected(result: FaceLandmarkResult?) {
        val holder = resultCallback.getAndSet(null) ?: return
        holder.second.invoke(result)
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
        resultCallback.value = null
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
