package com.switch2go.aac

import com.switch2go.aac.presets.Category
import com.switch2go.aac.room.CategorySortOrder
import com.switch2go.aac.utils.locale.LocalesWithText
import kotlinx.coroutines.flow.Flow

interface ICategoriesUseCase {
    fun categories(): Flow<List<Category>>
    suspend fun updateCategoryName(categoryId: String, localizedName: LocalesWithText)
    suspend fun addCategory(categoryName: String)
    suspend fun updateCategorySortOrders(categorySortOrders: List<CategorySortOrder>)
    suspend fun getCategoryById(categoryId: String): Category
    suspend fun updateCategoryHidden(categoryId: String, hidden: Boolean)
    suspend fun deleteCategory(categoryId: String)
    suspend fun moveCategoryUp(categoryId: String)
    suspend fun moveCategoryDown(categoryId: String)
}