package com.switch2connect.aac.customviews

import android.content.Context
import android.speech.tts.TextToSpeech
import android.util.AttributeSet
import com.switch2connect.aac.utils.VocableTextToSpeech

/**
 * A subclass of VocableButton that allows a caller to define a custom action
 */
open class ActionButton @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyle: Int = 0
) : VocableButton(context, attrs, defStyle) {

    var action: (() -> Unit)? = null

    override fun performAction() {
        action?.invoke()
    }

    override fun sayText(text: CharSequence?) {
        if (text?.isNotBlank() == true) {
            VocableTextToSpeech.speak(locale, text.toString())
        }
    }
}