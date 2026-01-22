package com.willowtree.vocable.settings

import android.os.Bundle
import android.view.View
import androidx.navigation.fragment.findNavController
import com.willowtree.vocable.BaseFragment
import com.willowtree.vocable.BindingInflater
import com.willowtree.vocable.R
import com.willowtree.vocable.databinding.FragmentCviDisplaySettingsBinding
import com.willowtree.vocable.utils.VocableSharedPreferences
import org.koin.android.ext.android.inject

/**
 * Fragment for CVI-friendly display settings.
 * Allows users to configure the number of symbols shown.
 */
class CVIDisplaySettingsFragment : BaseFragment<FragmentCviDisplaySettingsBinding>() {

    override val bindingInflater: BindingInflater<FragmentCviDisplaySettingsBinding> =
        FragmentCviDisplaySettingsBinding::inflate

    private val sharedPrefs: VocableSharedPreferences by inject()
    private var currentSymbolCount = VocableSharedPreferences.DEFAULT_SYMBOL_COUNT

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Load current symbol count
        currentSymbolCount = sharedPrefs.getSymbolCount()
        updateDisplay()

        setupUI()
    }

    private fun setupUI() {
        // Back button
        binding.backButton.action = {
            findNavController().popBackStack()
        }

        // Decrease symbol count
        binding.decreaseButton.action = {
            if (currentSymbolCount > VocableSharedPreferences.MIN_SYMBOL_COUNT) {
                currentSymbolCount--
                saveAndUpdateDisplay()
            }
        }

        // Increase symbol count
        binding.increaseButton.action = {
            if (currentSymbolCount < VocableSharedPreferences.MAX_SYMBOL_COUNT) {
                currentSymbolCount++
                saveAndUpdateDisplay()
            }
        }

    }

    private fun saveAndUpdateDisplay() {
        sharedPrefs.setSymbolCount(currentSymbolCount)
        updateDisplay()
    }

    private fun updateDisplay() {
        binding.symbolCountValue.text = currentSymbolCount.toString()

        // Update button states
        binding.decreaseButton.isEnabled = currentSymbolCount > VocableSharedPreferences.MIN_SYMBOL_COUNT
        binding.increaseButton.isEnabled = currentSymbolCount < VocableSharedPreferences.MAX_SYMBOL_COUNT

        binding.decreaseButton.alpha = if (binding.decreaseButton.isEnabled) 1.0f else 0.5f
        binding.increaseButton.alpha = if (binding.increaseButton.isEnabled) 1.0f else 0.5f

        // Update preview text
        val layoutDescription = when (currentSymbolCount) {
            2 -> getString(R.string.layout_description_2)
            3 -> getString(R.string.layout_description_3)
            4 -> getString(R.string.layout_description_4)
            5 -> getString(R.string.layout_description_5)
            else -> getString(R.string.layout_description_more, currentSymbolCount)
        }
        binding.previewText.text = layoutDescription
    }

    override fun getAllViews(): List<View> {
        return emptyList()
    }
}
