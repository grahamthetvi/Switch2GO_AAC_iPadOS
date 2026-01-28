package com.willowtree.vocable.customviews

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.AttributeSet
import android.view.Gravity
import androidx.annotation.DrawableRes
import androidx.core.content.ContextCompat
import kotlin.math.min

/**
 * A class that allows you to pass a custom action to a VocableButton.
 * Supports:
 * - Text outline ("bubble letters") via setTextOutline()
 * - Image above text via setPhraseImage()
 */
class VocablePhraseButton @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyle: Int = 0
) : VocableButton(context, attrs, defStyle) {

    var action: (() -> Unit)? = null
    private var textOutlineColor: Int? = null
    private var textOutlineWidthPx: Float = 0f
    
    // Image above text support
    private var phraseImageDrawable: Drawable? = null
    private var phraseImageResId: Int = 0

    override fun performAction() {
        action?.invoke()
    }

    /**
     * Sets the text outline (bubble letter effect).
     * @param color The outline color (ARGB int), or null to clear
     * @param widthDp The outline width in dp, or null to clear
     */
    fun setTextOutline(color: Int?, widthDp: Float?) {
        if (color == null || widthDp == null || widthDp <= 0f) {
            textOutlineColor = null
            textOutlineWidthPx = 0f
            invalidate()
            return
        }
        textOutlineColor = color
        textOutlineWidthPx = widthDp * resources.displayMetrics.density
        invalidate()
    }

    /**
     * Sets an image to display above the text.
     * @param resId The drawable resource ID, or 0 to clear
     */
    fun setPhraseImage(@DrawableRes resId: Int) {
        phraseImageResId = resId
        phraseImageDrawable = if (resId != 0) {
            ContextCompat.getDrawable(context, resId)
        } else {
            null
        }
        invalidate()
    }

    /**
     * Sets an image to display above the text.
     * @param drawable The drawable to display, or null to clear
     */
    fun setPhraseImage(drawable: Drawable?) {
        phraseImageDrawable = drawable
        phraseImageResId = 0
        invalidate()
    }

    /**
     * Sets an image to display above the text from a Bitmap.
     * @param bitmap The bitmap to display, or null to clear
     */
    fun setPhraseImage(bitmap: Bitmap?) {
        phraseImageDrawable = if (bitmap != null) {
            BitmapDrawable(resources, bitmap)
        } else {
            null
        }
        phraseImageResId = 0
        invalidate()
    }

    /**
     * Returns the current phrase image resource ID, or 0 if none/cleared.
     */
    fun getPhraseImageResId(): Int = phraseImageResId

    /**
     * Clears the phrase image.
     */
    fun clearPhraseImage() {
        phraseImageDrawable = null
        phraseImageResId = 0
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        val outlineColor = textOutlineColor
        val outlineWidth = textOutlineWidthPx
        val hasOutline = outlineColor != null && outlineWidth > 0f
        val drawable = phraseImageDrawable
        val hasImage = drawable != null
        
        if (!hasOutline && !hasImage) {
            // No special drawing needed
            super.onDraw(canvas)
            return
        }

        val textLayout = layout
        if (textLayout == null) {
            super.onDraw(canvas)
            return
        }

        // Calculate dimensions for image positioning
        val imageHeight: Int
        val imageWidth: Int
        val imageTopPadding: Int
        val textAreaTop: Int
        
        if (drawable != null) {
            // Calculate image size - use a portion of the button height
            val availableHeight = height - paddingTop - paddingBottom
            imageHeight = (availableHeight * 0.45f).toInt().coerceAtLeast(24)
            imageWidth = (imageHeight * (drawable.intrinsicWidth.toFloat() / drawable.intrinsicHeight.coerceAtLeast(1))).toInt()
            imageTopPadding = paddingTop + 4
            textAreaTop = imageTopPadding + imageHeight + 4
        } else {
            imageHeight = 0
            imageWidth = 0
            imageTopPadding = 0
            textAreaTop = paddingTop
        }

        val compoundPaddingLeft = compoundPaddingLeft
        val adjustedCompoundPaddingTop = if (hasImage) textAreaTop else compoundPaddingTop
        val compoundPaddingBottom = compoundPaddingBottom

        // Calculate vertical offset based on gravity
        val vspace = height - compoundPaddingBottom - adjustedCompoundPaddingTop
        val voffset = when (gravity and Gravity.VERTICAL_GRAVITY_MASK) {
            Gravity.TOP -> 0
            Gravity.BOTTOM -> vspace - textLayout.height
            else -> (vspace - textLayout.height) / 2  // CENTER
        }

        if (hasOutline) {
            // Save original paint state
            val originalColor = paint.color
            val originalStyle = paint.style
            val originalStrokeWidth = paint.strokeWidth
            val originalStrokeJoin = paint.strokeJoin
            val originalStrokeMiter = paint.strokeMiter

            // Set stroke style for outline
            // Use a reasonable cap that scales with text size
            val effectiveOutlineWidth = min(outlineWidth, textSize * 1.0f)
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = effectiveOutlineWidth
            paint.strokeJoin = Paint.Join.ROUND
            paint.strokeMiter = 10f
            paint.color = outlineColor!!

            canvas.save()
            canvas.translate(
                compoundPaddingLeft.toFloat(),
                (adjustedCompoundPaddingTop + voffset).toFloat()
            )
            textLayout.draw(canvas)
            canvas.restore()

            // Restore paint to fill style
            paint.style = Paint.Style.FILL
            paint.strokeWidth = originalStrokeWidth
            paint.strokeJoin = originalStrokeJoin
            paint.strokeMiter = originalStrokeMiter
            paint.color = originalColor
        }

        // Draw filled text
        paint.style = Paint.Style.FILL
        paint.color = currentTextColor
        canvas.save()
        canvas.translate(
            compoundPaddingLeft.toFloat(),
            (adjustedCompoundPaddingTop + voffset).toFloat()
        )
        textLayout.draw(canvas)
        canvas.restore()

        // Draw the image above text if present
        if (drawable != null && imageWidth > 0 && imageHeight > 0) {
            val imageLeft = (width - imageWidth) / 2
            drawable.setBounds(
                imageLeft,
                imageTopPadding,
                imageLeft + imageWidth,
                imageTopPadding + imageHeight
            )
            drawable.draw(canvas)
        }
    }
}