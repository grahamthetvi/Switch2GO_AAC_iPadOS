package com.switch2go.aac.customviews

import android.content.Context
import android.speech.tts.TextToSpeech
import android.util.AttributeSet
import com.switch2go.aac.utils.Switch2GOTextToSpeech

/**
 * A subclass of Switch2GOButton that allows a caller to define a custom action
 */
open class ActionButton @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyle: Int = 0
) : Switch2GOButton(context, attrs, defStyle) {

    var action: (() -> Unit)? = null

    override fun performAction() {
        action?.invoke()
    }

    override fun sayText(text: CharSequence?) {
        if (text?.isNotBlank() == true) {
            Switch2GOTextToSpeech.speak(locale, text.toString())
        }
    }
}