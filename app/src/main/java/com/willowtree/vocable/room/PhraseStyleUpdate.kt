package com.willowtree.vocable.room

import androidx.room.ColumnInfo

/**
 * Partial entity for updating just the style field of a phrase
 */
data class PhraseStyleUpdate(
    @ColumnInfo(name = "phrase_id") val phraseId: String,
    @ColumnInfo(name = "style") val style: PhraseStyle?
)

/**
 * Partial entity for updating just the sort_order field of a phrase
 */
data class PhraseSortOrderUpdate(
    @ColumnInfo(name = "phrase_id") val phraseId: String,
    @ColumnInfo(name = "sort_order") val sortOrder: Int
)

