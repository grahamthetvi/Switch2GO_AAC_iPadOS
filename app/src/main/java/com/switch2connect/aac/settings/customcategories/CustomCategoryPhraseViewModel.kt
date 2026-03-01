package com.switch2connect.aac.settings.customcategories

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.switch2connect.aac.IPhrasesUseCase
import com.switch2connect.aac.presets.Phrase
import kotlinx.coroutines.launch

class CustomCategoryPhraseViewModel(
    private val phrasesUseCase: IPhrasesUseCase
) : ViewModel() {
    fun deletePhraseFromCategory(phrase: Phrase) {
        viewModelScope.launch {
            phrasesUseCase.deletePhrase(phrase.phraseId)
        }
    }
}