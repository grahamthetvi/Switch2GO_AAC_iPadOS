package com.switch2go.aac.room

import com.switch2go.aac.presets.PresetPhrase
import kotlinx.coroutines.flow.Flow

interface PresetPhrasesRepository {
    suspend fun populateDatabase()
    suspend fun getAllPresetPhrases(): List<PresetPhrase>
    suspend fun updatePhraseLastSpokenTime(phraseId: String)
    suspend fun updatePhraseStyle(phraseId: String, style: PhraseStyle?)
    suspend fun updatePhraseSortOrders(sortOrders: List<PhraseSortOrderUpdate>)
    suspend fun getRecentPhrases() : List<PresetPhrase>
    fun getRecentPhrasesFlow(): Flow<List<PresetPhrase>>
    suspend fun getPhrasesForCategory(categoryId: String): List<PresetPhrase>
    fun getPhrasesForCategoryFlow(categoryId: String): Flow<List<PresetPhrase>>
    suspend fun getPhrase(phraseId: String): PresetPhrase?
    suspend fun deletePhrase(phraseId: String)
}