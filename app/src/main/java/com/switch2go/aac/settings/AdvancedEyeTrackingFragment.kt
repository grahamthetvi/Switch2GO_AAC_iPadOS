package com.switch2go.aac.settings

import android.os.Bundle
import android.view.View
import androidx.navigation.fragment.findNavController
import com.switch2go.aac.BaseFragment
import com.switch2go.aac.BindingInflater
import com.switch2go.aac.R
import com.switch2go.aac.databinding.FragmentAdvancedEyeTrackingBinding
import com.switch2go.aac.eyegazetracking.EyeGazeTrackingViewModel
import com.switch2go.aac.eyegazetracking.EyeSelection
import com.switch2go.aac.eyegazetracking.EyeTrackingMethod
import com.switch2go.aac.eyegazetracking.SmoothingMode
import com.switch2go.aac.utils.Switch2GOSharedPreferences
import org.koin.android.ext.android.inject
import org.koin.androidx.scope.scopeActivity
import org.koin.androidx.viewmodel.ext.android.getViewModel
import timber.log.Timber

/**
 * Fragment for advanced eye tracking settings.
 * Contains GPU toggle, 2D/3D tracking mode, and smoothing mode options.
 */
class AdvancedEyeTrackingFragment : BaseFragment<FragmentAdvancedEyeTrackingBinding>() {

    override val bindingInflater: BindingInflater<FragmentAdvancedEyeTrackingBinding> =
        FragmentAdvancedEyeTrackingBinding::inflate

    private lateinit var viewModel: EyeGazeTrackingViewModel
    private val sharedPrefs: Switch2GOSharedPreferences by inject()
    private var gpuEnabled = false

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        viewModel = requireNotNull(scopeActivity?.getViewModel()) {
            "AdvancedEyeTrackingFragment requires parent to be a ScopeActivity"
        }

