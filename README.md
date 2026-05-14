# Switch2Go - Accessible AAC for CVI

![Platform Android](https://img.shields.io/badge/Platform-Android-blue.svg)
![Platform iOS](https://img.shields.io/badge/Platform-iOS-lightgrey.svg)
![Kotlin Multiplatform](https://img.shields.io/badge/Kotlin-Multiplatform-purple.svg)
![license MIT](https://img.shields.io/badge/license-MIT-brightgreen.svg)

> An accessible AAC application designed to support students with Cerebral Visual Impairment (CVI)
>
> **Available on both Android and iOS.** The core AAC experience (categories, phrases, customization, eye gaze / head tracking, dwell selection) is at parity; some auxiliary features differ between platforms — see "Platform differences" below.

### Platform differences

| Area | Android | iOS |
|---|---|---|
| Persistence | Room (`com.switch2connect.aac.room.VocableDatabase`) | SQLDelight via `:shared` (`com.vocable.data.createDatabase`) |
| Eye gaze | `MediaPipeIrisGazeTracker` (production) | KMP `GazeTracker` via `GazeTrackingManager.swift` |
| Head tracking | ARCore + Sceneform (`FaceTrackFragment`) | MediaPipe `HeadPoseTracker.swift` |
| USB HID switch (Arduino) | not implemented today | `SwitchControlManager.swift` (Game Controller framework) |

## About Switch2Go

Switch2Go is a fork of [Vocable AAC](https://github.com/grahamthetvi/Switch2GO_AAC_iPadOS), originally developed by WillowTree, LLC. This adaptation has been created by **Addison Graham, Teacher of the Visually Impaired**, to provide specialized support for students with Cerebral Visual Impairment (CVI).

The app has been customized with CVI-friendly features including:
- Simplified, high-contrast symbol layouts
- Customizable symbol colors and sizes
- Reduced visual complexity
- Configurable symbol count per page (2-4 symbols)
- Eye gaze and head tracking support for hands-free operation

## Contents
- [What is Switch2Go?](#what-is-switch2go)
- [Features](#features)
- [Requirements](#requirements)
- [Credits](#credits)
- [License](#license)

## What is Switch2Go?
Switch2Go is an Augmentative and Alternative Communication (AAC) application designed specifically for students with Cerebral Visual Impairment. It allows users to communicate using customizable symbol-based interfaces, with support for head tracking and eye gaze technology for hands-free operation.

## Features

### CVI-Optimized Interface
- **Configurable Symbol Layouts**: Choose from 2-4 symbols per page to reduce visual complexity
- **Customizable Colors**: Set high-contrast colors for each symbol position to improve visibility
- **Adjustable Text Sizes**: Multiple text size options to accommodate different visual needs
- **Simplified Design**: Clean, uncluttered interface designed for CVI users

### Multimodal User Interface
Switch2Go uses ARCore to track the user's head movements and eye gaze technology to understand where the user is looking on the screen. This allows the app to be used completely hands-free: users can look around the screen and make selections by lingering their gaze at a particular element.

For users with more mobility, the app can be operated by touch.

### Saved Phrases
Use a list of common phrases, or create and save your own custom phrases with customizable appearance settings.

### USB Switch Control (Arduino Micro/Tapio)
Use an Arduino Micro (or Leonardo) as a USB HID keyboard. Wire physical switches to the Arduino; when pressed, they send key presses (1, 2, 3, 4) that map directly to phrase tiles. No Bluetooth pairing—just plug in the USB cable. This feature will be further explained in future updates.

**Setup:** Settings → Switch Control → Enable USB Switch Control → Mode: "Direct Switch-to-Phrase". See `ArduinoMicro/Switch2GO_USB_Switch/` for the sketch.

## Getting Started

### Prerequisites (both platforms)

- **JDK 17** (required by Kotlin 2.2 / Gradle / KMP).
  - Recommended install: `brew install openjdk@17`
  - The repo's iOS build scripts auto-discover Java via `/usr/libexec/java_home -v 17`; you can also `source setjava.sh` to set `JAVA_HOME` for the current shell.

### Large Files Not Included in This Repo

The following files exceed GitHub's 100MB limit and are **not** included in the repository. They are restored automatically by running `pod install`:

| File / Directory | Size | How to Restore |
|---|---|---|
| `iosApp/Pods/MediaPipeTasksCommon/frameworks/` | ~315MB total | `cd iosApp && pod install` |
| `iosApp/Pods/MediaPipeTasksVision/frameworks/` | included above | `cd iosApp && pod install` |

MediaPipe frameworks are downloaded from [CocoaPods](https://cocoapods.org) at the versions pinned in `iosApp/Podfile.lock`.

### iOS Setup After Cloning

```bash
# 1. Install CocoaPods if you haven't already
sudo gem install cocoapods

# 2. Install iOS dependencies (downloads MediaPipe frameworks)
cd iosApp
pod install

# 3. Open the workspace (not the .xcodeproj)
open iosApp.xcworkspace
```

Then build and run from Xcode. The Xcode project includes a build phase that runs Gradle to produce the KMP `VocableShared.framework` automatically; if you want to build it ahead of time, run `./build_ios.sh` at the repo root.

The `face_landmarker.task` ML model file (~3.6MB) is downloaded to `iosApp/iosApp/Resources/face_landmarker.task` on first build by `build_ios.sh` and by the iOS CI workflow.

### Android Setup After Cloning

```bash
./gradlew :app:assembleDebug
```

Open the project in Android Studio (or any IDE with Gradle support); no extra steps beyond a working JDK 17 are required.

## Architecture Notes

- **DI**: Koin across both `:app` and `:shared` (no Hilt).
- **Persistence**:
  - Android: Room (`com.switch2connect.aac.room.VocableDatabase`) is canonical. Migrations live in `VocableDatabaseMigrations.kt`; the database does **not** use a blanket `fallbackToDestructiveMigration()`, so future schema bumps without a migration will throw rather than silently wipe user phrases.
  - iOS: SQLDelight via the `:shared` KMP module (`com.vocable.data.createDatabase`). The Room and SQLDelight schemas are intentionally separate today; keep entity/column names consistent if you change either.
- **Gaze tracking on Android**: production tracker is `MediaPipeIrisGazeTracker`. `SharedGazeTrackerAdapter` is an experimental bridge to the KMP `GazeTracker` and is not the production path.
- **Head tracking on Android**: built on Sceneform 1.17.1 (unmaintained); `FaceTrackingManager.checkIsSupportedDevice()` degrades gracefully on devices without ARCore.

## Device Requirements

### Android
- Android OS 8.0 (Oreo) or higher
- Camera for eye/head tracking (optional for touch-only use)
- Minimum 2GB RAM recommended

### iOS
- iOS 15.0 or higher
- iPad (recommended) or iPhone
- Front-facing camera for eye tracking
- Devices without TrueDepth sensor supported (uses standard camera)

**Note**: The app is designed to work on a wide range of devices, not just those with specialized IR sensors. This ensures maximum accessibility for all users.

## Credits

### Switch2Go Development
- **Addison Graham** - Teacher of the Visually Impaired, Fork Maintainer
  - Adapted Vocable AAC for students with Cerebral Visual Impairment (CVI)
  - Customized interface and features for CVI accessibility

### Original Vocable AAC Development
Switch2Go is based on Vocable AAC, originally developed by:
- Matt Kubota, Kyle Ohanian, Duncan Lewis, Ameir Al-Zoubi, and many more from [WillowTree](https://www.vocable.app/) 💙

We are grateful to the original Vocable team for creating this excellent foundation for accessible communication.

## License
Switch2Go is released under the MIT license. See [LICENSE](LICENSE) for details.

## Original Project
This project is a fork of [Vocable AAC for Android](https://github.com/grahamthetvi/Switch2GO_AAC_iPadOS), originally developed by WillowTree, LLC.
