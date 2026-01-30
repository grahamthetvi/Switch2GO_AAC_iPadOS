package com.switch2go.aac.room

import androidx.room.ColumnInfo
import com.switch2go.aac.utils.locale.LocalesWithText

data class CategoryLocalizedName(
    @ColumnInfo(name = "category_id") val categoryId: String,
    @ColumnInfo(name = "localized_name") var localizedName: LocalesWithText
)