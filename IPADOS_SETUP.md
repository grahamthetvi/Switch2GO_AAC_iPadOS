# iPadOS Setup Guide for Switch2GO AAC

This guide explains how to build and run the iPadOS version of Switch2GO AAC using Compose Multiplatform.

## Prerequisites

- macOS with Xcode 15+ installed
- CocoaPods (`sudo gem install cocoapods`)
- JDK 17+ installed
- Android Studio or IntelliJ IDEA with Kotlin Multiplatform plugin

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    shared/ (KMP)                         │
│  ┌────────────────────────────────────────────────────┐ │
│  │    commonMain/ - Pure Kotlin (Platform Agnostic)   │ │
│  │    • Eye gaze algorithms (IrisGazeCalculator)      │ │
│  │    • Kalman filters (KalmanFilter2D, Adaptive)     │ │
│  │    • Calibration (GazeCalibration)                 │ │
│  │    • Compose UI (GazePointerOverlay, etc.)         │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌─────────────────────┐  ┌─────────────────────────┐   │
│  │   androidMain/      │  │      iosMain/           │   │
│  │   • MediaPipe       │  │   • MediaPipe iOS       │   │
│  │   • Timber          │  │   • NSLog               │   │
│  │   • SharedPrefs     │  │   • NSUserDefaults      │   │
│  └─────────────────────┘  └─────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
         ↓                           ↓
   Android App                  iOS App (iosApp/)
   (app/)                       • SwiftUI entry point
                                • Hosts Compose view
```

## Build Steps

### 1. Generate the iOS Framework

First, build the shared KMP module and generate the CocoaPods spec:

```bash
cd /path/to/Switch2GO_AAC_iPadOS
./gradlew :shared:podspec
./gradlew :shared:generateDummyFramework
```

### 2. Install CocoaPods Dependencies

```bash
cd iosApp
pod install
```

This will install:
- `MediaPipeTasksVision` (0.10.14) - Face landmark detection
- `VocableShared` - KMP shared module framework

### 3. Add the MediaPipe Model File

Copy the `face_landmarker.task` model file to the iOS app bundle:

1. Download from [MediaPipe Models](https://developers.google.com/mediapipe/solutions/vision/face_landmarker#models)
2. Add to `iosApp/iosApp/` directory
3. In Xcode, add to the target's "Copy Bundle Resources" build phase

### 4. Open in Xcode

```bash
cd iosApp
open iosApp.xcworkspace  # Use .xcworkspace, NOT .xcodeproj
```

### 5. Build and Run

1. Select an iPad simulator or connected iPad device
2. Build and run (⌘R)

## Key Files

### iOS Platform Implementations (`shared/src/iosMain/`)

| File | Description |
|------|-------------|
| `platform/Logger.kt` | iOS logging using NSLog |
| `platform/Storage.kt` | Persistent storage using NSUserDefaults |
| `platform/FaceLandmarkDetector.kt` | MediaPipe iOS wrapper for face landmarks |
| `MainViewController.kt` | Compose Multiplatform entry point |

### Shared UI (`shared/src/commonMain/kotlin/com/vocable/ui/`)

| File | Description |
|------|-------------|
| `GazePointerOverlay.kt` | Visual gaze cursor overlay |
| `CalibrationScreen.kt` | 9-point calibration UI |
| `GazeTrackingApp.kt` | Main app scaffold |

### iOS App (`iosApp/`)

| File | Description |
|------|-------------|
| `Podfile` | CocoaPods dependencies |
| `iosApp/iOSApp.swift` | SwiftUI entry point |
| `iosApp/Info.plist` | Camera permissions & app config |

## Calibration

The app uses a 9-point calibration system:

1. Look at each highlighted point on screen
2. Hold gaze for ~2 seconds per point
3. System collects 30 samples per point
4. Polynomial or affine transform is computed
5. Calibration is saved to NSUserDefaults

## Eye Gaze Pipeline

```
Camera Frame (CVPixelBuffer)
    ↓
MediaPipe FaceLandmarker (478 landmarks)
    ↓
IrisGazeCalculator
    ├→ Head pose estimation (yaw/pitch/roll)
    ├→ Iris position calculation
    └→ Blink detection
    ↓
Kalman Filter (smoothing)
    ↓
Calibration Transform
    ↓
Screen Coordinates
```

## Troubleshooting

### "Module 'VocableShared' not found"

Run:
```bash
./gradlew :shared:embedAndSignAppleFrameworkForXcode
```

### CocoaPods issues

```bash
cd iosApp
pod deintegrate
pod install
```

### MediaPipe model not loading

Ensure `face_landmarker.task` is in the app bundle:
1. Check it's in "Copy Bundle Resources" build phase
2. Verify path in `FaceLandmarkDetector.kt` matches

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Kotlin | 2.2.0 | Language |
| Compose Multiplatform | 1.8.0 | Shared UI |
| MediaPipe Tasks Vision | 0.10.14 | Face landmark detection |
| kotlinx-coroutines | 1.10.2 | Async operations |
| Koin | 4.1.0 | Dependency injection |

## Notes

- Targeting iOS 15.0+ (iPadOS)
- iPad-only (TARGETED_DEVICE_FAMILY = 2)
- Requires front-facing camera
- Dark mode UI by default
