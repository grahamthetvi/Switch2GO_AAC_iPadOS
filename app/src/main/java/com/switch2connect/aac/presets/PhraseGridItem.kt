package com.switch2connect.aac.presets

import android.os.Parcelable
import com.switch2connect.aac.room.PhraseStyle
import kotlinx.parcelize.Parcelize

@Parcelize
sealed class PhraseGridItem : Parcelable {

    @Parcelize
    data class Phrase(
        val phraseId: String,
        val text: String,
        val style: PhraseStyle? = null
    ) : PhraseGridItem()

    @Parcelize
    object AddPhrase : PhraseGridItem()
}
