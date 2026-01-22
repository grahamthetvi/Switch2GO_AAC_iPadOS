package com.willowtree.vocable.eyegazetracking

import android.content.Context
import android.graphics.Bitmap
import com.vocable.eyetracking.GazeTracker
import com.vocable.eyetracking.models.EyeSelection
import com.vocable.eyetracking.models.GazeResult
import com.vocable.eyetracking.models.SmoothingMode
import com.vocable.platform.createFaceLandmarkDetector
import com.vocable.platform.createLogger
import com.vocable.platform.createStorage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Adapter class that bridges the existing Android ViewModel with the new shared KMP GazeTracker.
 *
 * This allows gradual migration:
 * - Existing code continues to work with MediaPipeIrisGazeTracker
 * - New code can use SharedGazeTrackerAdapter for KMP benefits
 * - Eventually, ViewModel can be refactored to use this exclusively
 *
 * Usage:
 * ```
 * val adapter = SharedGazeTrackerAdapter(context, screenWidth, screenHeight)
 * adapter.initialize(useGpu = true)
 *
 * // In camera callback:
 * val gazeResult = adapter.processFrame(bitmap)
 * val (screenX, screenY) = adapter.gazeToScreen(gazeResult)
 * ```
 */
class SharedGazeTrackerAdapter(
    private val context: Context,
    private val screenWidth: Int,
    private val screenHeight: Int
) {
    private val logger = createLogger("SharedGazeTracker")
    private val storage = createStorage(context)
    private val faceLandmarkDetector = createFaceLandmarkDetector(context)

    private val gazeTracker = GazeTracker(
        faceLandmarkDetector = faceLandmarkDetector,
        screenWidth = screenWidth,
        screenHeight = screenHeight,
        storage = storage,
        logger = logger
    )

    /**
     * Initialize the gaze tracker with MediaPipe.
     */
    fun initialize(useGpu: Boolean = false): Boolean {
        return faceLandmarkDetector.initialize(useGpu)
    }

    /**
     * Process a camera frame and get gaze result.
     *
     * @param bitmap Camera frame (from CameraX ImageProxy)
     * @return GazeResult with gaze coordinates and metadata, or null if no face detected
     */
    suspend fun processFrame(bitmap: Bitmap): GazeResult? = withContext(Dispatchers.Default) {
        faceLandmarkDetector.setFrameBitmap(bitmap)
        gazeTracker.processFrame()
    }

    /**
     * Convert gaze result to screen coordinates using calibration.
     */
    fun gazeToScreen(gazeResult: GazeResult?): Pair<Int, Int>? {
        return gazeResult?.let { gazeTracker.gazeToScreen(it) }
    }

    /**
     * Configure smoothing mode.
     */
    fun setSmoothingMode(mode: SmoothingMode) {
        gazeTracker.smoothingMode = mode
    }

    /**
     * Configure which eye(s) to use for tracking.
     */
    fun setEyeSelection(selection: EyeSelection) {
        gazeTracker.eyeSelection = selection
    }

    /**
     * Set gaze sensitivity (how much eye movement translates to cursor movement).
     */
    fun setSensitivity(x: Float? = null, y: Float? = null) {
        gazeTracker.getGazeCalculator().setSensitivity(x, y)
    }

    /**
     * Set gaze offset (for correcting camera angle / head position bias).
     */
    fun setOffset(x: Float? = null, y: Float? = null) {
        gazeTracker.getGazeCalculator().setOffset(x, y)
    }

    /**
     * Enable/disable head pose compensation.
     */
    fun setHeadPoseCompensation(enabled: Boolean) {
        gazeTracker.getGazeCalculator().headPoseCompensationEnabled = enabled
    }

    /**
     * Access calibration for calibration operations.
     */
    fun getCalibration() = gazeTracker.getCalibration()

    /**
     * Reset all filters and state.
     */
    fun reset() {
        gazeTracker.reset()
    }

    /**
     * Save calibration to SharedPreferences.
     */
    fun saveCalibration(): Boolean {
        return gazeTracker.saveCalibration()
    }

    /**
     * Load calibration from SharedPreferences.
     */
    fun loadCalibration(): Boolean {
        return gazeTracker.loadCalibration()
    }

    /**
     * Check if the tracker is ready.
     */
    fun isReady(): Boolean = faceLandmarkDetector.isReady()

    /**
     * Check if GPU is being used.
     */
    fun isUsingGpu(): Boolean = faceLandmarkDetector.isUsingGpu()

    /**
     * Release resources.
     */
    fun close() {
        faceLandmarkDetector.close()
    }
}
