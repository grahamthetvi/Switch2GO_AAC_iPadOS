package com.switch2go.aac.utils

import com.switch2go.aac.presets.Category
import com.switch2go.aac.presets.Phrase

interface ILocalizedResourceUtility {
    fun getTextFromCategory(category: Category?): String
    fun getTextFromPhrase(phrase: Phrase?): String
}