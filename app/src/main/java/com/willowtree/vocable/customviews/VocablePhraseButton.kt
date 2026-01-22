package com.willowtree.vocable.customviews

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.util.AttributeSet
import kotlin.math.min

/**
 * A class that allows you to pass a custom action to a VocableButton
 */
class VocablePhraseButton @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyle: Int = 0
) : VocableButton(context, attrs, defStyle) {

    var action: (() -> Unit)? = null
    private var textOutlineColor: Int? = null
    private var textOutlineWidthPx: Float = 0f

    override fun performAction() {
        action?.invoke()
    }

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

    override fun onDraw(canvas: Canvas) {
        val outlineColor = textOutlineColor
        val outlineWidth = textOutlineWidthPx
        if (outlineColor != null && outlineWidth > 0f) {
            val effectiveOutlineWidth = min(outlineWidth, textSize * 0.12f)
            val originalColor = paint.color
            val originalStyle = paint.style
            val originalStrokeWidth = paint.strokeWidth
            val originalStrokeJoin = paint.strokeJoin
            val originalStrokeMiter = paint.strokeMiter

            paint.style = Paint.Style.STROKE
            paint.strokeWidth = effectiveOutlineWidth
            paint.strokeJoin = Paint.Join.ROUND
            paint.strokeMiter = 10f
            paint.color = outlineColor
            super.onDraw(canvas)

            paint.style = originalStyle
            paint.strokeWidth = originalStrokeWidth
            paint.strokeJoin = originalStrokeJoin
            paint.strokeMiter = originalStrokeMiter
            paint.color = originalColor
        }
        super.onDraw(canvas)
    }
}