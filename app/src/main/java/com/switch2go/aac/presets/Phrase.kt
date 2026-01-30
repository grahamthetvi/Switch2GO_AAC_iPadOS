package com.switch2go.aac.presets

import android.content.Context
import android.os.Parcelable
import com.switch2go.aac.room.PhraseDto
import com.switch2go.aac.room.PhraseStyle
import com.switch2go.aac.room.PresetPhraseDto
import com.switch2go.aac.utils.locale.LocalesWithText
import com.switch2go.aac.utils.locale.text
import kotlinx.parcelize.Parcelize

sealed interface Phrase : Parcelable {
    val phraseId: String
    val sortOrder: Int
    val lastSpokenDate: Long?
    val style: PhraseStyle?

    fun text(context: Context): String
    
    /** Returns the effective style, using defaults if not set */
    fun effectiveStyle(): PhraseStyle = style ?: PhraseStyle.DEFAULT
}

@Parcelize
data class CustomPhrase(
    override val phraseId: String,
    override val sortOrder: Int,
    val localizedUtterance: LocalesWithText?,
    override val lastSpokenDate: Long?,
    override val style: PhraseStyle? = null,
) : Phrase, Parcelable {

    override fun text(context: Context): String {
        return localizedUtterance?.localizedText?.text() ?: ""
    }
}

@Parcelize
data class PresetPhrase(
    override val phraseId: String,
    override val sortOrder: Int,
    override val lastSpokenDate: Long?,
    val deleted: Boolean,
    val parentCategoryId: String?,
    override val style: PhraseStyle? = null,
) : Phrase {

    override fun text(context: Context): String {
        val utteranceStringRes = context.resources.getIdentifier(
            /* name = */ phraseId,
            /* defType = */ "string",
            /* defPackage = */ context.packageName
        )
        return context.resources.getString(utteranceStringRes)
    }
}

fun PhraseDto.asPhrase(): Phrase =
    CustomPhrase(
        phraseId = phraseId,
        sortOrder = sortOrder,
        localizedUtterance = localizedUtterance,
        lastSpokenDate = lastSpokenDate,
        style = style,
    )

fun PresetPhraseDto.asPhrase(): PresetPhrase =
    PresetPhrase(
        phraseId = phraseId,
        sortOrder = sortOrder,
        lastSpokenDate = lastSpokenDate,
        parentCategoryId = parentCategoryId,
        deleted = deleted,
        style = style,
    )
