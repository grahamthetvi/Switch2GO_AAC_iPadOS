package com.willowtree.vocable.eyegazetracking

import android.os.Bundle
import android.util.Size
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import timber.log.Timber
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Fragment that captures camera frames and processes them with MediaPipe
 * FaceLandmarker for eye gaze tracking using iris landmarks.
 *
 * This implementation uses:
 * - MediaPipe FaceLandmarker with iris landmarks (468-477)
 * - Kalman Filter for smooth gaze tracking
 * - 9-point calibration for accurate screen mapping
 *
 * Based on: "MediaPipe Iris and Kalman Filter for Robust Eye Gaze Tracking"
 */
class EyeGazeTrackFragment : Fragment() {

    private val viewModel: EyeGazeTrackingViewModel by activityViewModels()

    private var irisGazeTracker: MediaPipeIrisGazeTracker? = null
    private var cameraExecutor: ExecutorService? = null
    private var isProcessing = false
    private var frameCount = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        retainInstance = false
        cameraExecutor = Executors.newSingleThreadExecutor()
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        // This fragment doesn't need a visible UI - it just processes camera frames
        return View(requireContext()).apply {
            visibility = View.GONE
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        viewModel.eyeGazeEnabledLd.observe(viewLifecycleOwner) { enabled ->
            if (enabled) {
                setupIrisGazeTracker()
                startCamera()
            } else {
                stopCamera()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        viewModel.onResume()
    }

    /**
     * Setup MediaPipe Iris Gaze Tracker using FaceLandmarker with iris landmarks.
     */
    private fun setupIrisGazeTracker() {
        if (irisGazeTracker == null) {
            try {
                irisGazeTracker = MediaPipeIrisGazeTracker(requireContext())
                Timber.d("MediaPipe Iris GazeTracker initialized")
            } catch (e: Exception) {
                Timber.e(e, "Error setting up MediaPipe Iris GazeTracker")
            }
        }
    }

    private fun startCamera() {
        val executor = cameraExecutor ?: return
        val cameraProviderFuture = ProcessCameraProvider.getInstance(requireContext())

        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()

                // Set up image analysis for processing frames
                val imageAnalysis = ImageAnalysis.Builder()
                    .setTargetResolution(Size(640, 480))
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()

                imageAnalysis.setAnalyzer(executor) { imageProxy ->
                    if (!isProcessing && irisGazeTracker != null) {
                        isProcessing = true
                        var bitmap: android.graphics.Bitmap? = null
                        var mirroredBitmap: android.graphics.Bitmap? = null
                        try {
                            // Convert ImageProxy to Bitmap
                            bitmap = imageProxy.toBitmap()

                            // Mirror the bitmap horizontally for front camera
                            // (so left-right movement feels natural)
                            val matrix = android.graphics.Matrix()
                            matrix.preScale(-1f, 1f)
                            mirroredBitmap = android.graphics.Bitmap.createBitmap(
                                bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true
                            )

                            // Estimate gaze using MediaPipe Iris
                            val gazeResult = irisGazeTracker?.estimateGaze(mirroredBitmap)

                            frameCount++
                            if (frameCount % 60 == 0) {  // Log less frequently to reduce overhead
                                if (gazeResult != null) {
                                    Timber.d(
                                        "EyeGaze (Iris): gazeX=%.2f gazeY=%.2f conf=%.2f",
                                        gazeResult.gazeX,
                                        gazeResult.gazeY,
                                        gazeResult.confidence
                                    )
                                } else {
                                    Timber.d("EyeGaze (Iris): No face detected")
                                }
                            }

                            // Post result to ViewModel
                            viewModel.onIrisGazeResult(gazeResult, gazeResult != null)
                        } catch (e: Exception) {
                            Timber.e(e, "Error processing image")
                            viewModel.onIrisGazeResult(null, false)
                        } finally {
                            // CRITICAL: Always recycle BOTH bitmaps to prevent memory leaks
                            // This prevents GC pauses that cause cursor freezing
                            try {
                                mirroredBitmap?.recycle()
                                // Only recycle original if it's different from mirrored
                                if (bitmap != null && bitmap != mirroredBitmap) {
                                    bitmap.recycle()
                                }
                            } catch (e: Exception) {
                                // Ignore recycling errors
                            }
                            isProcessing = false
                        }
                    }
                    imageProxy.close()
                }

                // Use front camera for face tracking
                val cameraSelector = CameraSelector.Builder()
                    .requireLensFacing(CameraSelector.LENS_FACING_FRONT)
                    .build()

                // Unbind all use cases before rebinding
                cameraProvider.unbindAll()

                // Bind use cases to camera
                cameraProvider.bindToLifecycle(
                    viewLifecycleOwner,
                    cameraSelector,
                    imageAnalysis
                )

                Timber.d("Camera started with MediaPipe Iris tracking")
            } catch (e: Exception) {
                Timber.e(e, "Camera binding failed")
            }
        }, ContextCompat.getMainExecutor(requireContext()))
    }

    private fun stopCamera() {
        try {
            val cameraProviderFuture = ProcessCameraProvider.getInstance(requireContext())
            cameraProviderFuture.addListener({
                val cameraProvider = cameraProviderFuture.get()
                cameraProvider.unbindAll()
            }, ContextCompat.getMainExecutor(requireContext()))
        } catch (e: Exception) {
            Timber.e(e, "Error stopping camera")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor?.shutdown()
        irisGazeTracker?.close()
    }
}
