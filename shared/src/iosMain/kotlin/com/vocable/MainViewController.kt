package com.vocable

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.ComposeUIViewController
import com.vocable.eyetracking.GazeTracker
import com.vocable.eyetracking.models.EyeSelection
import com.vocable.eyetracking.models.GazeResult
import com.vocable.eyetracking.models.SmoothingMode
import com.vocable.platform.*
import com.vocable.ui.*
import kotlinx.coroutines.*
import platform.UIKit.UIScreen
import platform.UIKit.UIViewController

/**
 * Main entry point for the iOS app using Compose Multiplatform.
 */
fun MainViewController(): UIViewController = ComposeUIViewController {
    VocableApp()
}

/**
 * Main Compose app for iOS.
 */
@Composable
fun VocableApp() {
    val screenBounds = UIScreen.mainScreen.bounds
    val screenWidth = screenBounds.useContents { size.width.toInt() }
    val screenHeight = screenBounds.useContents { size.height.toInt() }

    var currentScreen by remember { mutableStateOf(AppScreen.MAIN) }
    var gazeResult by remember { mutableStateOf<GazeResult?>(null) }
    var screenX by remember { mutableIntStateOf(screenWidth / 2) }
    var screenY by remember { mutableIntStateOf(screenHeight / 2) }
    var isTracking by remember { mutableStateOf(false) }
    var isCalibrated by remember { mutableStateOf(false) }
    var cameraPermissionGranted by remember { mutableStateOf(false) }
    var showPermissionDialog by remember { mutableStateOf(false) }

    // Initialize components
    val storage = remember { createStorage() }
    val logger = remember { createLogger("VocableApp") }
    val faceLandmarkDetector = remember { PlatformFaceLandmarkDetector() }

    val gazeTracker = remember {
        GazeTracker(
            faceLandmarkDetector = faceLandmarkDetector,
            screenWidth = screenWidth,
            screenHeight = screenHeight,
            storage = storage,
            logger = logger
        )
    }

    // Load saved calibration on startup
    LaunchedEffect(Unit) {
        isCalibrated = gazeTracker.loadCalibration()
        logger.info("Calibration loaded: $isCalibrated")
    }

    MaterialTheme(
        colorScheme = darkColorScheme()
    ) {
        when (currentScreen) {
            AppScreen.MAIN -> {
                MainScreen(
                    gazeResult = gazeResult,
                    screenX = screenX,
                    screenY = screenY,
                    isTracking = isTracking,
                    isCalibrated = isCalibrated,
                    cameraPermissionGranted = cameraPermissionGranted,
                    onRequestCameraPermission = {
                        // Camera permission will be requested by the native layer
                        showPermissionDialog = true
                    },
                    onStartTracking = {
                        isTracking = true
                    },
                    onStopTracking = {
                        isTracking = false
                    },
                    onStartCalibration = {
                        currentScreen = AppScreen.CALIBRATION
                    },
                    onOpenSettings = {
                        currentScreen = AppScreen.SETTINGS
                    },
                    screenWidth = screenWidth,
                    screenHeight = screenHeight
                )
            }

            AppScreen.CALIBRATION -> {
                CalibrationFlow(
                    gazeTracker = gazeTracker,
                    screenWidth = screenWidth,
                    screenHeight = screenHeight,
                    onCalibrationComplete = { success ->
                        isCalibrated = success
                        if (success) {
                            gazeTracker.saveCalibration()
                        }
                        currentScreen = AppScreen.MAIN
                    },
                    onCancel = {
                        currentScreen = AppScreen.MAIN
                    }
                )
            }

            AppScreen.SETTINGS -> {
                SettingsScreen(
                    smoothingMode = gazeTracker.smoothingMode.name,
                    eyeSelection = gazeTracker.eyeSelection.name,
                    sensitivityX = gazeTracker.getGazeCalculator().sensitivityX,
                    sensitivityY = gazeTracker.getGazeCalculator().sensitivityY,
                    onSmoothingModeChange = { mode ->
                        gazeTracker.smoothingMode = SmoothingMode.valueOf(mode)
                    },
                    onEyeSelectionChange = { selection ->
                        gazeTracker.eyeSelection = EyeSelection.valueOf(selection)
                    },
                    onSensitivityChange = { x, y ->
                        gazeTracker.getGazeCalculator().sensitivityX = x
                        gazeTracker.getGazeCalculator().sensitivityY = y
                    },
                    onClose = {
                        currentScreen = AppScreen.MAIN
                    }
                )
            }
        }
    }
}

