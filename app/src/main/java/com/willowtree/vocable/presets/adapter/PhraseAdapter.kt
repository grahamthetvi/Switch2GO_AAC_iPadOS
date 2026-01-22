package com.willowtree.vocable.presets.adapter

import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.core.view.isInvisible
import androidx.recyclerview.widget.RecyclerView
import com.willowtree.vocable.R
import com.willowtree.vocable.customviews.VocablePhraseButton
import com.willowtree.vocable.databinding.PhraseButtonAddBinding
import com.willowtree.vocable.databinding.PhraseButtonBinding
import com.willowtree.vocable.presets.PhraseGridItem
import com.willowtree.vocable.room.PhraseStyle
import com.willowtree.vocable.utils.PhraseTextBubble
import java.util.Locale

class PhraseAdapter(
    private val phrases: List<PhraseGridItem>,
    private val numRows: Int,
    private val phraseClickAction: ((String) -> Unit)?,
    private val phraseAddClickAction: (() -> Unit)?
) : RecyclerView.Adapter<PhraseAdapter.PhraseViewHolder>() {

    abstract inner class PhraseViewHolder(
        itemView: View
    ) : RecyclerView.ViewHolder(itemView) {
        abstract fun bind(position: Int)
    }

    inner class PhraseGridItemViewHolder(itemView: View) :
        PhraseAdapter.PhraseViewHolder(itemView) {

        override fun bind(position: Int) {
            when (val gridItem = phrases[position]) {
                is PhraseGridItem.Phrase -> {
                    val binding = PhraseButtonBinding.bind(itemView)
                    binding.root.setText(gridItem.text, Locale.getDefault())
                    binding.root.action = {
                        phraseClickAction?.invoke(gridItem.phraseId)
                    }
                    
                    // Apply per-phrase style if available, otherwise clear bubble
                    val style = gridItem.style
                    if (style != null) {
                        applyPhraseStyle(binding.root, style)
                    } else {
                        PhraseTextBubble.apply(binding.root, null)
                    }
                }

                PhraseGridItem.AddPhrase -> {
                    val binding = PhraseButtonAddBinding.bind(itemView)
                    binding.root.action = {
                        phraseAddClickAction?.invoke()
                    }
                }
            }
        }
        
        private fun applyPhraseStyle(button: VocablePhraseButton, style: PhraseStyle) {
            val context = button.context
            val density = context.resources.displayMetrics.density
            val cornerRadius = 16f * density
            val selectedColor = ContextCompat.getColor(context, R.color.selectedColor)
            val backgroundColor = style.effectiveBackgroundColor()
            
            // Darken color for pressed state
            val pressedColor = darkenColor(backgroundColor, 0.7f)

            // Create state list drawable
            val stateListDrawable = StateListDrawable()

            // Pressed state
            val pressedDrawable = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                this.cornerRadius = cornerRadius
                setColor(pressedColor)
                setStroke((4 * density).toInt(), selectedColor)
            }
            stateListDrawable.addState(intArrayOf(android.R.attr.state_pressed), pressedDrawable)

            // Selected state
            val selectedDrawable = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                this.cornerRadius = cornerRadius
                setColor(backgroundColor)
                setStroke((4 * density).toInt(), selectedColor)
            }
            stateListDrawable.addState(intArrayOf(android.R.attr.state_selected), selectedDrawable)

            // Normal state
            val normalDrawable = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                this.cornerRadius = cornerRadius
                setColor(backgroundColor)
            }
            stateListDrawable.addState(intArrayOf(), normalDrawable)

            button.background = stateListDrawable
            
            // Apply text color
            button.setTextColor(style.effectiveTextColor())
            
            // Apply text size
            button.textSize = style.effectiveTextSize()
            
            // Apply bold
            button.setTypeface(
                null,
                if (style.isBold) Typeface.BOLD else Typeface.NORMAL
            )

            // Apply text bubble around the phrase text
            PhraseTextBubble.apply(button, style)
        }
        
        private fun darkenColor(color: Int, factor: Float): Int {
            val a = android.graphics.Color.alpha(color)
            val r = (android.graphics.Color.red(color) * factor).toInt().coerceIn(0, 255)
            val g = (android.graphics.Color.green(color) * factor).toInt().coerceIn(0, 255)
            val b = (android.graphics.Color.blue(color) * factor).toInt().coerceIn(0, 255)
            return android.graphics.Color.argb(a, r, g, b)
        }
    }

    private var _minHeight: Int? = null

    override fun getItemViewType(position: Int): Int {
        return when (phrases[position]) {
            is PhraseGridItem.Phrase -> R.layout.phrase_button
            PhraseGridItem.AddPhrase -> R.layout.phrase_button_add
        }
    }

    override fun onCreateViewHolder(
        parent: ViewGroup,
        viewType: Int
    ): PhraseAdapter.PhraseViewHolder {
        val itemView =
            LayoutInflater.from(parent.context).inflate(viewType, parent, false)
        itemView.isInvisible = true
        parent.post {
            with(itemView) {
                minimumHeight = getMinHeight(parent)
                isInvisible = false
            }
        }

        return PhraseGridItemViewHolder(itemView)
    }

    override fun onBindViewHolder(holder: PhraseAdapter.PhraseViewHolder, position: Int) {
        holder.bind(position)
    }

    private fun getMinHeight(parent: ViewGroup): Int {
        if (_minHeight == null) {
            val offset =
                parent.context.resources.getDimensionPixelSize(R.dimen.speech_button_margin)
            _minHeight = (parent.measuredHeight / numRows) - ((numRows - 1) * offset / numRows)
        }
        return _minHeight ?: 0
    }

    override fun getItemCount(): Int = phrases.size
}