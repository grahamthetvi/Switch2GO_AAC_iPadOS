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
    GENERAL("preset_general", 0),
    BASIC_NEEDS("preset_basic_needs", 1),
    PERSONAL_CARE("preset_personal_care", 2),
    CONVERSATION("preset_conversation", 3),
    ENVIRONMENT("preset_environment", 4),
    USER_KEYPAD("preset_user_keypad", 5),
    RECENTS("preset_recents", 6),
    // MY_SAYINGS is deprecated - custom categories should be used instead
    @Deprecated("Use custom categories instead")
    MY_SAYINGS("preset_user_favorites", 7);
    
    companion object {
        fun fromId(id: String): PresetCategories? = entries.find { it.id == id }
    }
}
