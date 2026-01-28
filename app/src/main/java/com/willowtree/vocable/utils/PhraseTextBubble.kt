package com.willowtree.vocable.utils

import com.willowtree.vocable.customviews.VocablePhraseButton
import com.willowtree.vocable.room.PhraseStyle

/**
 * Utility object for applying phrase styling (bubble text outline and images) to VocablePhraseButton.
 */
object PhraseTextBubble {

    /**
     * Applies both text outline (bubble effect) and image to a phrase button.
     * @param textView The button to style
     * @param style The style to apply, or null to clear all styling
     */
    fun apply(textView: VocablePhraseButton, style: PhraseStyle?) {
        // Apply text outline (bubble letters)
        if (style?.borderColor == null || style.effectiveBorderWidth() <= 0f) {
            textView.setTextOutline(null, null)
        } else {
            textView.setTextOutline(style.borderColor, style.effectiveBorderWidth())
        }
        
        // Apply image
        if (style == null || !style.hasImage()) {
            textView.clearPhraseImage()
        } else {
            val drawable = style.loadImageDrawable(textView.context)
            if (drawable != null) {
                textView.setPhraseImage(drawable)
            } else {
                // Try loading by resource ID as fallback
                val resId = style.getImageResId(textView.context)
                if (resId != 0) {
                    textView.setPhraseImage(resId)
                } else {
                    textView.clearPhraseImage()
                }
            }
        }
    }
    
    /**
     * Clears all phrase styling from a button.
     */
    fun clear(textView: VocablePhraseButton) {
        textView.setTextOutline(null, null)
        textView.clearPhraseImage()
    }
}
