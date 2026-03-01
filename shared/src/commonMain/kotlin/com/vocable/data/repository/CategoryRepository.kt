package com.vocable.data.repository

import com.vocable.data.models.CategoryModel
import kotlinx.coroutines.flow.Flow

/**
 * Repository interface for managing categories
 */
interface CategoryRepository {
    /**
     * Get all categories (preset + custom) as a Flow
     */
    fun getAllCategories(): Flow<List<CategoryModel>>
    
    /**
     * Get only visible categories (not hidden) as a Flow
     */
    fun getVisibleCategories(): Flow<List<CategoryModel>>
    
    /**
     * Get a category by ID
     */
    suspend fun getCategoryById(categoryId: String): CategoryModel?
    
    /**
     * Insert or update a custom category
     */
    suspend fun insertCategory(category: CategoryModel.StoredCategory)
    
    /**
     * Update category visibility
     */
    suspend fun updateCategoryHidden(categoryId: String, hidden: Boolean)
    
    /**
     * Update category sort order
     */
    suspend fun updateCategorySortOrder(categoryId: String, sortOrder: Int)
    
    /**
     * Update category name (custom categories only)
     */
    suspend fun updateCategoryName(categoryId: String, name: String)
    
    /**
     * Delete a custom category
     */
    suspend fun deleteCategory(categoryId: String)
    
    /**
     * Get total number of categories
     */
    suspend fun getCategoryCount(): Long
}
