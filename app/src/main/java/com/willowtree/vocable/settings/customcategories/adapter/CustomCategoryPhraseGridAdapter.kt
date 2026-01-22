package com.willowtree.vocable.settings.customcategories.adapter

import android.annotation.SuppressLint
import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import androidx.core.view.isInvisible
import com.willowtree.vocable.R
import com.willowtree.vocable.databinding.EditCustomCategoryPhraseItemBinding
import com.willowtree.vocable.presets.Phrase
import org.koin.core.component.KoinComponent

class CustomCategoryPhraseGridAdapter(
    context: Context,
    private var phrases: List<Phrase>,
    private val onPhraseEdit: (Phrase) -> Unit,
    @Suppress("UNUSED_PARAMETER") private val onPhraseDelete: (Phrase) -> Unit // Keep for API compatibility, delete is now in menu
) :
    ArrayAdapter<Phrase>(
        context,
        R.layout.edit_custom_category_phrase_item
    ),
    KoinComponent {

    private lateinit var binding: EditCustomCategoryPhraseItemBinding

    init {
        addAll(phrases)
    }

    // Linter warns about using ViewHolder for smoother scrolling, but we shouldn't be scrolling here anyway
    @SuppressLint("ViewHolder")
    override fun getView(position: Int, itemView: View?, parent: ViewGroup): View {
        binding =
            EditCustomCategoryPhraseItemBinding.inflate(LayoutInflater.from(context), parent, false)

        val listItemView: View = binding.root

        listItemView.isInvisible = true
        
        // Both the edit icon button and the phrase text button go to the edit menu
        binding.removeCategoryButton.action = {
            onPhraseEdit(phrases[position])
        }
        binding.phraseTextButton.action = {
            onPhraseEdit(phrases[position])
        }
        
        binding.root.setPaddingRelative(
            0,
            context.resources.getDimensionPixelSize(R.dimen.edit_category_phrase_button_margin),
            0,
            0
        )
        
        // Set phrase text and accessible content description with position
        val phraseText = phrases[position].text(context)
        binding.phraseTextButton.text = phraseText
        binding.phraseTextButton.contentDescription = 
            context.getString(R.string.current_position, position + 1, phrases.size) + 
            ", $phraseText. " + context.getString(R.string.edit_phrases)
        
        parent.post {
            with(listItemView) {
                isInvisible = false
            }
        }
        return listItemView
    }
}