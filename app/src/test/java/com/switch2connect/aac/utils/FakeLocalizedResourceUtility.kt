package com.switch2connect.aac.utils

import com.switch2connect.aac.presets.Category
import com.switch2connect.aac.presets.CustomPhrase
import com.switch2connect.aac.presets.Phrase
import com.switch2connect.aac.presets.PresetPhrase

class FakeLocalizedResourceUtility : ILocalizedResourceUtility {
    override fun getTextFromCategory(category: Category?): String {
        return when(category) {
            is Category.PresetCategory -> category.categoryId
            is Category.Recents -> "Recents"
            is Category.StoredCategory -> category.localizedName.localesTextMap.entries.first().value
            null -> ""
        }
    }

    override fun getTextFromPhrase(phrase: Phrase?): String {
        return when(phrase) {
            is CustomPhrase -> phrase.localizedUtterance?.localesTextMap?.entries?.first()?.value ?: ""
            is PresetPhrase -> phrase.phraseId
            null -> ""
        }
    }
}