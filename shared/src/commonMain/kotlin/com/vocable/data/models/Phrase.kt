package com.vocable.data.models

import kotlinx.serialization.Serializable

/**
 * Represents a phrase that can be spoken
 */
@Serializable
data class PhraseModel(
    val phraseId: String,
    val parentCategoryId: String?,
    val localizedUtterance: String,
    val sortOrder: Int,
    val creationDate: Long,
    val lastSpokenDate: Long? = null,
    val style: PhraseStyle? = null,
    val isPreset: Boolean = false
)

/**
 * Styling options for a phrase (colors, text size, images, etc.)
 * Matches Android's PhraseStyle implementation
 */
@Serializable
data class PhraseStyle(
    /** Background color as ARGB hex (e.g. 0xFFE53935) */
    val backgroundColor: UInt? = null,
    
    /** Text color as ARGB hex */
    val textColor: UInt? = null,
    
    /** Text size in scaled pixels (sp) */
    val textSizeSp: Float? = null,
    
    /** Whether text should be bold */
    val isBold: Boolean = false,
    
    /** Border color as ARGB hex */
    val borderColor: UInt? = null,
    
    /** Border width in density-independent pixels (dp) */
    val borderWidthDp: Float? = null,
    
    /**
     * Image reference. Can be:
     * - Drawable resource name (e.g. "ic_symbol_happy")
     * - File URI (e.g. "file:///path/to/image.png")
     * - Emoji with prefix (e.g. "emoji:😀")
     * - null for no image
     */
    val imageRef: String? = null,

    /**
     * Media reference for delayed phrase playback. Can be:
     * - File URI (e.g. "file:///path/to/video.mp4") on iOS
     * - Blob prefix (e.g. "media:<uuid>") on Web
     * - null for no media
     */
    val mediaRef: String? = null,

    /** Media type: "video", "audio", or "youtube"; null when no media */
    val mediaType: String? = null,

    /** Game type for delayed phrase games; null when no game */
    val gameType: String? = null
) {
    companion object {
        const val EMOJI_PREFIX = "emoji:"
        const val MEDIA_BLOB_PREFIX = "media:"
        const val MEDIA_YOUTUBE_PREFIX = "youtube:"
        const val MEDIA_TYPE_VIDEO = "video"
        const val MEDIA_TYPE_AUDIO = "audio"
        const val MEDIA_TYPE_YOUTUBE = "youtube"
        const val GAME_TYPE_CURSOR_ROCKET = "cursor_rocket"
        
        // Default values
        const val DEFAULT_TEXT_SIZE_SP = 18f
        const val DEFAULT_BACKGROUND_COLOR: UInt = 0xFF000000u
        const val DEFAULT_TEXT_COLOR: UInt = 0xFF000000u
        const val DEFAULT_BORDER_COLOR: UInt = 0xFFE53935u
        const val DEFAULT_BORDER_WIDTH_DP = 6f
        
        val DEFAULT = PhraseStyle()
        
        /** Predefined color palette (19 colors) */
        val PRESET_COLORS = listOf(
            0xFFE53935u,  // Red
            0xFF1E88E5u,  // Blue
            0xFF43A047u,  // Green
            0xFFFB8C00u,  // Orange
            0xFF8E24AAu,  // Purple
            0xFF00ACC1u,  // Cyan
            0xFFF06292u,  // Pink
            0xFFFFEE58u,  // Yellow
            0xFF78909Cu,  // Grey
            0xFF26A69Au,  // Teal
            0xFF795548u,  // Brown
            0xFFCDDC39u,  // Lime
            0xFF3F51B5u,  // Indigo
            0xFFFFC107u,  // Amber
            0xFF673AB7u,  // Deep Purple
            0xFF000000u,  // Black
            0xFFFFFFFFu,  // White
            0xFFD9D9D9u,  // Light Gray
            0xFF4A4A4Au   // Dark Gray
        )
        
        /** Text size options (7 sizes) */
        val TEXT_SIZE_OPTIONS = listOf(
            12f,  // Small
            16f,  // Medium Small
            18f,  // Medium (default)
            22f,  // Medium Large
            26f,  // Large
            32f,  // Extra Large
            40f   // Huge
        )
        
        /** Border width options (6 options) */
        val BORDER_WIDTH_OPTIONS = listOf(
            0f,   // None
            6f,   // Thin
            10f,  // Medium
            14f,  // Thick
            20f,  // XL
            28f   // XXL
        )
        
        /** Built-in symbol names (14 symbols) */
        val PRESET_IMAGES = listOf(
            "ic_symbol_happy",
            "ic_symbol_sad",
            "ic_symbol_yes",
            "ic_symbol_no",
            "ic_symbol_help",
            "ic_symbol_food",
            "ic_symbol_drink",
            "ic_symbol_pain",
            "ic_symbol_bathroom",
            "ic_symbol_sleep",
            "ic_symbol_love",
            "ic_symbol_home",
            "ic_symbol_person",
            "ic_symbol_question"
        )
        
        fun extractEmoji(ref: String?): String? {
            if (ref.isNullOrBlank()) return null
            return if (ref.startsWith(EMOJI_PREFIX)) ref.removePrefix(EMOJI_PREFIX) else null
        }

        /** Extract an 11-character YouTube video ID from a stored ref or pasted URL. */
        fun extractYouTubeVideoId(ref: String?): String? {
            if (ref.isNullOrBlank()) return null
            val trimmed = ref.trim()
            if (trimmed.startsWith(MEDIA_YOUTUBE_PREFIX)) {
                return trimmed.removePrefix(MEDIA_YOUTUBE_PREFIX).takeIf { it.isNotBlank() }
            }
            val patterns = listOf(
                Regex("(?:youtube\\.com/watch\\?.*[?&]v=|youtube\\.com/embed/|youtube\\.com/shorts/|youtu\\.be/)([\\w-]{11})"),
                Regex("^([\\w-]{11})$")
            )
            for (pattern in patterns) {
                val match = pattern.find(trimmed) ?: continue
                return match.groupValues.getOrNull(1)?.takeIf { it.isNotBlank() }
            }
            return null
        }

        /** Normalize a pasted YouTube URL or ID to `youtube:<videoId>`. */
        fun normalizeYouTubeMediaRef(input: String?): String? {
            val videoId = extractYouTubeVideoId(input) ?: return null
            return "$MEDIA_YOUTUBE_PREFIX$videoId"
        }
    }
    
    /** Returns effective background color (with fallback to default) */
    fun effectiveBackgroundColor(): UInt = backgroundColor ?: DEFAULT_BACKGROUND_COLOR
    
    /** Returns effective text color (with fallback to default) */
    fun effectiveTextColor(): UInt = textColor ?: DEFAULT_TEXT_COLOR
    
    /** Returns effective text size (with fallback to default) */
    fun effectiveTextSize(): Float = textSizeSp ?: DEFAULT_TEXT_SIZE_SP
    
    /** Returns effective border width (with fallback to default) */
    fun effectiveBorderWidth(): Float = borderWidthDp ?: DEFAULT_BORDER_WIDTH_DP
    
    /** Returns effective border color (with fallback to default) */
    fun effectiveBorderColor(): UInt = borderColor ?: DEFAULT_BORDER_COLOR
    
    /** Returns true if this style has an image set */
    fun hasImage(): Boolean = !imageRef.isNullOrBlank()

    /** Returns true if this style has video or audio media attached */
    fun hasMedia(): Boolean = !mediaRef.isNullOrBlank() && !mediaType.isNullOrBlank()

    fun isVideo(): Boolean = hasMedia() && mediaType == MEDIA_TYPE_VIDEO

    fun isAudio(): Boolean = hasMedia() && mediaType == MEDIA_TYPE_AUDIO

    fun isYouTube(): Boolean = hasMedia() && mediaType == MEDIA_TYPE_YOUTUBE

    fun triggersDelayedPlayback(): Boolean = isVideo() || isAudio() || isYouTube()

    fun hasGame(): Boolean = !gameType.isNullOrBlank()

    fun isCursorRocketGame(): Boolean = hasGame() && gameType == GAME_TYPE_CURSOR_ROCKET

    fun triggersDelayedGame(): Boolean = hasGame()
}
