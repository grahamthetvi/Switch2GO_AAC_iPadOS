package com.switch2connect.aac.utils

import com.switch2connect.aac.presets.Category
import com.switch2connect.aac.presets.Phrase

interface ILocalizedResourceUtility {
    fun getTextFromCategory(category: Category?): String
    fun getTextFromPhrase(phrase: Phrase?): String
}