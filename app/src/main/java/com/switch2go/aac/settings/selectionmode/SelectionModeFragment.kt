package com.switch2go.aac.settings.selectionmode

import android.os.Bundle
import android.view.View
import androidx.navigation.fragment.findNavController
import com.switch2go.aac.BaseFragment
import com.switch2go.aac.BindingInflater
import com.switch2go.aac.R
import com.switch2go.aac.databinding.FragmentSelectionModeBinding
import org.koin.androidx.scope.scopeActivity
import org.koin.androidx.viewmodel.ext.android.getViewModel

class SelectionModeFragment : BaseFragment<FragmentSelectionModeBinding>() {

    override val bindingInflater: BindingInflater<FragmentSelectionModeBinding> = FragmentSelectionModeBinding::inflate
    private lateinit var viewModel: SelectionModeViewModel

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        viewModel = requireNotNull(scopeActivity?.getViewModel()) {
            "SelectionModeFragment requires parent to be a ScopeActivity"
        }

        binding.selectionModeBackButton.action = {
            findNavController().popBackStack()
        }

        // Head Tracking switch
        binding.selectionModeOptions.selectionModeSwitch.text = getString(R.string.settings_head_tracking)

        viewModel.headTrackingEnabled.observe(viewLifecycleOwner) {
            binding.selectionModeOptions.selectionModeSwitch.isChecked = it
        }

        binding.selectionModeOptions.selectionModeSwitch.action = {
            if (!binding.selectionModeOptions.selectionModeSwitch.isChecked) {
                viewModel.requestHeadTracking()
            } else {
                viewModel.disableHeadTracking()
            }
        }

        // Eye Gaze switch
        binding.selectionModeOptions.eyeGazeSwitch.text = getString(R.string.settings_eye_gaze)

        viewModel.eyeGazeEnabled.observe(viewLifecycleOwner) {
            binding.selectionModeOptions.eyeGazeSwitch.isChecked = it
        }

        binding.selectionModeOptions.eyeGazeSwitch.action = {
            if (!binding.selectionModeOptions.eyeGazeSwitch.isChecked) {
                viewModel.requestEyeGaze()
            } else {
                viewModel.disableEyeGaze()
            }
        }
    }

    override fun getAllViews(): List<View> {
        return listOf()
    }
}
