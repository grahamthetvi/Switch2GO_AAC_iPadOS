package com.switch2go.aac.presets

import android.content.Context
import com.switch2go.aac.room.CategoryDto
import com.switch2go.aac.room.CategoryLocalizedName
import com.switch2go.aac.room.CategorySortOrder
import com.switch2go.aac.room.PhraseDto
import com.switch2go.aac.room.StoredCategoryHidden
import com.switch2go.aac.room.VocableDatabase
import com.switch2go.aac.utils.locale.LocalesWithText
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import org.koin.core.component.KoinComponent

class LegacyCategoriesAndPhrasesRepository(
    val context: Context,
    private val database: VocableDatabase
) : KoinComponent, ILegacyCategoriesAndPhrasesRepository {

    override suspend fun getAllCategories(): List<CategoryDto> {
        return database.categoryDao().getAllCategories()
    }

    override fun getAllCategoriesFlow(): Flow<List<CategoryDto>> {
        return database.categoryDao().getAllCategoriesFlow()
    }

    override suspend fun getPhrasesForCategory(categoryId: String): List<PhraseDto> {
        return database.phraseDao().getPhrasesForCategory(categoryId).first()
    }

    override suspend fun getRecentPhrases(): List<PhraseDto> =
        database.phraseDao().getRecentPhrases().first()

    override suspend fun updateCategorySortOrders(categorySortOrders: List<CategorySortOrder>) {
        database.categoryDao().updateCategorySortOrders(categorySortOrders)
    }

    override suspend fun deletePhrases(phrases: List<PhraseDto>) {
        database.phraseDao().deletePhrases(*phrases.toTypedArray())
    }

    override suspend fun deleteCategory(categoryId: String) {
        database.categoryDao().deleteCategory(categoryId)
    }

    override suspend fun updateCategoryName(categoryId: String, localizedName: LocalesWithText) {
        database.categoryDao().updateCategory(CategoryLocalizedName(categoryId, localizedName))
    }

    override suspend fun updateCategoryHidden(categoryId: String, hidden: Boolean) {
        database.categoryDao().updateCategoryHidden(StoredCategoryHidden(categoryId, hidden))
    }
}
