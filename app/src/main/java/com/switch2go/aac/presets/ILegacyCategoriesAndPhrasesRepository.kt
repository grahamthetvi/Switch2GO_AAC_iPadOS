package com.switch2go.aac.presets

import com.switch2go.aac.room.CategoryDto
import com.switch2go.aac.room.CategorySortOrder
import com.switch2go.aac.room.PhraseDto
import com.switch2go.aac.utils.locale.LocalesWithText
import kotlinx.coroutines.flow.Flow

@Deprecated("This is the old way of accessing categories and phrases. Prefer using" +
        " ICategoriesUseCase and PhrasesUseCase instead.")
interface ILegacyCategoriesAndPhrasesRepository {
    suspend fun getPhrasesForCategory(categoryId: String): List<PhraseDto>

    /**
     * Return all categories, sorted by [CategoryDto.sortOrder]
     */
    fun getAllCategoriesFlow(): Flow<List<CategoryDto>>

    /**
     * Return all categories, sorted by [CategoryDto.sortOrder]
     */
    suspend fun getAllCategories(): List<CategoryDto>
    suspend fun updateCategorySortOrders(categorySortOrders: List<CategorySortOrder>)
    suspend fun updateCategoryName(categoryId: String, localizedName: LocalesWithText)
    suspend fun updateCategoryHidden(categoryId: String, hidden: Boolean)
    suspend fun deleteCategory(categoryId: String)
    suspend fun getRecentPhrases(): List<PhraseDto>
    suspend fun deletePhrases(phrases: List<PhraseDto>)
}