package com.switch2go.aac.platform

import com.switch2go.aac.eyetracking.models.LandmarkPoint
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.IO
import kotlinx.coroutines.withContext
import platform.CoreMedia.CMSampleBufferRef
import platform.CoreVideo.CVPixelBufferRef
import platform.Foundation.NSBundle
import cocoapods.MediaPipeTasksVision.MPPFaceLandmarker
import cocoapods.MediaPipeTasksVision.MPPFaceLandmarkerOptions
import cocoapods.MediaPipeTasksVision.MPPBaseOptions
import cocoapods.MediaPipeTasksVision.MPPImage
import cocoapods.MediaPipeTasksVision.MPPRunningMode
import cocoapods.MediaPipeTasksVision.MPPDelegate

/**
 * iOS actual implementation for FaceLandmarkDetector using MediaPipe iOS SDK.
 *
 * This class wraps the MediaPipe FaceLandmarker for iOS, providing the same
 * 478-point face mesh with iris landmarks (468-477) as the Android implementation.
 */
@OptIn(ExperimentalForeignApi::class)
actual class PlatformFaceLandmarkDetector : FaceLandmarkDetector {
    private var faceLandmarker: MPPFaceLandmarker? = null
    private var isInitialized = false
    private var usingGpu = false
    private var currentPixelBuffer: CVPixelBufferRef? = null
    private var frameWidth: Int = 0
    private var frameHeight: Int = 0

    private val logger = createLogger("IOSFaceLandmarkDetector")

    companion object {
        private const val MODEL_NAME = "face_landmarker"
        private const val MODEL_EXTENSION = "task"
    }

    /**
     * Set the current camera frame pixel buffer for processing.
     * This should be called from the camera callback before detectLandmarks().
     *
     * @param pixelBuffer The CVPixelBuffer from the camera
     * @param width Frame width in pixels
     * @param height Frame height in pixels
     */
    fun setFramePixelBuffer(pixelBuffer: CVPixelBufferRef?, width: Int, height: Int) {
        currentPixelBuffer = pixelBuffer
        frameWidth = width
        frameHeight = height
    }

    override fun initialize(useGpu: Boolean): Boolean {
        if (isInitialized) {
            logger.warn("FaceLandmarkDetector already initialized")
            return true
        }

        return try {
            // Get the model path from the app bundle
            val modelPath = NSBundle.mainBundle.pathForResource(MODEL_NAME, MODEL_EXTENSION)
            if (modelPath == null) {
                logger.error("Model file not found: $MODEL_NAME.$MODEL_EXTENSION")
                return false
            }

            // Configure base options
            val baseOptions = MPPBaseOptions()
            baseOptions.modelAssetPath = modelPath

            // Set delegate (GPU or CPU)
            baseOptions.delegate = if (useGpu) {
                logger.debug("Attempting to use GPU delegate for MediaPipe")
                MPPDelegate.MPPDelegateGPU
            } else {
                MPPDelegate.MPPDelegateCPU
            }

            // Configure face landmarker options
            val options = MPPFaceLandmarkerOptions()
            options.baseOptions = baseOptions
            options.runningMode = MPPRunningMode.MPPRunningModeImage
            options.numFaces = 1
            options.minFaceDetectionConfidence = 0.5f
            options.minFacePresenceConfidence = 0.5f
            options.minTrackingConfidence = 0.5f
            options.outputFaceBlendshapes = false
            options.outputFacialTransformationMatrixes = true

            // Create the face landmarker
            faceLandmarker = MPPFaceLandmarker(options = options, error = null)

            if (faceLandmarker != null) {
                isInitialized = true
                usingGpu = useGpu
                logger.debug("MediaPipe FaceLandmarkDetector initialized successfully (GPU: $useGpu)")
                true
            } else {
                // Try CPU fallback if GPU failed
                if (useGpu) {
                    logger.warn("GPU initialization failed, falling back to CPU")
                    baseOptions.delegate = MPPDelegate.MPPDelegateCPU
                    options.baseOptions = baseOptions
                    faceLandmarker = MPPFaceLandmarker(options = options, error = null)

                    if (faceLandmarker != null) {
                        isInitialized = true
                        usingGpu = false
                        logger.debug("MediaPipe FaceLandmarkDetector initialized with CPU fallback")
                        true
                    } else {
                        logger.error("Failed to initialize MediaPipe FaceLandmarkDetector")
                        false
                    }
                } else {
                    logger.error("Failed to initialize MediaPipe FaceLandmarkDetector")
                    false
                }
            }
        } catch (e: Exception) {
            logger.error("Error initializing FaceLandmarkDetector", e)
            false
        }
    }

    override suspend fun detectLandmarks(): FaceLandmarkResult? = withContext(Dispatchers.IO) {
        if (!isInitialized || faceLandmarker == null) {
            logger.warn("FaceLandmarkDetector not initialized")
            return@withContext null
        }

        val pixelBuffer = currentPixelBuffer
        if (pixelBuffer == null) {
            logger.warn("No pixel buffer set. Call setFramePixelBuffer() before detectLandmarks()")
            return@withContext null
        }

        try {
            // Create MPPImage from pixel buffer
            val mppImage = MPPImage(pixelBuffer = pixelBuffer, error = null)
            if (mppImage == null) {
                logger.error("Failed to create MPPImage from pixel buffer")
                return@withContext null
            }

            // Detect landmarks
            val result = faceLandmarker?.detectImage(mppImage, error = null)

            if (result == null || result.faceLandmarks.isEmpty()) {
                return@withContext null
            }

            // Get landmarks for the first face
            val landmarks = result.faceLandmarks.firstOrNull() as? List<*>
            if (landmarks == null || landmarks.isEmpty()) {
                return@withContext null
            }

            // Convert MediaPipe NormalizedLandmark to our LandmarkPoint
            val landmarkPoints = landmarks.mapNotNull { landmark ->
                // MediaPipe iOS returns MPPNormalizedLandmark objects
                // Access x, y, z properties via reflection or direct casting
                try {
                    val mpLandmark = landmark as? cocoapods.MediaPipeTasksVision.MPPNormalizedLandmark
                    if (mpLandmark != null) {
                        LandmarkPoint(
                            x = mpLandmark.x,
                            y = mpLandmark.y,
                            z = mpLandmark.z
                        )
                    } else {
                        null
                    }
                } catch (e: Exception) {
                    logger.error("Error converting landmark", e)
                    null
                }
            }

            if (landmarkPoints.isEmpty()) {
                return@withContext null
            }

            FaceLandmarkResult(
                landmarks = landmarkPoints,
                frameWidth = frameWidth,
                frameHeight = frameHeight,
                timestamp = platform.Foundation.NSDate().timeIntervalSince1970.toLong() * 1000
            )
        } catch (e: Exception) {
            logger.error("Error detecting landmarks", e)
            null
        }
    }

    override fun isReady(): Boolean = isInitialized

    override fun isUsingGpu(): Boolean = usingGpu

    override fun close() {
        try {
            faceLandmarker = null
        } catch (e: Exception) {
            logger.error("Error closing FaceLandmarkDetector", e)
        }
        isInitialized = false
        currentPixelBuffer = null
    }
}

/**
 * Helper function to create and initialize a FaceLandmarkDetector for iOS.
 */
fun createIOSFaceLandmarkDetector(useGpu: Boolean = false): PlatformFaceLandmarkDetector {
    return PlatformFaceLandmarkDetector().apply {
        initialize(useGpu)
    }
}
