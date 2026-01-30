package com.switch2go.aac.utils.locale

import android.content.Context
import com.switch2go.aac.presets.Category
import com.switch2go.aac.presets.Phrase
import com.switch2go.aac.utils.ILocalizedResourceUtility

class LocalizedResourceUtility(
    private val context: Context,
) : ILocalizedResourceUtility {

    override fun getTextFromCategory(category: Category?): String {
        return category?.text(context) ?: ""
    }

    override fun getTextFromPhrase(phrase: Phrase?): String {
        return phrase?.text(context) ?: ""
    }
}