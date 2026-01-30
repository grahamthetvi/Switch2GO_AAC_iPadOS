package com.switch2go.aac.settings.customcategories

import android.os.Build
import android.os.Bundle
import android.view.View
import androidx.core.os.bundleOf
import androidx.core.view.isVisible
import androidx.navigation.fragment.findNavController
import com.switch2go.aac.BaseFragment
import com.switch2go.aac.BindingInflater
import com.switch2go.aac.R
import com.switch2go.aac.databinding.FragmentCustomCategoryPhraseListBinding
import com.switch2go.aac.presets.Category
import com.switch2go.aac.presets.Phrase
import com.switch2go.aac.settings.EditCategoryPhrasesFragmentDirections
import com.switch2go.aac.settings.customcategories.adapter.CustomCategoryPhraseGridAdapter
import org.koin.androidx.viewmodel.ext.android.viewModel

class CustomCategoryPhraseListFragment : BaseFragment<FragmentCustomCategoryPhraseListBinding>() {

    companion object {
        private const val KEY_PHRASES = "KEY_PHRASES"
        private const val KEY_CATEGORY = "KEY_CATEGORY"

        fun newInstance(
            phrases: List<Phrase>,
            category: Category
        ): CustomCategoryPhraseListFragment {
            return CustomCategoryPhraseListFragment().apply {
                arguments = bundleOf(KEY_PHRASES to ArrayList(phrases), KEY_CATEGORY to category)
            }
        }
    }

    private val viewModel: CustomCategoryPhraseViewModel by viewModel()
    private lateinit var category: Category

    private val onPhraseEdit = { phrase: Phrase ->
        // Navigate to the new phrase edit menu which provides accessible reordering
        // and style editing options
        val action =
            EditCategoryPhrasesFragmentDirections.actionEditCategoryPhrasesFragmentToPhraseEditMenuFragment(
                phrase,
                category
            )
        if (findNavController().currentDestination?.id == R.id.editCategoryPhrasesFragment) {
            findNavController().navigate(action)
        }
    }

    // Delete is now handled in the phrase edit menu
    private val onPhraseDelete = { _: Phrase ->
        // No-op - delete is now in the PhraseEditMenuFragment
    }

    override val bindingInflater: BindingInflater<FragmentCustomCategoryPhraseListBinding> =
        FragmentCustomCategoryPhraseListBinding::inflate

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        arguments?.getParcelable<Category>(KEY_CATEGORY)?.let {
            category = it
        }

        val numColumns = resources.getInteger(R.integer.custom_category_phrase_columns)

        val phrases = arguments?.getParcelableArrayList<Phrase>(KEY_PHRASES)

        phrases?.let {
            with(binding.customCategoryPhraseHolder) {
                setNumColumns(numColumns)
                adapter = CustomCategoryPhraseGridAdapter(
                    context = requireContext(),
                    phrases = it,
                    onPhraseEdit = onPhraseEdit,
                    onPhraseDelete = onPhraseDelete,
                )
            }
        }
    }

    override fun getAllViews(): List<View> = emptyList()
}
