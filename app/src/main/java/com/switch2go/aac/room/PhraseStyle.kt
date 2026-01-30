package com.switch2go.aac.room

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Parcelable
import android.text.TextPaint
import androidx.core.content.ContextCompat
import kotlinx.parcelize.Parcelize

/**
 * Represents styling options for a phrase that can be customized per-phrase.
 * All color values are stored as ARGB integers (e.g., 0xFFE53935).
 * Size values are in scaled pixels (sp).
 */
@Parcelize
data class PhraseStyle(
    /** Background color of the phrase button/bubble */
    val backgroundColor: Int? = null,
    
    /** Text color of the phrase */
    val textColor: Int? = null,
    
    /** Text size in scaled pixels (sp) */
    val textSizeSp: Float? = null,
    
    /** Whether the text should be bold */
    val isBold: Boolean = false,
    
    /** Border/outline color of the bubble */
    val borderColor: Int? = null,
    
    /** Border width in density-independent pixels (dp) */
    val borderWidthDp: Float? = null,
    
    /**
     * Image to display above the text.
     * Can be:
     * - A drawable resource name (e.g., "ic_emoji_smile") for built-in icons
     * - A file URI (e.g., "file:///path/to/image.png") for user images
     * - null for no image
     */
    val imageRef: String? = null
) : Parcelable {
    
    companion object {
        const val EMOJI_PREFIX = "emoji:"

        /** Default style with no customizations (uses system defaults) */
        val DEFAULT = PhraseStyle()
        
        /** Default text size in sp */
        const val DEFAULT_TEXT_SIZE_SP = 18f
        
        /** Default background color (dark gray) */
        const val DEFAULT_BACKGROUND_COLOR = 0xFF3D3D3D.toInt()
        
        /** Default text color (white) */
        const val DEFAULT_TEXT_COLOR = 0xFFFFFFFF.toInt()
        
        /** Default border width in dp */
        const val DEFAULT_BORDER_WIDTH_DP = 0f
        
        /** Predefined colors for easy selection */
        val PRESET_COLORS = listOf(
            0xFFE53935.toInt(),  // Red
            0xFF1E88E5.toInt(),  // Blue
            0xFF43A047.toInt(),  // Green
            0xFFFB8C00.toInt(),  // Orange
            0xFF8E24AA.toInt(),  // Purple
            0xFF00ACC1.toInt(),  // Cyan
            0xFFF06292.toInt(),  // Pink
            0xFFFFEE58.toInt(),  // Yellow
            0xFF78909C.toInt(),  // Grey
            0xFF26A69A.toInt(),  // Teal
            0xFF795548.toInt(),  // Brown
            0xFFCDDC39.toInt(),  // Lime
            0xFF3F51B5.toInt(),  // Indigo
            0xFFFFC107.toInt(),  // Amber
            0xFF673AB7.toInt()   // Deep Purple
        )
        
        /** Text size options */
        val TEXT_SIZE_OPTIONS = listOf(
            12f to "Small",
            16f to "Medium Small",
            18f to "Medium",
            22f to "Medium Large",
            26f to "Large",
            32f to "Extra Large",
            40f to "Huge"
        )
        
        /**
         * Built-in symbol/icon options that can be used for phrases.
         * Maps display name to drawable resource name.
         */
        val PRESET_IMAGES = listOf(
            "None" to null,
            "Happy" to "ic_symbol_happy",
            "Sad" to "ic_symbol_sad",
            "Yes" to "ic_symbol_yes",
            "No" to "ic_symbol_no",
            "Help" to "ic_symbol_help",
            "Food" to "ic_symbol_food",
            "Drink" to "ic_symbol_drink",
            "Pain" to "ic_symbol_pain",
            "Bathroom" to "ic_symbol_bathroom",
            "Sleep" to "ic_symbol_sleep",
            "Love" to "ic_symbol_love",
            "Home" to "ic_symbol_home",
            "Person" to "ic_symbol_person",
            "Question" to "ic_symbol_question"
        )

        fun extractEmoji(ref: String?): String? {
            if (ref.isNullOrBlank()) return null
            return if (ref.startsWith(EMOJI_PREFIX)) ref.removePrefix(EMOJI_PREFIX) else null
        }
    }
    
    /** Returns the effective background color, using default if not set */
    fun effectiveBackgroundColor(): Int = backgroundColor ?: DEFAULT_BACKGROUND_COLOR
    
    /** Returns the effective text color, using default if not set */
    fun effectiveTextColor(): Int = textColor ?: DEFAULT_TEXT_COLOR
    
    /** Returns the effective text size, using default if not set */
    fun effectiveTextSize(): Float = textSizeSp ?: DEFAULT_TEXT_SIZE_SP
    
    /** Returns the effective border width, using default if not set */
    fun effectiveBorderWidth(): Float = borderWidthDp ?: DEFAULT_BORDER_WIDTH_DP
    
    /** Returns true if this style has an image set */
    fun hasImage(): Boolean = !imageRef.isNullOrBlank()
    
    /**
     * Loads and returns the image drawable for this style.
     * @param context The context to use for loading resources
     * @return The drawable, or null if no image is set or loading fails
     */
    fun loadImageDrawable(context: Context): Drawable? {
        val ref = imageRef ?: return null
        if (ref.isBlank()) return null

        extractEmoji(ref)?.let { emoji ->
            return createEmojiDrawable(context, emoji)
        }
        
        return try {
            if (ref.startsWith("file://") || ref.startsWith("content://")) {
                // Load from file/content URI
                val uri = android.net.Uri.parse(ref)
                context.contentResolver.openInputStream(uri)?.use { stream ->
                    val bitmap = BitmapFactory.decodeStream(stream)
                    if (bitmap != null) {
                        BitmapDrawable(context.resources, bitmap)
                    } else {
                        null
                    }
                }
            } else {
                // Load from drawable resource by name
                val resId = context.resources.getIdentifier(ref, "drawable", context.packageName)
                if (resId != 0) {
                    ContextCompat.getDrawable(context, resId)
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            null
        }
    }
    
    /**
     * Returns the drawable resource ID for the image, or 0 if not a resource or not found.
     */
    fun getImageResId(context: Context): Int {
        val ref = imageRef ?: return 0
        if (ref.isBlank() || ref.startsWith(EMOJI_PREFIX) || ref.startsWith("file://") || ref.startsWith("content://")) return 0
        return context.resources.getIdentifier(ref, "drawable", context.packageName)
    }

    private fun createEmojiDrawable(context: Context, emoji: String): Drawable? {
        if (emoji.isBlank()) return null
        val density = context.resources.displayMetrics.density
        val sizePx = (48f * density).toInt().coerceAtLeast(24)
        val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.BLACK
            textSize = 32f * density
            textAlign = Paint.Align.CENTER
        }
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val y = sizePx / 2f - (textPaint.descent() + textPaint.ascent()) / 2f
        canvas.drawText(emoji, sizePx / 2f, y, textPaint)
        return BitmapDrawable(context.resources, bitmap)
    }
}

