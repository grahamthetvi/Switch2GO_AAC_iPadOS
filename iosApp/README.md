# Switch2Go iOS App

This directory contains the iOS application for Switch2Go AAC.

## Prerequisites

- macOS with Xcode 15.0+
- CocoaPods (`sudo gem install cocoapods`)
- JDK 17 for building the shared KMP framework

## Setup Instructions

### 1. Create Xcode Project

Since Xcode projects can't be versioned effectively, you need to create the project on your Mac:

1. Open Xcode
2. File > New > Project
3. Choose "iOS" > "App"
4. Configure:
   - Product Name: `iosApp`
   - Team: Your Apple Developer Team
   - Organization Identifier: `com.yourname`
   - Bundle Identifier: `com.yourname.switch2go`
   - Interface: **SwiftUI**
   - Language: **Swift**
5. Save in this `iosApp/` directory
6. Uncheck "Create Git repository"

### 2. Add Swift Files

After creating the project, add all the Swift files from `iosApp/` subdirectories:

1. In Xcode, right-click the `iosApp` folder
2. Choose "Add Files to 'iosApp'..."
3. Select all `.swift` files from:
   - `iosApp/` (main app files)
   - `Views/AAC/`
   - `Views/Calibration/`
   - `Views/Settings/`
   - `Camera/`
   - `Tracking/`
   - `MediaPipe/`

### 3. Install CocoaPods

```bash
cd iosApp
pod install
```

**Important**: After running `pod install`, always open `iosApp.xcworkspace` (not `.xcodeproj`)

### 4. Download MediaPipe Model

```bash
mkdir -p iosApp/Resources
curl -L "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task" \
  -o iosApp/Resources/face_landmarker.task
```

Then add `face_landmarker.task` to your Xcode project.

### 5. Build Shared Framework

```bash
cd ..  # Back to project root
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64
```

### 6. Link Shared Framework

1. In Xcode, select the project
2. Select "iosApp" target > "General"
3. Under "Frameworks, Libraries, and Embedded Content":
   - Click "+"
   - Click "Add Other..." > "Add Files..."
   - Navigate to `shared/build/bin/iosSimulatorArm64/debugFramework/`
   - Select `VocableShared.framework`
   - Set "Embed" to "Embed & Sign"

### 7. Run

1. Select a simulator or connected device
2. Press Cmd+R to build and run

## Project Structure

```
iosApp/
├── Podfile                 # CocoaPods dependencies
├── README.md               # This file
└── iosApp/
    ├── Switch2GoApp.swift  # App entry point
    ├── ContentView.swift   # Main content view
    ├── Info.plist          # App configuration
    ├── Views/
    │   ├── AAC/            # AAC phrase grid views
    │   ├── Calibration/    # Eye tracking calibration
    │   └── Settings/       # App settings
    ├── Camera/             # Camera capture
    ├── Tracking/           # Gaze tracking manager
    ├── MediaPipe/          # Face landmark detection
    └── Resources/          # Model files, assets
```

## Troubleshooting

### "No such module 'VocableShared'"
Rebuild the framework: `./gradlew :shared:linkDebugFrameworkIosSimulatorArm64`

### "No such module 'MediaPipeTasksVision'"
Run `pod install` and open the `.xcworkspace` file.

### Camera not working in Simulator
The iOS Simulator doesn't support camera. Test on a real device.

## Related Documentation

- [iOS Development Guide](../Documentation/IOS_DEVELOPMENT_GUIDE.md) - Complete setup guide
- [KMP Migration Progress](../KMP_MIGRATION_PROGRESS.md) - Shared module status
