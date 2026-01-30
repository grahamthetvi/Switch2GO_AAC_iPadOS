package com.switch2go.aac.presets

import com.switch2go.aac.room.CategorySortOrder
import kotlinx.coroutines.flow.Flow

interface PresetCategoriesRepository {
    fun getPresetCategories(): Flow<List<Category.PresetCategory>>
    suspend fun updateCategorySortOrders(categorySortOrders: List<CategorySortOrder>)
    suspend fun getCategoryById(categoryId: String): Category.PresetCategory?
    suspend fun updateCategoryHidden(categoryId: String, hidden: Boolean)
    suspend fun deleteCategory(categoryId: String)
}