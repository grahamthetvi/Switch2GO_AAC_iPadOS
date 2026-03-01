package com.switch2connect.aac.room

import androidx.room.ColumnInfo
import com.switch2connect.aac.utils.locale.LocalesWithText

data class PhraseLocalizedUtterance(
    @ColumnInfo(name = "phrase_id") val phraseId: String,
    @ColumnInfo(name = "localized_utterance") var localizedUtterance: LocalesWithText
)
