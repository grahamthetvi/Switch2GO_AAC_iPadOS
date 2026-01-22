package com.willowtree.vocable.utils

import com.willowtree.vocable.customviews.VocablePhraseButton
import com.willowtree.vocable.room.PhraseStyle

object PhraseTextBubble {

    fun apply(textView: VocablePhraseButton, style: PhraseStyle?) {
        if (style?.borderColor == null || style.effectiveBorderWidth() <= 0f) {
            textView.setTextOutline(null, null)
            return
        }
        textView.setTextOutline(style.borderColor, style.effectiveBorderWidth())
    }
}
