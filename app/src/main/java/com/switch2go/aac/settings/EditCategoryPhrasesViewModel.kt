package com.switch2go.aac.settings

import androidx.lifecycle.LiveData
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.asLiveData
import com.switch2go.aac.IPhrasesUseCase
import com.switch2go.aac.presets.Category
import com.switch2go.aac.presets.Phrase
import com.switch2go.aac.utils.ILocalizedResourceUtility

class EditCategoryPhrasesViewModel(
    savedStateHandle: SavedStateHandle,
    phrasesUseCase: IPhrasesUseCase,
    private val localizedResourceUtility: ILocalizedResourceUtility
) : ViewModel() {

    val categoryPhraseList: LiveData<List<Phrase>> = phrasesUseCase.getPhrasesForCategoryFlow(savedStateHandle.get<Category>("category")!!.categoryId)
        .asLiveData()

    fun getCategoryName(category: Category): String {
        return localizedResourceUtility.getTextFromCategory(category)
    }
}