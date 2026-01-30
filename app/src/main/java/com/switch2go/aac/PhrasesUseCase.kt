package com.switch2go.aac

import com.switch2go.aac.presets.CustomPhrase
import com.switch2go.aac.presets.ILegacyCategoriesAndPhrasesRepository
import com.switch2go.aac.presets.Phrase
import com.switch2go.aac.presets.PresetCategories
import com.switch2go.aac.presets.PresetPhrase
import com.switch2go.aac.room.PhraseDto
import com.switch2go.aac.room.PhraseSortOrderUpdate
import com.switch2go.aac.room.PhraseStyle
import com.switch2go.aac.room.PresetPhrasesRepository
import com.switch2go.aac.room.StoredPhrasesRepository
import com.switch2go.aac.utils.DateProvider
import com.switch2go.aac.utils.UUIDProvider
import com.switch2go.aac.utils.locale.LocaleProvider
import com.switch2go.aac.utils.locale.LocalesWithText
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first

class PhrasesUseCase(
    private val legacyPhrasesRepository: ILegacyCategoriesAndPhrasesRepository,
    private val storedPhrasesRepository: StoredPhrasesRepository,
    private val presetPhrasesRepository: PresetPhrasesRepository,
    private val dateProvider: DateProvider,
    private val uuidProvider: UUIDProvider,
    private val localeProvider: LocaleProvider
) : IPhrasesUseCase {
    override suspend fun getPhrasesForCategory(categoryId: String): List<Phrase> {
        return getPhrasesForCategoryFlow(categoryId).first()
    }

    override fun getPhrasesForCategoryFlow(categoryId: String): Flow<List<Phrase>> {
        return combine(
            presetPhrasesRepository.getRecentPhrasesFlow(),
            storedPhrasesRepository.getRecentPhrasesFlow(),
            storedPhrasesRepository.getPhrasesForCategoryFlow(categoryId),
            presetPhrasesRepository.getPhrasesForCategoryFlow(categoryId)
        ) { recentPresets, recentStored, stored, presets ->
            if (categoryId == PresetCategories.RECENTS.id) {
                (recentPresets + recentStored)
                    .sortedByDescending { it.lastSpokenDate }
                    .take(8)
            } else {
                stored + presets
            }
        }
    }

    override suspend fun updatePhraseLastSpokenTime(phraseId: String) {
        storedPhrasesRepository.updatePhraseLastSpokenTime(phraseId)
        presetPhrasesRepository.updatePhraseLastSpokenTime(phraseId)
    }

    override suspend fun deletePhrase(phraseId: String) {
        storedPhrasesRepository.deletePhrase(phraseId)
        presetPhrasesRepository.deletePhrase(phraseId)
    }

    override suspend fun updatePhrase(phraseId: String, updatedPhrase: String) {
        val phrase = storedPhrasesRepository.getPhrase(phraseId)
            ?: presetPhrasesRepository.getPhrase(phraseId)
                .takeIf { it != null && !it.deleted }!!
        when (phrase) {
            is CustomPhrase -> {
                val localizedUtterance = (phrase.localizedUtterance ?: LocalesWithText(emptyMap()))
                    .with(localeProvider.getDefaultLocaleString(), updatedPhrase)
                storedPhrasesRepository.updatePhraseLocalizedUtterance(
                    phraseId = phraseId,
                    localizedUtterance = localizedUtterance,
                )
            }

            is PresetPhrase -> {
                presetPhrasesRepository.deletePhrase(phraseId = phraseId)
                // add a custom phrase to "shadow" over the preset
                storedPhrasesRepository.addPhrase(
                    PhraseDto(
                        phraseId = phrase.phraseId,
                        parentCategoryId = phrase.parentCategoryId,
                        creationDate = dateProvider.currentTimeMillis(),
                        lastSpokenDate = phrase.lastSpokenDate,
                        localizedUtterance = LocalesWithText(mapOf(localeProvider.getDefaultLocaleString() to updatedPhrase)),
                        sortOrder = phrase.sortOrder
                    )
                )

            }

            null -> throw IllegalArgumentException("Phrase with id $phraseId not found")
        }
    }

    override suspend fun addPhrase(localizedUtterance: LocalesWithText, parentCategoryId: String) {
        if (parentCategoryId != PresetCategories.RECENTS.id) {
            storedPhrasesRepository.addPhrase(
                PhraseDto(
                    phraseId = uuidProvider.randomUUIDString(),
                    parentCategoryId = parentCategoryId,
                    creationDate = dateProvider.currentTimeMillis(),
                    lastSpokenDate = null,
                    localizedUtterance = localizedUtterance,
                    sortOrder = legacyPhrasesRepository.getPhrasesForCategory(parentCategoryId).size
                )
            )
        } else {
            throw Exception(
                "The 'Recents' category is not a true category -" +
                        " it is a filter applied to true categories. Therefore, saving phrases from " +
                        "the Recents 'category' is not supported."
            )
        }
    }
    
    override suspend fun updatePhraseStyle(phraseId: String, style: PhraseStyle?) {
        // Try stored phrases first, then preset phrases
        val storedPhrase = storedPhrasesRepository.getPhrase(phraseId)
        if (storedPhrase != null) {
            storedPhrasesRepository.updatePhraseStyle(phraseId, style)
        } else {
            presetPhrasesRepository.updatePhraseStyle(phraseId, style)
        }
    }
    
    override suspend fun movePhraseUp(categoryId: String, phraseId: String) {
        val phrases = getPhrasesForCategory(categoryId).sortedBy { it.sortOrder }
        val index = phrases.indexOfFirst { it.phraseId == phraseId }
        
        if (index > 0) {
            val currentPhrase = phrases[index]
            val previousPhrase = phrases[index - 1]
            
            val updates = listOf(
                PhraseSortOrderUpdate(currentPhrase.phraseId, previousPhrase.sortOrder),
                PhraseSortOrderUpdate(previousPhrase.phraseId, currentPhrase.sortOrder)
            )
            
            updateSortOrders(updates, phrases)
        }
    }
    
    override suspend fun movePhraseDown(categoryId: String, phraseId: String) {
        val phrases = getPhrasesForCategory(categoryId).sortedBy { it.sortOrder }
        val index = phrases.indexOfFirst { it.phraseId == phraseId }
        
        if (index >= 0 && index < phrases.size - 1) {
            val currentPhrase = phrases[index]
            val nextPhrase = phrases[index + 1]
            
            val updates = listOf(
                PhraseSortOrderUpdate(currentPhrase.phraseId, nextPhrase.sortOrder),
                PhraseSortOrderUpdate(nextPhrase.phraseId, currentPhrase.sortOrder)
            )
            
            updateSortOrders(updates, phrases)
        }
    }
    
    override suspend fun movePhraseToPosition(categoryId: String, phraseId: String, newPosition: Int) {
        val phrases = getPhrasesForCategory(categoryId).sortedBy { it.sortOrder }.toMutableList()
        val currentIndex = phrases.indexOfFirst { it.phraseId == phraseId }
        
        if (currentIndex < 0 || newPosition < 0 || newPosition >= phrases.size || currentIndex == newPosition) {
            return
        }
        
        // Remove and reinsert at new position
        val phrase = phrases.removeAt(currentIndex)
        phrases.add(newPosition, phrase)
        
        // Update all sort orders
        val updates = phrases.mapIndexed { index, p ->
            PhraseSortOrderUpdate(p.phraseId, index)
        }
        
        updateSortOrders(updates, phrases)
    }
    
    private suspend fun updateSortOrders(updates: List<PhraseSortOrderUpdate>, phrases: List<Phrase>) {
        // Separate updates for stored vs preset phrases
        val storedUpdates = mutableListOf<PhraseSortOrderUpdate>()
        val presetUpdates = mutableListOf<PhraseSortOrderUpdate>()
        
        updates.forEach { update ->
            val phrase = phrases.find { it.phraseId == update.phraseId }
            when (phrase) {
                is CustomPhrase -> storedUpdates.add(update)
                is PresetPhrase -> presetUpdates.add(update)
                null -> {} // Ignore
            }
        }
        
        if (storedUpdates.isNotEmpty()) {
            storedPhrasesRepository.updatePhraseSortOrders(storedUpdates)
        }
        if (presetUpdates.isNotEmpty()) {
            presetPhrasesRepository.updatePhraseSortOrders(presetUpdates)
        }
    }
}