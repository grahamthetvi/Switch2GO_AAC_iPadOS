package com.willowtree.vocable.utils

import android.content.Context
import android.hardware.display.DisplayManager
import android.util.DisplayMetrics
import android.view.Surface
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import com.willowtree.vocable.BuildConfig
import com.willowtree.vocable.R
import com.willowtree.vocable.eyegazetracking.EyeGazeTrackFragment
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import timber.log.Timber

/**
 * Interface for updating the eye gaze pointer visibility
 */
interface EyeGazePointerUpdates {
    fun toggleVisibility(visible: Boolean)
}

/**
 * Manager class for eye gaze tracking using MediaPipe FaceLandmarker.
 * Similar to FaceTrackingManager but uses MediaPipe instead of ARCore.
 */
class EyeGazeTrackingManager(
    private val activity: AppCompatActivity,
    private val eyeGazePermissions: IEyeGazePermissions,
) {
    val displayMetrics = DisplayMetrics()

    private lateinit var eyeGazePointerUpdates: EyeGazePointerUpdates

    /**
     * Initializes the EyeGazeTrackingManager and begins listening to permission state updates.
     */
    suspend fun initialize(eyeGazePointerUpdates: EyeGazePointerUpdates) {
        this.eyeGazePointerUpdates = eyeGazePointerUpdates

        activity.windowManager.defaultDisplay.getMetrics(displayMetrics)

        if (BuildConfig.USE_HEAD_TRACKING) { // Reusing this flag for eye gaze as well
            coroutineScope {
                launch {
                    eyeGazePermissions.permissionState.collect { eyeGazeState ->
                        when (eyeGazeState) {
                            IEyeGazePermissions.PermissionState.Enabled -> {
                                togglePointerVisible(true)
                                setupEyeGazeTracking()
                            }
                            IEyeGazePermissions.PermissionState.Disabled -> {
                                togglePointerVisible(false)
                            }
                        }
                    }
                }
            }
        } else {
            eyeGazePermissions.disableEyeGaze()
            togglePointerVisible(false)
        }
    }

    private var hasSetupEyeGaze: Boolean = false

    private fun setupEyeGazeTracking() {
        if (!hasSetupEyeGaze) {
            hasSetupEyeGaze = true

            listenToOrientationChanges()

            if (activity.supportFragmentManager.findFragmentById(R.id.eye_gaze_fragment) == null) {
                activity.supportFragmentManager
                    .beginTransaction()
                    .replace(R.id.eye_gaze_fragment, EyeGazeTrackFragment())
                    .commitAllowingStateLoss()
            } else {
                activity.window
                    .decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    .or(View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION)
                    .or(View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN)
                    .or(View.SYSTEM_UI_FLAG_HIDE_NAVIGATION)
                    .or(View.SYSTEM_UI_FLAG_FULLSCREEN)
                    .or(View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
            }
        }
    }

    private fun togglePointerVisible(visible: Boolean) {
        eyeGazePointerUpdates.toggleVisibility(if (!BuildConfig.USE_HEAD_TRACKING) false else visible)
    }

    /**
     * Resets the EyeGazeTrackFragment if the device is rotated 180 degrees.
     */
    private fun listenToOrientationChanges() {
        val windowManager = activity.windowManager
        val displayListener = object : DisplayManager.DisplayListener {

            private var orientation = activity.windowManager.defaultDisplay.rotation

            override fun onDisplayChanged(displayId: Int) {
                val newOrientation = windowManager.defaultDisplay.rotation
                when (orientation) {
                    Surface.ROTATION_0 -> {
                        if (newOrientation == Surface.ROTATION_180) {
                            resetEyeGazeTrackFragment("eye_gaze_${Surface.ROTATION_180}")
                        }
                    }
                    Surface.ROTATION_90 -> {
                        if (newOrientation == Surface.ROTATION_270) {
                            resetEyeGazeTrackFragment("eye_gaze_${Surface.ROTATION_270}")
                        }
                    }
                    Surface.ROTATION_180 -> {
                        if (newOrientation == Surface.ROTATION_0) {
                            resetEyeGazeTrackFragment("eye_gaze_${Surface.ROTATION_0}")
                        }
                    }
                    Surface.ROTATION_270 -> {
                        if (newOrientation == Surface.ROTATION_90) {
                            resetEyeGazeTrackFragment("eye_gaze_${Surface.ROTATION_90}")
                        }
                    }
                }
                orientation = newOrientation
            }

            override fun onDisplayAdded(displayId: Int) = Unit
            override fun onDisplayRemoved(displayId: Int) = Unit
        }

        val displayManager = activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.registerDisplayListener(displayListener, null)
    }

    private fun resetEyeGazeTrackFragment(tag: String) {
        if (!activity.supportFragmentManager.isDestroyed && 
            activity.supportFragmentManager.findFragmentByTag(tag) == null) {
            activity.supportFragmentManager
                .beginTransaction()
                .replace(R.id.eye_gaze_fragment, EyeGazeTrackFragment(), tag)
                .commitAllowingStateLoss()
        }
    }
}

