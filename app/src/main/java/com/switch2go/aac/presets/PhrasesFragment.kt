package com.switch2go.aac.presets

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.GridLayoutManager
import com.switch2go.aac.BaseFragment
import com.switch2go.aac.BindingInflater
import com.switch2go.aac.R
import com.switch2go.aac.databinding.FragmentPhrasesBinding
import com.switch2go.aac.presets.adapter.PhraseAdapter
import com.switch2go.aac.utils.ItemOffsetDecoration
import org.koin.androidx.viewmodel.ext.android.activityViewModel

class PhrasesFragment : BaseFragment<FragmentPhrasesBinding>() {
    private val presetsViewModel: PresetsViewModel by activityViewModel()

    companion object {
        private const val KEY_PHRASES = "KEY_PHRASES"

        fun newInstance(phrases: List<PhraseGridItem>): PhrasesFragment {
            return PhrasesFragment().apply {
                arguments = Bundle().apply {
                    putParcelableArrayList(KEY_PHRASES, ArrayList(phrases))
                }
            }
        }
    }

    override val bindingInflater: BindingInflater<FragmentPhrasesBinding> =
        FragmentPhrasesBinding::inflate

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        super.onCreateView(inflater, container, savedInstanceState)

        val numColumns = resources.getInteger(R.integer.phrases_columns)
        val numRows = resources.getInteger(R.integer.phrases_rows)

        val phrases = arguments?.getParcelableArrayList<PhraseGridItem>(KEY_PHRASES)
        phrases?.let {
            with(binding.phrasesContainer) {
                layoutManager = GridLayoutManager(requireContext(), numColumns)
                addItemDecoration(
                    ItemOffsetDecoration(
                        requireContext(),
                        R.dimen.speech_button_margin,
                        it.size
                    )
                )

                adapter = PhraseAdapter(it, numRows, { phrase ->
                    presetsViewModel.addToRecents(phrase)
                }, {
                   presetsViewModel.navToAddPhrase()
                })

                setHasFixedSize(true)
            }
        }

        return binding.root
    }

    override fun getAllViews(): List<View> = emptyList()
}