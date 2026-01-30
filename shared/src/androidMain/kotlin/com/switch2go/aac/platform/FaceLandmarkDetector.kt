package com.switch2go.aac.platform

import android.content.Context
import android.graphics.Bitmap
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.switch2go.aac.eyetracking.models.LandmarkPoint
import timber.log.Timber
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Android actual implementation for FaceLandmarkDetector using MediaPipe.
 */
actual class PlatformFaceLandmarkDetector : FaceLandmarkDetector {
    private var faceLandmarker: FaceLandmarker? = null
    private var isInitialized = false
    private var isUsingGpu = false
    private var currentBitmap: Bitmap? = null
    private var context: Context? = null

    companion object {
        private const val MODEL_PATH = "face_landmarker.task"
    }

    /**
     * Set the Android context (required for MediaPipe initialization).
     */
    fun setContext(context: Context) {
        this.context = context
    }

    /**
     * Set the current camera frame bitmap for processing.
     * This should be called from the camera callback before detectLandmarks().
     */
    fun setFrameBitmap(bitmap: Bitmap) {
        currentBitmap = bitmap
    }

    override fun initialize(useGpu: Boolean): Boolean {
        val ctx = context ?: run {
            Timber.e("Context not set. Call setContext() before initialize()")
            return false
        }

        if (isInitialized) {
            Timber.w("FaceLandmarkDetector already initialized")
            return true
        }

        return try {
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
                .setOutputFacialTransformationMatrixes(true)
                .build()

            faceLandmarker = FaceLandmarker.createFromOptions(ctx, options)
            isInitialized = true
            isUsingGpu = useGpu
            Timber.d("MediaPipe FaceLandmarkDetector initialized successfully (GPU: $useGpu)")
            true
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

                    faceLandmarker = FaceLandmarker.createFromOptions(ctx, options)
                    isInitialized = true
                    isUsingGpu = false
                    Timber.d("MediaPipe FaceLandmarkDetector initialized with CPU fallback")
                    true
                } catch (fallbackEx: Exception) {
                    Timber.e(fallbackEx, "Failed to initialize MediaPipe FaceLandmarkDetector")
                    false
                }
            } else {
                Timber.e(e, "Failed to initialize MediaPipe FaceLandmarkDetector")
                false
            }
        }
    }

    override suspend fun detectLandmarks(): FaceLandmarkResult? = withContext(Dispatchers.Default) {
        if (!isInitialized || faceLandmarker == null) {
            Timber.w("FaceLandmarkDetector not initialized")
            return@withContext null
        }

        val bitmap = currentBitmap ?: run {
            Timber.w("No bitmap set. Call setFrameBitmap() before detectLandmarks()")
            return@withContext null
        }

        try {
            val mpImage = BitmapImageBuilder(bitmap).build()
            val result = faceLandmarker?.detect(mpImage)

            if (result == null || result.faceLandmarks().isEmpty()) {
                return@withContext null
            }

            val landmarks = result.faceLandmarks()[0]

            // Convert MediaPipe NormalizedLandmark to our LandmarkPoint
            val landmarkPoints = landmarks.map { landmark ->
                LandmarkPoint(
                    x = landmark.x(),
                    y = landmark.y(),
                    z = landmark.z()
                )
            }

            FaceLandmarkResult(
                landmarks = landmarkPoints,
                frameWidth = bitmap.width,
                frameHeight = bitmap.height,
                timestamp = System.currentTimeMillis()
            )
        } catch (e: Exception) {
            Timber.e(e, "Error detecting landmarks")
            null
        }
    }

    override fun isReady(): Boolean = isInitialized

    override fun isUsingGpu(): Boolean = isUsingGpu

    override fun close() {
        try {
            faceLandmarker?.close()
            faceLandmarker = null
        } catch (e: Exception) {
            Timber.e(e, "Error closing FaceLandmarkDetector")
        }
        isInitialized = false
        currentBitmap = null
    }
}

/**
 * Helper function to create and initialize a FaceLandmarkDetector for Android.
 */
fun createFaceLandmarkDetector(context: Context, useGpu: Boolean = false): PlatformFaceLandmarkDetector {
    return PlatformFaceLandmarkDetector().apply {
        setContext(context)
        initialize(useGpu)
    }
}
