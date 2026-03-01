package com.switch2connect.aac.room

import androidx.room.ColumnInfo

data class StoredCategoryHidden(
    @ColumnInfo(name = "category_id") val categoryId: String,
    @ColumnInfo(name = "hidden") val hidden: Boolean
)
