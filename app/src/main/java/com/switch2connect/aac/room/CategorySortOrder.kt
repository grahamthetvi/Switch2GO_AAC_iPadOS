package com.switch2connect.aac.room

import androidx.room.ColumnInfo

data class CategorySortOrder(
    @ColumnInfo(name = "category_id") val categoryId: String,
    @ColumnInfo(name = "sort_order") var sortOrder: Int
)
