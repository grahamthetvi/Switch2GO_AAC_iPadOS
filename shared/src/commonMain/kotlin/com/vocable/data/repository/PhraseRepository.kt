package com.vocable.data.repository

import com.vocable.data.models.PhraseModel
import com.vocable.data.models.PhraseStyle
import kotlinx.coroutines.flow.Flow

/**
 * Repository interface for managing phrases
 */
interface PhraseRepository {
    /**
     * Get all phrases as a Flow
     */
    fun getAllPhrases(): Flow<List<PhraseModel>>
    
    /**
     * Get phrases for a specific category as a Flow
     */
    fun getPhrasesForCategory(categoryId: String): Flow<List<PhraseModel>>
    
    /**
     * Get recently spoken phrases as a Flow
     */
    fun getRecentPhrases(limit: Int = 8): Flow<List<PhraseModel>>
    
    /**
     * Get a phrase by ID
     */
    suspend fun getPhraseById(phraseId: String): PhraseModel?
    
    /**
     * Insert or update a phrase
     */
    suspend fun insertPhrase(phrase: PhraseModel)
    
    /**
     * Update phrase text
     */
    suspend fun updatePhraseText(phraseId: String, text: String)
    
    /**
     * Update phrase style
     */
    suspend fun updatePhraseStyle(phraseId: String, style: PhraseStyle?)
    
    /**
     * Update phrase last spoken timestamp
     */
    suspend fun updatePhraseLastSpoken(phraseId: String, timestamp: Long)
    
    /**
     * Update phrase sort order
     */
    suspend fun updatePhraseSortOrder(phraseId: String, sortOrder: Int)
    
    /**
     * Move phrase to different category
     */
    suspend fun updatePhraseCategory(phraseId: String, categoryId: String)
    
    /**
     * Delete a phrase
     */
    suspend fun deletePhrase(phraseId: String)
    
    /**
     * Delete all phrases for a category
     */
    suspend fun deletePhrasesForCategory(categoryId: String)
    
    /**
     * Get total number of phrases
     */
    suspend fun getPhraseCount(): Long
    
    /**
     * Get number of phrases in a category
     */
    suspend fun getPhrasesCountForCategory(categoryId: String): Long
}
