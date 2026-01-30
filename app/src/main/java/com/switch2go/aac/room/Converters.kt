package com.switch2go.aac.room

import androidx.room.TypeConverter
import com.squareup.moshi.JsonAdapter
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import com.switch2go.aac.utils.locale.LocaleString
import com.switch2go.aac.utils.locale.LocalesWithText
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

object Converters : KoinComponent {

    private val moshi: Moshi by inject()
    
    // PhraseStyle adapter for JSON serialization
    private val phraseStyleAdapter: JsonAdapter<PhraseStyle> by lazy {
        moshi.adapter(PhraseStyle::class.java)
    }

    @TypeConverter
    @JvmStatic
    fun stringMapToJson(stringMap: Map<String, String>?): String {
        val type = Types.newParameterizedType(Map::class.java, String::class.java, String::class.java)
        val adapter: JsonAdapter<Map<String, String>> = moshi.adapter(type)
        return adapter.toJson(stringMap)
    }

    @TypeConverter
    @JvmStatic
    fun jsonToStringMap(json: String?): Map<String, String>? {
        return json?.let {
            val type = Types.newParameterizedType(Map::class.java, String::class.java, String::class.java)
            val adapter: JsonAdapter<Map<String, String>> = moshi.adapter(type)
            adapter.fromJson(it)
        }
    }

    @TypeConverter
    @JvmStatic
    fun stringMapToLanguagesWithText(localesWithText: LocalesWithText?): String {
        val type = Types.newParameterizedType(Map::class.java, LocaleString::class.java, String::class.java)
        val adapter: JsonAdapter<Map<LocaleString, String>> = moshi.adapter(type)
        return adapter.toJson(localesWithText?.localesTextMap)
    }

    @TypeConverter
    @JvmStatic
    fun languagesWithTextToStringMap(json: String?): LocalesWithText? {
        return json?.let {
            val type = Types.newParameterizedType(Map::class.java, LocaleString::class.java, String::class.java)
            val adapter: JsonAdapter<Map<LocaleString, String>> = moshi.adapter(type)
            adapter.fromJson(it)?.let { stringMap ->
                LocalesWithText(stringMap)
            }

        }
    }
    
    @TypeConverter
    @JvmStatic
    fun phraseStyleToJson(style: PhraseStyle?): String? {
        return style?.let { phraseStyleAdapter.toJson(it) }
    }
    
    @TypeConverter
    @JvmStatic
    fun jsonToPhraseStyle(json: String?): PhraseStyle? {
        // Handle null, empty, or literal "null" string (from bad migration)
        if (json.isNullOrBlank() || json == "null") {
            return null
        }
        return try {
            phraseStyleAdapter.fromJson(json)
        } catch (e: Exception) {
            // Return null if parsing fails
            null
        }
    }
}