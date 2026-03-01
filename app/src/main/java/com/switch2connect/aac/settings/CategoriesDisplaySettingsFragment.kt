package com.switch2connect.aac.settings

import android.os.Bundle
import android.view.View
import androidx.navigation.fragment.findNavController
import com.switch2connect.aac.BaseFragment
import com.switch2connect.aac.BindingInflater
import com.switch2connect.aac.R
import com.switch2connect.aac.databinding.FragmentCategoriesDisplaySettingsBinding

class CategoriesDisplaySettingsFragment :
    BaseFragment<FragmentCategoriesDisplaySettingsBinding>() {

    override val bindingInflater: BindingInflater<FragmentCategoriesDisplaySettingsBinding> =
        FragmentCategoriesDisplaySettingsBinding::inflate

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.backButton.action = {
            findNavController().popBackStack()
        }

        binding.categoriesPhrasesButton.action = {
            if (findNavController().currentDestination?.id == R.id.categoriesDisplaySettingsFragment) {
                findNavController()
                    .navigate(R.id.action_categoriesDisplaySettingsFragment_to_editCategoriesFragment)
            }
        }

        binding.displaySettingsButton.action = {
            if (findNavController().currentDestination?.id == R.id.categoriesDisplaySettingsFragment) {
                findNavController()
                    .navigate(R.id.action_categoriesDisplaySettingsFragment_to_cviDisplaySettingsFragment)
            }
        }
    }

    override fun getAllViews(): List<View> {
        return emptyList()
    }
}