/**
 * Main screen with gaze tracking overlay.
 */
@Composable
fun MainScreen(
    gazeResult: GazeResult?,
    screenX: Int,
    screenY: Int,
    isTracking: Boolean,
    isCalibrated: Boolean,
    cameraPermissionGranted: Boolean,
    onRequestCameraPermission: () -> Unit,
    onStartTracking: () -> Unit,
    onStopTracking: () -> Unit,
    onStartCalibration: () -> Unit,
    onOpenSettings: () -> Unit,
    screenWidth: Int,
    screenHeight: Int
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF121212))
    ) {
        if (!cameraPermissionGranted) {
            // Camera permission required screen
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
                modifier = Modifier.fillMaxSize()
            ) {
                Text(
                    text = "Camera Permission Required",
                    style = MaterialTheme.typography.headlineMedium,
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "This app needs camera access for eye gaze tracking.",
                    color = Color.White.copy(alpha = 0.7f)
                )
                Spacer(modifier = Modifier.height(24.dp))
                Button(onClick = onRequestCameraPermission) {
                    Text("Grant Camera Access")
                }
            }
        } else {
            // Main gaze tracking view
            GazeTrackingApp(
                currentScreen = AppScreen.MAIN,
                gazeResult = gazeResult,
                screenX = screenX,
                screenY = screenY,
                isTracking = isTracking,
                isCalibrated = isCalibrated,
                onStartCalibration = onStartCalibration,
                onOpenSettings = onOpenSettings,
                screenWidth = screenWidth,
                screenHeight = screenHeight
            ) {
                // Main content area - placeholder for AAC grid
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(top = 60.dp),
                    contentAlignment = Alignment.Center
                ) {
                    if (!isTracking) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "Switch2GO AAC",
                                style = MaterialTheme.typography.headlineLarge,
                                color = Color.White
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            if (!isCalibrated) {
                                Text(
                                    text = "Please calibrate to start",
                                    color = Color.White.copy(alpha = 0.7f)
                                )
                                Spacer(modifier = Modifier.height(16.dp))
                                Button(onClick = onStartCalibration) {
                                    Text("Start Calibration")
                                }
                            } else {
                                Button(onClick = onStartTracking) {
                                    Text("Start Tracking")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * Calibration flow screen.
 */
@Composable
fun CalibrationFlow(
    gazeTracker: GazeTracker,
    screenWidth: Int,
    screenHeight: Int,
    onCalibrationComplete: (Boolean) -> Unit,
    onCancel: () -> Unit
) {
    var currentPointIndex by remember { mutableIntStateOf(0) }
    var samplesCollected by remember { mutableIntStateOf(0) }
    val totalPoints = 9
    val samplesRequired = 30
    val pointStates = remember {
        mutableStateListOf<CalibrationPointState>().apply {
            repeat(totalPoints) { add(CalibrationPointState.PENDING) }
        }
    }

    val calibrationPoints = remember {
        calculateCalibrationPoints(screenWidth, screenHeight)
    }

    // Update current point state
    LaunchedEffect(currentPointIndex) {
        if (currentPointIndex < totalPoints) {
            pointStates[currentPointIndex] = CalibrationPointState.ACTIVE
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        CalibrationScreen(
            currentPointIndex = currentPointIndex,
            totalPoints = totalPoints,
            pointStates = pointStates,
            samplesCollected = samplesCollected,
            samplesRequired = samplesRequired,
            screenWidth = screenWidth,
            screenHeight = screenHeight,
            instructions = when {
                currentPointIndex >= totalPoints -> "Calibration Complete!"
                else -> "Look at the highlighted point"
            }
        )

        // Cancel button
        TextButton(
            onClick = onCancel,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(16.dp)
        ) {
            Text("Cancel", color = Color.White)
        }

        // Simulate calibration progress (in real implementation, this would be driven by gaze data)
        LaunchedEffect(currentPointIndex) {
            if (currentPointIndex < totalPoints) {
                // In real implementation, collect gaze samples here
                // For now, auto-advance for demonstration
                delay(2000)
                samplesCollected = samplesRequired
                pointStates[currentPointIndex] = CalibrationPointState.COMPLETED

                if (currentPointIndex < totalPoints - 1) {
                    currentPointIndex++
                    samplesCollected = 0
                } else {
                    // Calibration complete
                    delay(500)
                    onCalibrationComplete(true)
                }
            }
        }
    }
}
