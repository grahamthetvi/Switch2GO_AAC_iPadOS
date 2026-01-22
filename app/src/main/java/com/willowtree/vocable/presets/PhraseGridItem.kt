package com.willowtree.vocable.presets

import android.os.Parcelable
import com.willowtree.vocable.room.PhraseStyle
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
