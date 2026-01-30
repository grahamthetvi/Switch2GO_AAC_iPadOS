package com.switch2go.aac.basetest.utils.presets

import com.switch2go.aac.presets.Category
import com.switch2go.aac.utils.locale.LocalesWithText

fun createStoredCategory(
    categoryId: String,
    localizedName: LocalesWithText = LocalesWithText(mapOf("en_US" to "category")),
    hidden: Boolean = false,
    sortOrder: Int = 0
): Category.StoredCategory = Category.StoredCategory(
    categoryId = categoryId,
    localizedName = localizedName,
    hidden = hidden,
    sortOrder = sortOrder,
)