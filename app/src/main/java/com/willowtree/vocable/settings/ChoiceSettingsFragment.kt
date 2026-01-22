package com.willowtree.vocable.settings

import android.os.Bundle
import android.view.View
import androidx.navigation.fragment.findNavController
import com.willowtree.vocable.BaseFragment
import com.willowtree.vocable.BindingInflater
import com.willowtree.vocable.R
import com.willowtree.vocable.databinding.FragmentChoiceSettingsBinding
import com.willowtree.vocable.utils.VocableSharedPreferences
import org.koin.android.ext.android.inject

class ChoiceSettingsFragment : BaseFragment<FragmentChoiceSettingsBinding>() {

    override val bindingInflater: BindingInflater<FragmentChoiceSettingsBinding> =
        FragmentChoiceSettingsBinding::inflate

    private val sharedPrefs: VocableSharedPreferences by inject()

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.backButton.action = {
            findNavController().popBackStack()
        }

        // Initialize choice mode toggle
        binding.choiceModeToggle.isChecked = sharedPrefs.getChoiceModeEnabled()
        binding.choiceModeToggle.action = {
            val newValue = !binding.choiceModeToggle.isChecked
            binding.choiceModeToggle.isChecked = newValue
            sharedPrefs.setChoiceModeEnabled(newValue)
        }

        // Initialize visual feedback toggle
        binding.visualFeedbackToggle.isChecked = sharedPrefs.getChoiceVisualFeedbackEnabled()
        binding.visualFeedbackToggle.action = {
            val newValue = !binding.visualFeedbackToggle.isChecked
            binding.visualFeedbackToggle.isChecked = newValue
            sharedPrefs.setChoiceVisualFeedbackEnabled(newValue)
        }
    }

    override fun getAllViews(): List<View> {
        return emptyList()
    }
}