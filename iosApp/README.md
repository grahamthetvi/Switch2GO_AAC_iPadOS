# Switch2Go iOS App

Native iPad/iPhone client in `iosApp/iosApp/` (SwiftUI + MediaPipe + KMP `VocableShared`).

## Quick start

```bash
# From repo root
./build_ios.sh
open iosApp/iosApp.xcworkspace
```

In Xcode: set your **Team** under Signing, choose a device or simulator, **Cmd+R**.

Requires **JDK 17**, **CocoaPods**, and **Xcode 15+**. Deployment target: **iOS 17**.

## Docs

| Guide | Use for |
|-------|---------|
| [BUILD_AND_RUN.md](BUILD_AND_RUN.md) | Full build steps, Gradle/Java fixes, troubleshooting |
| [../README.md](../README.md) | Project overview, ESP32 switches, Web app |
| [../TESTING_GUIDE.md](../TESTING_GUIDE.md) | Manual QA on device |
| [../Documentation/IOS_RELEASE_AND_SIGNING.md](../Documentation/IOS_RELEASE_AND_SIGNING.md) | TestFlight and App Store |

## Notes

- Always open **`iosApp.xcworkspace`**, not `.xcodeproj`.
- Run `pod install` after every clone (`iosApp/Pods/` is not in git).
- Camera-based tracking requires a **physical device** (simulator has no camera).
- The Xcode project is versioned; you do **not** need to create a new Xcode project from scratch.

## Layout

```
iosApp/
├── iosApp.xcworkspace   ← open this
├── Podfile
└── iosApp/
    ├── Switch2GoApp.swift
    ├── Views/           AAC, Settings, Calibration
    ├── Tracking/        Gaze, head pose, switches, gestures
    ├── MediaPipe/
    └── Resources/       face_landmarker.task, localizations
```
