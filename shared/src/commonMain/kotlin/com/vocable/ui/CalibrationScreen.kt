package com.vocable.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Calibration point state during calibration process.
 */
enum class CalibrationPointState {
    PENDING,    // Not yet calibrated
    ACTIVE,     // Currently collecting samples
    COMPLETED   // Calibration complete for this point
}

/**
 * Calibration screen for 9-point eye gaze calibration.
 *
 * @param currentPointIndex Index of the current calibration point (0-8)
 * @param totalPoints Total number of calibration points
 * @param pointStates State of each calibration point
 * @param samplesCollected Number of samples collected for current point
 * @param samplesRequired Number of samples required per point
 * @param screenWidth Screen width in pixels
 * @param screenHeight Screen height in pixels
 * @param instructions Text instructions to display
 */
@Composable
fun CalibrationScreen(
    currentPointIndex: Int,
    totalPoints: Int = 9,
    pointStates: List<CalibrationPointState>,
    samplesCollected: Int,
    samplesRequired: Int,
    screenWidth: Int,
    screenHeight: Int,
    instructions: String = "Look at the highlighted point",
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Draw calibration points
        CalibrationPointsCanvas(
            currentPointIndex = currentPointIndex,
            totalPoints = totalPoints,
            pointStates = pointStates,
            screenWidth = screenWidth,
            screenHeight = screenHeight
        )

        // Instructions text at top
        Text(
            text = instructions,
            color = Color.White,
            fontSize = 20.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 60.dp)
        )

        // Progress indicator at bottom
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 60.dp)
        ) {
            Text(
                text = "Point ${currentPointIndex + 1} of $totalPoints",
                color = Color.White.copy(alpha = 0.8f),
                fontSize = 16.sp
            )
            Spacer(modifier = Modifier.height(8.dp))
            // Progress bar for current point
            LinearProgressBar(
                progress = samplesCollected.toFloat() / samplesRequired,
                modifier = Modifier.width(200.dp)
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "$samplesCollected / $samplesRequired samples",
                color = Color.White.copy(alpha = 0.6f),
                fontSize = 12.sp
            )
        }
    }
}

/**
 * Canvas that draws the calibration points in a 3x3 grid.
 */
@Composable
private fun CalibrationPointsCanvas(
    currentPointIndex: Int,
    totalPoints: Int,
    pointStates: List<CalibrationPointState>,
    screenWidth: Int,
    screenHeight: Int,
    modifier: Modifier = Modifier
) {
    Canvas(modifier = modifier.fillMaxSize()) {
        val margin = 100f
        val cols = 3
        val rows = 3

        val stepX = (screenWidth - 2 * margin) / (cols - 1)
        val stepY = (screenHeight - 2 * margin) / (rows - 1)

        for (i in 0 until totalPoints) {
            val col = i % cols
            val row = i / cols

            val x = margin + col * stepX
            val y = margin + row * stepY

            val state = pointStates.getOrNull(i) ?: CalibrationPointState.PENDING
            val isActive = i == currentPointIndex

            val color = when {
                isActive -> Color(0xFF2196F3) // Blue for active
                state == CalibrationPointState.COMPLETED -> Color(0xFF4CAF50) // Green for completed
                else -> Color.White.copy(alpha = 0.5f) // Dim white for pending
            }

            val radius = if (isActive) 25f else 15f

            // Outer ring for active point
            if (isActive) {
                drawCircle(
                    color = color.copy(alpha = 0.3f),
                    radius = radius * 2f,
                    center = Offset(x, y),
                    style = Stroke(width = 2f)
                )
            }

            // Main point circle
            drawCircle(
                color = color,
                radius = radius,
                center = Offset(x, y)
            )

            // Inner dot
            drawCircle(
                color = Color.White,
                radius = radius * 0.3f,
                center = Offset(x, y)
            )
        }
    }
}

/**
 * Simple linear progress bar.
 */
@Composable
private fun LinearProgressBar(
    progress: Float,
    modifier: Modifier = Modifier
) {
    val animatedProgress by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        animationSpec = tween(durationMillis = 200),
        label = "progress"
    )

    Canvas(modifier = modifier.height(8.dp)) {
        val width = size.width
        val height = size.height

        // Background
        drawRoundRect(
            color = Color.White.copy(alpha = 0.2f),
            size = size
        )

        // Progress
        drawRoundRect(
            color = Color(0xFF2196F3),
            size = size.copy(width = width * animatedProgress)
        )
    }
}

/**
 * Calculate calibration point positions for a given grid size.
 */
fun calculateCalibrationPoints(
    screenWidth: Int,
    screenHeight: Int,
    cols: Int = 3,
    rows: Int = 3,
    margin: Float = 100f
): List<Pair<Int, Int>> {
    val points = mutableListOf<Pair<Int, Int>>()
    val stepX = (screenWidth - 2 * margin) / (cols - 1)
    val stepY = (screenHeight - 2 * margin) / (rows - 1)

    for (row in 0 until rows) {
        for (col in 0 until cols) {
            val x = (margin + col * stepX).toInt()
            val y = (margin + row * stepY).toInt()
            points.add(Pair(x, y))
        }
    }

    return points
}
