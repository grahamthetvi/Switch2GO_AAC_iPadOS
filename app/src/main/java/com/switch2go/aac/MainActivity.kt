package com.switch2go.aac

import android.content.Context
import android.graphics.Rect
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import androidx.core.view.children
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import com.switch2go.aac.customviews.PointerListener
import com.switch2go.aac.customviews.PointerView
import com.switch2go.aac.databinding.ActivityMainBinding
import com.switch2go.aac.eyegazetracking.EyeGazeTrackingViewModel
import com.switch2go.aac.facetracking.FaceTrackingViewModel
import com.switch2go.aac.utils.EyeGazePointerUpdates
import com.switch2go.aac.utils.EyeGazeTrackingManager
import com.switch2go.aac.utils.FaceTrackingManager
import com.switch2go.aac.utils.FaceTrackingPointerUpdates
import com.switch2go.aac.utils.ISwitch2GOSharedPreferences
import com.switch2go.aac.utils.SelectionMode
import com.switch2go.aac.utils.Switch2GOEnvironment
import com.switch2go.aac.utils.Switch2GOEnvironmentType
import com.switch2go.aac.utils.Switch2GOTextToSpeech
import io.github.inflationx.viewpump.ViewPump
import io.github.inflationx.viewpump.ViewPumpContextWrapper
import kotlinx.coroutines.launch
import org.koin.android.ext.android.inject
import org.koin.androidx.scope.ScopeActivity
import org.koin.androidx.viewmodel.ext.android.getViewModel

class MainActivity : ScopeActivity() {

    private var currentView: View? = null
    private var paused = false
    private lateinit var binding: ActivityMainBinding
    private val sharedPrefs: ISwitch2GOSharedPreferences by inject()
    private val allViews = mutableListOf<View>()

    private val faceTrackingManager: FaceTrackingManager by inject()
    private val eyeGazeTrackingManager: EyeGazeTrackingManager by inject()
    private val environment: Switch2GOEnvironment by inject()

    private lateinit var faceTrackingViewModel: FaceTrackingViewModel
    private lateinit var eyeGazeTrackingViewModel: EyeGazeTrackingViewModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        faceTrackingViewModel = getViewModel()
        eyeGazeTrackingViewModel = getViewModel()

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        if (environment.environmentType != Switch2GOEnvironmentType.TESTING) {
            lifecycleScope.launch {
                // Initialize head tracking (ARCore)
                faceTrackingManager.initialize(
                    faceTrackingPointerUpdates = object : FaceTrackingPointerUpdates {
                        override fun toggleVisibility(visible: Boolean) {
                            // Only show pointer if head tracking is the active mode
                            if (sharedPrefs.getSelectionMode() == SelectionMode.HEAD_TRACKING) {
                                binding.pointerView.isVisible = visible
                            }
                        }
                    })
            }

            lifecycleScope.launch {
                // Initialize eye gaze tracking (MediaPipe)
                eyeGazeTrackingManager.initialize(
                    eyeGazePointerUpdates = object : EyeGazePointerUpdates {
                        override fun toggleVisibility(visible: Boolean) {
                            // Only show pointer if eye gaze is the active mode
                            if (sharedPrefs.getSelectionMode() == SelectionMode.EYE_GAZE) {
                                binding.pointerView.isVisible = visible
                            }
                        }
                    })
            }

            // Set display metrics for eye gaze ViewModel
            eyeGazeTrackingViewModel.setDisplayMetrics(eyeGazeTrackingManager.displayMetrics)
        }

        // Head tracking error handling
        faceTrackingViewModel.showError.observe(this) { showError ->
            if (!sharedPrefs.getHeadTrackingEnabled() || sharedPrefs.getSelectionMode() != SelectionMode.HEAD_TRACKING) {
                return@observe
            }
            if (showError) {
                (currentView as? PointerListener)?.onPointerExit()
            }
            getErrorView().isVisible = showError
            getPointerView().isVisible = !showError
        }

        // Eye gaze error handling
        eyeGazeTrackingViewModel.showError.observe(this) { showError ->
            if (!sharedPrefs.getEyeGazeEnabled() || sharedPrefs.getSelectionMode() != SelectionMode.EYE_GAZE) {
                return@observe
            }
            if (showError) {
                (currentView as? PointerListener)?.onPointerExit()
            }
            getErrorView().isVisible = showError
            getPointerView().isVisible = !showError
        }