        setupUI()
    }

    private fun setupUI() {
        // Back button
        binding.backButton.action = {
            findNavController().popBackStack()
        }

        // GPU toggle
        binding.gpuSwitch.text = getString(R.string.gpu_rendering_label)
        gpuEnabled = sharedPrefs.getGpuRenderingEnabled()
        binding.gpuSwitch.isChecked = gpuEnabled

        binding.gpuSwitch.action = {
            gpuEnabled = !gpuEnabled
            sharedPrefs.setGpuRenderingEnabled(gpuEnabled)
            binding.gpuSwitch.isChecked = gpuEnabled
            Timber.d("GPU rendering ${if (gpuEnabled) "enabled" else "disabled"}")
        }

        // Tracking mode button (2D/3D)
        binding.trackingModeButton.action = {
            val newMethod = viewModel.cycleTrackingMethod()
            updateTrackingModeButton(newMethod)
            // Save to preferences
            val modeString = if (newMethod == EyeTrackingMethod.TRACKING_3D) {
                Switch2GOSharedPreferences.EYE_TRACKING_MODE_3D
            } else {
                Switch2GOSharedPreferences.EYE_TRACKING_MODE_2D
            }
            sharedPrefs.setEyeTrackingMode(modeString)
        }

        // Smoothing mode button
        binding.smoothingModeButton.action = {
            val newMode = viewModel.cycleSmoothingMode()
            updateSmoothingModeButton(newMode)
        }

        // Eye selection button
        binding.eyeSelectionButton.action = {
            val newSelection = viewModel.cycleEyeSelection()
            updateEyeSelectionButton(newSelection)
            // Save to preferences
            sharedPrefs.setEyeSelection(newSelection.name)
        }

        // Gaze amplification button
        binding.gazeAmplificationButton.action = {
            val newAmplification = viewModel.cycleGazeAmplification()
            updateGazeAmplificationButton(newAmplification)
        }

        // Auto-recenter toggle button
        binding.autoRecenterButton.action = {
            val newState = !viewModel.isAutoRecenterEnabled()
            viewModel.setAutoRecenterEnabled(newState)
            updateAutoRecenterButton(newState)
        }

        // Recenter cursor button
        binding.recenterCursorButton.action = {
            viewModel.recenterCursorManual()
        }

        // Reset button
        binding.resetButton.action = {
            resetToDefaults()
        }

        // Observe changes
        viewModel.smoothingModeLd.observe(viewLifecycleOwner) { mode ->
            updateSmoothingModeButton(mode)
        }

        viewModel.trackingMethodLd.observe(viewLifecycleOwner) { method ->
            updateTrackingModeButton(method)
        }

        viewModel.eyeSelectionLd.observe(viewLifecycleOwner) { selection ->
            updateEyeSelectionButton(selection)
        }

        viewModel.gazeAmplificationLd.observe(viewLifecycleOwner) { amplification ->
            updateGazeAmplificationButton(amplification)
        }

        viewModel.recenterEvent.observe(viewLifecycleOwner) { source ->
            // Could show a toast or visual feedback here if desired
            source?.let {
                Timber.d("Recenter event: $it")
            }
        }

        // Initialize with current settings
        updateSmoothingModeButton(viewModel.getSmoothingMode())
        updateTrackingModeButton(viewModel.getTrackingMethod())
        updateEyeSelectionButton(viewModel.getEyeSelection())
        updateGazeAmplificationButton(viewModel.getGazeAmplification())
        updateAutoRecenterButton(viewModel.isAutoRecenterEnabled())

        // Load tracking mode from preferences
        val savedMode = sharedPrefs.getEyeTrackingMode()
        val trackingMethod = if (savedMode == Switch2GOSharedPreferences.EYE_TRACKING_MODE_3D) {
            EyeTrackingMethod.TRACKING_3D
        } else {
            EyeTrackingMethod.TRACKING_2D
        }
        viewModel.setTrackingMethod(trackingMethod)

        // Load eye selection from preferences
        val savedEyeSelection = sharedPrefs.getEyeSelection()
        val eyeSelection = EyeSelection.fromString(savedEyeSelection)
        viewModel.setEyeSelection(eyeSelection)
    }

    private fun updateTrackingModeButton(method: EyeTrackingMethod) {
        val text = when (method) {
            EyeTrackingMethod.TRACKING_2D -> getString(R.string.tracking_mode_2d)
            EyeTrackingMethod.TRACKING_3D -> getString(R.string.tracking_mode_3d)
        }
        binding.trackingModeButton.text = text
    }

    private fun updateSmoothingModeButton(mode: SmoothingMode) {
        val text = when (mode) {
            SmoothingMode.SIMPLE_LERP -> getString(R.string.smoothing_mode_simple)
            SmoothingMode.KALMAN_FILTER -> getString(R.string.smoothing_mode_kalman)
            SmoothingMode.ADAPTIVE_KALMAN -> getString(R.string.smoothing_mode_adaptive)
            SmoothingMode.COMBINED -> getString(R.string.smoothing_mode_combined)
        }
        binding.smoothingModeButton.text = text
    }

    private fun updateEyeSelectionButton(selection: EyeSelection) {
        val text = when (selection) {
            EyeSelection.BOTH_EYES -> getString(R.string.eye_selection_both)
            EyeSelection.LEFT_EYE_ONLY -> getString(R.string.eye_selection_left)
            EyeSelection.RIGHT_EYE_ONLY -> getString(R.string.eye_selection_right)
        }
        binding.eyeSelectionButton.text = text
    }

    private fun updateGazeAmplificationButton(amplification: Float) {
        val text = if (amplification <= 1.0f) {
            getString(R.string.gaze_amplification_off)
        } else {
            getString(R.string.gaze_amplification_level, amplification)
        }
        binding.gazeAmplificationButton.text = text
    }

    private fun updateAutoRecenterButton(enabled: Boolean) {
        val text = if (enabled) {
            getString(R.string.recenter_auto)
        } else {
            getString(R.string.recenter_auto_off)
        }
        binding.autoRecenterButton.text = text
    }

    /**
     * Reset all advanced eye tracking settings to their default values.
     */
    private fun resetToDefaults() {
        // Reset GPU rendering (default: disabled)
        gpuEnabled = false
        sharedPrefs.setGpuRenderingEnabled(false)
        binding.gpuSwitch.isChecked = false

        // Reset tracking mode (default: 2D)
        val defaultTrackingMethod = EyeTrackingMethod.TRACKING_2D
        viewModel.setTrackingMethod(defaultTrackingMethod)
        sharedPrefs.setEyeTrackingMode(Switch2GOSharedPreferences.EYE_TRACKING_MODE_2D)
        updateTrackingModeButton(defaultTrackingMethod)

        // Reset smoothing mode (default: Adaptive Kalman)
        val defaultSmoothingMode = SmoothingMode.ADAPTIVE_KALMAN
        viewModel.setSmoothingMode(defaultSmoothingMode)
        updateSmoothingModeButton(defaultSmoothingMode)

        // Reset eye selection (default: Both Eyes)
        val defaultEyeSelection = EyeSelection.BOTH_EYES
        viewModel.setEyeSelection(defaultEyeSelection)
        sharedPrefs.setEyeSelection(Switch2GOSharedPreferences.EYE_SELECTION_BOTH)
        updateEyeSelectionButton(defaultEyeSelection)

        // Reset gaze amplification (default: 1.0x / Off)
        val defaultAmplification = Switch2GOSharedPreferences.DEFAULT_GAZE_AMPLIFICATION
        viewModel.setGazeAmplification(defaultAmplification)
        updateGazeAmplificationButton(defaultAmplification)

        // Reset auto-recenter (default: enabled)
        viewModel.setAutoRecenterEnabled(true)
        updateAutoRecenterButton(true)

        // Reset gaze offset
        viewModel.resetGazeOffset()

        Timber.d("Advanced eye tracking settings reset to defaults")
    }

    override fun getAllViews(): List<View> {
        return emptyList()
    }
}

