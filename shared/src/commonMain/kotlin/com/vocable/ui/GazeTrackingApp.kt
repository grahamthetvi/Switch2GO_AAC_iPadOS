package com.vocable.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.vocable.eyetracking.models.GazeResult

/**
 * App state for the gaze tracking application.
 */
enum class AppScreen {
    MAIN,        // Main gaze tracking view
    CALIBRATION, // Calibration in progress
    SETTINGS     // Settings screen
}

/**
 * Main app composable that manages navigation between screens.
 *
 * @param currentScreen Current visible screen
 * @param gazeResult Latest gaze tracking result
 * @param screenX Mapped screen X coordinate
 * @param screenY Mapped screen Y coordinate
 * @param isTracking Whether gaze tracking is active
 * @param isCalibrated Whether calibration is complete
 * @param onStartCalibration Callback to start calibration
 * @param onOpenSettings Callback to open settings
 * @param screenWidth Screen width in pixels
 * @param screenHeight Screen height in pixels
 * @param content Main content to display behind the gaze overlay
 */
@Composable
fun GazeTrackingApp(
    currentScreen: AppScreen,
    gazeResult: GazeResult?,
    screenX: Int,
    screenY: Int,
    isTracking: Boolean,
    isCalibrated: Boolean,
    onStartCalibration: () -> Unit,
    onOpenSettings: () -> Unit,
    screenWidth: Int,
    screenHeight: Int,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit = {}
) {
    Box(modifier = modifier.fillMaxSize()) {
        // Main content area
        content()

        // Gaze pointer overlay (when tracking is active)
        if (isTracking && gazeResult != null) {
            GazePointerOverlay(
                gazeX = screenX.toFloat(),
                gazeY = screenY.toFloat(),
                isBlinking = gazeResult.leftBlink && gazeResult.rightBlink,
                confidence = gazeResult.confidence
            )
        }

        // Status bar at top
        StatusBar(
            isTracking = isTracking,
            isCalibrated = isCalibrated,
            gazeResult = gazeResult,
            onStartCalibration = onStartCalibration,
            onOpenSettings = onOpenSettings,
            modifier = Modifier.align(Alignment.TopCenter)
        )
    }
}

/**
 * Status bar showing tracking state and quick actions.
 */
@Composable
private fun StatusBar(
    isTracking: Boolean,
    isCalibrated: Boolean,
    gazeResult: GazeResult?,
    onStartCalibration: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        color = Color.Black.copy(alpha = 0.7f),
        modifier = modifier.fillMaxWidth()
    ) {
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .statusBarsPadding()
        ) {
            // Tracking status indicator
            Row(verticalAlignment = Alignment.CenterVertically) {
                StatusDot(
                    isActive = isTracking,
                    color = if (isTracking) Color(0xFF4CAF50) else Color.Gray
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = if (isTracking) "Tracking" else "Not Tracking",
                    color = Color.White,
                    style = MaterialTheme.typography.bodyMedium
                )
            }

            // Center info
            if (gazeResult != null && isTracking) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "Confidence: ${(gazeResult.confidence * 100).toInt()}%",
                        color = Color.White.copy(alpha = 0.8f),
                        style = MaterialTheme.typography.bodySmall
                    )
                    if (gazeResult.leftBlink || gazeResult.rightBlink) {
                        Text(
                            text = "Blink detected",
                            color = Color.Yellow,
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }

            // Action buttons
            Row {
                TextButton(onClick = onStartCalibration) {
                    Text(
                        text = if (isCalibrated) "Recalibrate" else "Calibrate",
                        color = if (isCalibrated) Color.White else Color(0xFF2196F3)
                    )
                }
                IconButton(onClick = onOpenSettings) {
                    Text("⚙", color = Color.White)
                }
            }
        }
    }
}

/**
 * Small status indicator dot.
 */
@Composable
private fun StatusDot(
    isActive: Boolean,
    color: Color,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .size(12.dp)
            .background(color = color, shape = MaterialTheme.shapes.small)
    )
}

/**
 * Settings screen for configuring gaze tracking parameters.
 */
@Composable
fun SettingsScreen(
    smoothingMode: String,
    eyeSelection: String,
    sensitivityX: Float,
    sensitivityY: Float,
    onSmoothingModeChange: (String) -> Unit,
    onEyeSelectionChange: (String) -> Unit,
    onSensitivityChange: (Float, Float) -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        color = MaterialTheme.colorScheme.surface,
        modifier = modifier.fillMaxSize()
    ) {
        Column(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxSize()
        ) {
            // Header
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = "Settings",
                    style = MaterialTheme.typography.headlineMedium
                )
                TextButton(onClick = onClose) {
                    Text("Done")
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Smoothing mode
            Text(
                text = "Smoothing Mode",
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(modifier = Modifier.height(8.dp))
            // Would add radio buttons or dropdown here

            Spacer(modifier = Modifier.height(16.dp))

            // Eye selection
            Text(
                text = "Eye Selection",
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(modifier = Modifier.height(8.dp))
            // Would add radio buttons here

            Spacer(modifier = Modifier.height(16.dp))

            // Sensitivity sliders
            Text(
                text = "Sensitivity",
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(modifier = Modifier.height(8.dp))

            Text("Horizontal: ${String.format("%.1f", sensitivityX)}")
            Slider(
                value = sensitivityX,
                onValueChange = { onSensitivityChange(it, sensitivityY) },
                valueRange = 1f..5f
            )

            Text("Vertical: ${String.format("%.1f", sensitivityY)}")
            Slider(
                value = sensitivityY,
                onValueChange = { onSensitivityChange(sensitivityX, it) },
                valueRange = 1f..5f
            )
        }
    }
}
