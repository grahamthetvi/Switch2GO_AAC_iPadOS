package com.switch2connect.aac.utils.locale

import android.content.Context
import com.switch2connect.aac.presets.Category
import com.switch2connect.aac.presets.Phrase
import com.switch2connect.aac.utils.ILocalizedResourceUtility

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