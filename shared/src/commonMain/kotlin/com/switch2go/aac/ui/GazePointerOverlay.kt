package com.switch2go.aac.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke

/**
 * Gaze pointer overlay that displays where the user is looking on screen.
 *
 * @param gazeX Screen X coordinate in pixels
 * @param gazeY Screen Y coordinate in pixels
 * @param isBlinking Whether the user is currently blinking
 * @param confidence Gaze tracking confidence (0-1)
 * @param pointerColor Color of the gaze pointer
 * @param pointerRadius Base radius of the pointer circle
 */
@Composable
fun GazePointerOverlay(
    gazeX: Float,
    gazeY: Float,
    isBlinking: Boolean = false,
    confidence: Float = 1.0f,
    pointerColor: Color = Color(0xFF00C853), // Green
    pointerRadius: Float = 30f,
    modifier: Modifier = Modifier
) {
    // Animate position smoothly
    val animatedX by animateFloatAsState(
        targetValue = gazeX,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "gazeX"
    )
    val animatedY by animateFloatAsState(
        targetValue = gazeY,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 300f),
        label = "gazeY"
    )

    // Adjust alpha based on confidence and blink state
    val alpha = if (isBlinking) 0.3f else confidence.coerceIn(0.3f, 1.0f)

    Canvas(modifier = modifier.fillMaxSize()) {
        val center = Offset(animatedX, animatedY)

        // Outer ring
        drawCircle(
            color = pointerColor.copy(alpha = alpha * 0.5f),
            radius = pointerRadius * 1.5f,
            center = center,
            style = Stroke(width = 3f)
        )

        // Middle ring
        drawCircle(
            color = pointerColor.copy(alpha = alpha * 0.7f),
            radius = pointerRadius,
            center = center,
            style = Stroke(width = 2f)
        )

        // Inner filled circle
        drawCircle(
            color = pointerColor.copy(alpha = alpha),
            radius = pointerRadius * 0.4f,
            center = center
        )

        // Center dot
        drawCircle(
            color = Color.White.copy(alpha = alpha),
            radius = pointerRadius * 0.15f,
            center = center
        )
    }
}

/**
 * Debug overlay showing gaze tracking state information.
 */
@Composable
fun GazeDebugOverlay(
    gazeX: Float,
    gazeY: Float,
    rawGazeX: Float,
    rawGazeY: Float,
    headYaw: Float,
    headPitch: Float,
    headRoll: Float,
    confidence: Float,
    leftBlink: Boolean,
    rightBlink: Boolean,
    fps: Float = 0f,
    modifier: Modifier = Modifier
) {
    // This would show debug info as text overlay
    // For now, just the visual pointer is sufficient
    // Can be expanded later to show state info
}
