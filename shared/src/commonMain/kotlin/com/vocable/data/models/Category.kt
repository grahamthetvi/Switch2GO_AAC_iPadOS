package com.vocable.data.models

import kotlinx.serialization.Serializable

/**
 * Represents a category that contains phrases.
 * Can be either a preset category or a user-created category.
 */
@Serializable
sealed class CategoryModel {
    abstract val categoryId: String
    abstract val sortOrder: Int
    abstract val hidden: Boolean
    
    /**
     * User-created custom category
     */
    @Serializable
    data class StoredCategory(
        override val categoryId: String,
        val localizedName: String,
        override val sortOrder: Int,
        override val hidden: Boolean,
        val creationDate: Long
    ) : CategoryModel()
    
    /**
     * Preset category (General, Basic Needs, etc.)
     */
    @Serializable
    data class PresetCategory(
        override val categoryId: String,
        override val sortOrder: Int,
        override val hidden: Boolean,
        val deleted: Boolean = false
    ) : CategoryModel()
    
    /**
     * Special Recents category showing recently spoken phrases
     */
    @Serializable
    data class RecentsCategory(
        override val sortOrder: Int,
        override val hidden: Boolean
    ) : CategoryModel() {
        override val categoryId: String = PresetCategories.RECENTS.id
    }
}

/**
 * Enum of all preset categories in the app
 */
enum class PresetCategories(val id: String, val initialSortOrder: Int) {
    ROUTINE_ACTIVITY("preset_routine_activity", 0),
    FOOD_DRINK("preset_food_drink", 1),
    COMFORT_STATE("preset_comfort_state", 2),
    PLAY_LEISURE("preset_play_leisure", 3),
    POSITIONING("preset_positioning", 4),
    RECENTS("preset_recents", 5);
    
    companion object {
        fun fromId(id: String): PresetCategories? = entries.find { it.id == id }
    }
}
