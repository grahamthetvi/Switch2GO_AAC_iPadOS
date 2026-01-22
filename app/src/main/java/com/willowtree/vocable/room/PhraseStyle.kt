package com.willowtree.vocable.room

import android.os.Parcelable
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
    val borderWidthDp: Float? = null
) : Parcelable {
    
    companion object {
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
    }
    
    /** Returns the effective background color, using default if not set */
    fun effectiveBackgroundColor(): Int = backgroundColor ?: DEFAULT_BACKGROUND_COLOR
    
    /** Returns the effective text color, using default if not set */
    fun effectiveTextColor(): Int = textColor ?: DEFAULT_TEXT_COLOR
    
    /** Returns the effective text size, using default if not set */
    fun effectiveTextSize(): Float = textSizeSp ?: DEFAULT_TEXT_SIZE_SP
    
    /** Returns the effective border width, using default if not set */
    fun effectiveBorderWidth(): Float = borderWidthDp ?: DEFAULT_BORDER_WIDTH_DP
}

