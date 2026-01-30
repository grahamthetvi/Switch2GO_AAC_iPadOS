package com.switch2go.aac.settings

import android.os.Bundle
import android.view.View
import androidx.navigation.fragment.findNavController
import com.switch2go.aac.BaseFragment
import com.switch2go.aac.BindingInflater
import com.switch2go.aac.R
import com.switch2go.aac.databinding.FragmentCviDisplaySettingsBinding
import com.switch2go.aac.utils.Switch2GOSharedPreferences
import org.koin.android.ext.android.inject

/**
 * Fragment for CVI-friendly display settings.
 * Allows users to configure the number of symbols shown.
 */
class CVIDisplaySettingsFragment : BaseFragment<FragmentCviDisplaySettingsBinding>() {

    override val bindingInflater: BindingInflater<FragmentCviDisplaySettingsBinding> =
        FragmentCviDisplaySettingsBinding::inflate

    private val sharedPrefs: Switch2GOSharedPreferences by inject()
    private var currentSymbolCount = Switch2GOSharedPreferences.DEFAULT_SYMBOL_COUNT

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
            if (currentSymbolCount > Switch2GOSharedPreferences.MIN_SYMBOL_COUNT) {
                currentSymbolCount--
                saveAndUpdateDisplay()
            }
        }

        // Increase symbol count
        binding.increaseButton.action = {
            if (currentSymbolCount < Switch2GOSharedPreferences.MAX_SYMBOL_COUNT) {
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
        binding.decreaseButton.isEnabled = currentSymbolCount > Switch2GOSharedPreferences.MIN_SYMBOL_COUNT
        binding.increaseButton.isEnabled = currentSymbolCount < Switch2GOSharedPreferences.MAX_SYMBOL_COUNT

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
