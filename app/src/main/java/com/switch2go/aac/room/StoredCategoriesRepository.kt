package com.switch2go.aac.room

import com.switch2go.aac.presets.Category
import kotlinx.coroutines.flow.Flow

interface StoredCategoriesRepository {
    fun getAllCategories(): Flow<List<CategoryDto>>
    suspend fun upsertCategory(category: Category.StoredCategory)
    suspend fun updateCategorySortOrders(categorySortOrders: List<CategorySortOrder>)
    suspend fun getCategoryById(categoryId: String): CategoryDto?
    suspend fun updateCategoryHidden(categoryId: String, hidden: Boolean)
    suspend fun deleteCategory(categoryId: String)
}