package com.switch2go.aac.room

import com.switch2go.aac.presets.Phrase
import com.switch2go.aac.utils.locale.LocalesWithText
import kotlinx.coroutines.flow.Flow

interface StoredPhrasesRepository {
    suspend fun addPhrase(phrase: PhraseDto)
    suspend fun updatePhraseLastSpokenTime(phraseId: String)
    fun getRecentPhrasesFlow(): Flow<List<Phrase>>
    fun getPhrasesForCategoryFlow(categoryId: String): Flow<List<Phrase>>
    suspend fun getPhrase(phraseId: String): Phrase?
    suspend fun updatePhrase(phrase: PhraseDto)
    suspend fun updatePhraseLocalizedUtterance(
        phraseId: String,
        localizedUtterance: LocalesWithText,
    )
    suspend fun updatePhraseStyle(phraseId: String, style: PhraseStyle?)
    suspend fun updatePhraseSortOrders(sortOrders: List<PhraseSortOrderUpdate>)
    suspend fun deletePhrase(phraseId: String)
}