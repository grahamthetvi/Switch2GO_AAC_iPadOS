package com.willowtree.vocable

import com.willowtree.vocable.presets.Phrase
import com.willowtree.vocable.room.PhraseStyle
import com.willowtree.vocable.utils.locale.LocalesWithText
import kotlinx.coroutines.flow.Flow

interface IPhrasesUseCase {

    suspend fun getPhrasesForCategory(categoryId: String): List<Phrase>

    fun getPhrasesForCategoryFlow(categoryId: String): Flow<List<Phrase>>

    suspend fun updatePhraseLastSpokenTime(phraseId: String)

    suspend fun deletePhrase(phraseId: String)

    suspend fun updatePhrase(phraseId: String, updatedPhrase: String)

    suspend fun addPhrase(localizedUtterance: LocalesWithText, parentCategoryId: String)
    
    /** Updates the style for a phrase */
    suspend fun updatePhraseStyle(phraseId: String, style: PhraseStyle?)
    
    /** Moves a phrase up in the list (decreases sort order) */
    suspend fun movePhraseUp(categoryId: String, phraseId: String)
    
    /** Moves a phrase down in the list (increases sort order) */
    suspend fun movePhraseDown(categoryId: String, phraseId: String)
    
    /** Moves a phrase to a specific position */
    suspend fun movePhraseToPosition(categoryId: String, phraseId: String, newPosition: Int)
}