        // Eye gaze out-of-bounds handling (auto-hide cursor when looking far away)
        eyeGazeTrackingViewModel.gazeInBounds.observe(this) { isInBounds ->
            if (!sharedPrefs.getEyeGazeEnabled() || sharedPrefs.getSelectionMode() != SelectionMode.EYE_GAZE) {
                return@observe
            }
            // Only handle visibility if there's no error already being shown
            if (eyeGazeTrackingViewModel.showError.value != true) {
                if (!isInBounds) {
                    // Gaze is out of bounds - hide cursor and cancel any dwell
                    (currentView as? PointerListener)?.onPointerExit()
                    currentView = null
                }
                getPointerView().isVisible = isInBounds
            }
        }

        // Head tracking pointer updates
        faceTrackingViewModel.pointerLocation.observe(this) {
            if (sharedPrefs.getSelectionMode() == SelectionMode.HEAD_TRACKING) {
                updatePointer(it.x, it.y)
            }
        }

        // Eye gaze pointer updates
        eyeGazeTrackingViewModel.pointerLocation.observe(this) { (x, y) ->
            if (sharedPrefs.getSelectionMode() == SelectionMode.EYE_GAZE) {
                updatePointer(x, y)
            }
        }

        supportActionBar?.hide()
        Switch2GOTextToSpeech.initialize(this)

        binding.mainNavHostFragment?.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            allViews.clear()
        }
    }

    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(ViewPumpContextWrapper.Companion.wrap(newBase, ViewPump.builder().build()))
    }

    override fun onDestroy() {
        super.onDestroy()
        Switch2GOTextToSpeech.shutdown()
    }

    private fun getErrorView(): View = binding.errorView.root

    private fun getPointerView(): PointerView = binding.pointerView

    fun getAllViews(): List<View> {
        if (allViews.isEmpty()) {
            getAllChildViews(binding.parentLayout)
            getAllFragmentViews()
        }
        return allViews
    }

    fun resetAllViews() {
        allViews.clear()
    }

    private fun getAllChildViews(viewGroup: ViewGroup) {
        viewGroup.children.forEach {
            if (it is PointerListener) {
                allViews.add(it)
            } else if (it is ViewGroup) {
                getAllChildViews(it)
            }
        }
    }

    private fun getAllFragmentViews() {
        supportFragmentManager.fragments.forEach {
            if (it is BaseFragment<*>) {
                allViews.addAll(it.getAllViews())
            }
        }
    }

    private fun updatePointer(x: Float, y: Float) {
        var newX = x
        var newY = y
        if (x < 0) {
            newX = 0f
        } else if (x > faceTrackingManager.displayMetrics.widthPixels) {
            newX = faceTrackingManager.displayMetrics.widthPixels.toFloat()
        }

        if (y < 0) {
            newY = 0f
        } else if (y > faceTrackingManager.displayMetrics.heightPixels) {
            newY = faceTrackingManager.displayMetrics.heightPixels.toFloat()
        }
        getPointerView().updatePointerPosition(newX, newY)
        getPointerView().bringToFront()

        if (currentView == null) {
            findIntersectingView()
        } else {
            if (!viewIntersects(currentView!!, getPointerView())) {
                (currentView as? PointerListener)?.onPointerExit()
                findIntersectingView()
            }
        }
    }

    private fun findIntersectingView() {
        currentView = null
        if (!paused) {
            getAllViews().forEach {
                if (viewIntersects(it, getPointerView())) {
                    if (it.isEnabled && it.isVisible) {
                        currentView = it
                        (currentView as PointerListener).onPointerEnter()
                        return
                    }
                }
            }
        }
    }

    private fun viewIntersects(view1: View, view2: View): Boolean {
        val coords = IntArray(2)
        view1.getLocationOnScreen(coords)
        val rect = Rect(
            coords[0],
            coords[1],
            coords[0] + view1.measuredWidth,
            coords[1] + view1.measuredHeight
        )

        val view2Coords = IntArray(2)
        view2.getLocationOnScreen(view2Coords)
        val view2Rect = Rect(
            view2Coords[0],
            view2Coords[1],
            view2Coords[0] + view2.measuredWidth,
            view2Coords[1] + view2.measuredHeight
        )
        return rect.contains(view2Rect.centerX(), view2Rect.centerY())
    }

}