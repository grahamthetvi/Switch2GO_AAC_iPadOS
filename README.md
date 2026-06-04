# Switch2Go - Accessible AAC for CVI

![Platform Android](https://img.shields.io/badge/Platform-Android-blue.svg)
![Platform iOS](https://img.shields.io/badge/Platform-iOS-lightgrey.svg)
![Platform Web](https://img.shields.io/badge/Platform-Web-green.svg)
![Kotlin Multiplatform](https://img.shields.io/badge/Kotlin-Multiplatform-purple.svg)
![license MIT](https://img.shields.io/badge/license-MIT-brightgreen.svg)

> An accessible AAC application designed to support students with Cerebral Visual Impairment (CVI)
>
> **Available on Android, iOS, and Web.** The core AAC experience (categories, phrases, customization, eye gaze / head tracking, dwell selection) is at parity across mobile; the web app is in [`web/`](web/) and deploys to GitHub Pages. Some auxiliary features differ between platforms — see "Platform differences" below.

### Platform differences

| Area | Android | iOS |
|---|---|---|
| Persistence | Room (`com.switch2connect.aac.room.VocableDatabase`) | SQLDelight via `:shared` (`com.vocable.data.createDatabase`) |
| Eye gaze | `MediaPipeIrisGazeTracker` (production) | KMP `GazeTracker` via `GazeTrackingManager.swift` |
| Head tracking | ARCore + Sceneform (`FaceTrackFragment`) | MediaPipe `HeadPoseTracker.swift` |
| BLE switch (ESP32) | not implemented today | `SwitchControlManager.swift` + `ESP32/Switch2GO_BLE_Switch/` |
| Web | IndexedDB (Dexie) | SQLDelight via `:shared` |
| Web input | Keyboard 1–4, touch, MediaPipe gaze/head | Same + BLE HID switch (ESP32) on iOS |

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

### Switch Control (ESP32 Bluetooth HID)
Physical switches connect to an **ESP32** running the BLE keyboard firmware in [`ESP32/Switch2GO_BLE_Switch/`](ESP32/Switch2GO_BLE_Switch/). The board advertises as `Switch2GO-XXXX` and sends keys `1`–`4` (configurable in the sketch). The iPad app treats it as a standard Bluetooth keyboard.

**App setup:** Settings → Selection Mode → Switch Control → enable External Switches. Two modes:

- **Switch to Phrase** (2–4 switches): each switch activates one phrase tile (keys `1`–`4` by default).
- **Scan & Select** (2 switches): one switch moves a highlight, one selects (keys `1` = select, `2` = next).

**BOOT button:** On the ESP32, multi-tap the built-in BOOT button (1–4 taps within 350 ms) to simulate switch 1–4 when testing without wired switches.

#### Arduino IDE setup (ESP32 firmware)

Use [Arduino IDE 2.x](https://www.arduino.cc/en/software) on a Mac or PC. The sketch targets a standard **ESP32-WROOM** board (e.g. DevKitC / DevKit V1). It does **not** run on ESP32-S2 or ESP32-P4 (no BLE keyboard support in HijelHID for those chips).

**1. Install the ESP32 board package**

1. **File → Preferences** → Additional boards manager URLs, add if missing:
   ```
   https://espressif.github.io/arduino-esp32/package_esp32_index.json
   ```
2. **Tools → Board → Boards Manager** → search **esp32** → install **esp32** by Espressif (use **3.3.7 or newer**; HijelHID requires ESP32 Arduino Core 3.x).
3. **Tools → Board** → choose **ESP32 Dev Module** (or your exact DevKit; WROOM-32 is the default for this project).

**2. Install libraries (order matters)**

| Library | How to install | Version |
|---------|----------------|---------|
| **NimBLE-Arduino** | **Sketch → Include Library → Manage Libraries** → search `NimBLE-Arduino` | **≥ 2.3.8** |
| **HijelHID** | Same Library Manager → search `HijelHID` (package name for [HijelHID_BLEKeyboard](https://github.com/HijelHub/HijelHID_BLEKeyboard)) | latest |

If **HijelHID** does not appear in Library Manager:

1. Download [HijelHID_BLEKeyboard.zip](https://github.com/HijelHub/HijelHID_BLEKeyboard/releases/latest/download/HijelHID_BLEKeyboard.zip) from GitHub.
2. **Sketch → Include Library → Add .ZIP Library** → select the zip.

**3. Open and configure the sketch**

1. Open `ESP32/Switch2GO_BLE_Switch/Switch2GO_BLE_Switch.ino` in Arduino IDE (the parent folder name must match the `.ino` filename).
2. Optional edits at the top of the file:
   - `NUM_SWITCHES` — set to `2`, `3`, or `4` if you wire fewer physical switches.
   - `SWITCH_PINS[]` — default `{12, 13, 14, 27}` for DevKit V1.
   - `SWITCH_KEYS[]` — default `'1'`–`'4'`; must match Switch Control key mapping in the iPad app.

**4. Upload settings**

| Setting | Value |
|---------|--------|
| **Board** | ESP32 Dev Module (or your DevKit) |
| **Upload Speed** | 921600 (or 115200 if upload fails) |
| **Port** | USB serial port for the ESP32 (e.g. `/dev/cu.usbserial-*` on Mac) |

Plug in the ESP32 via USB, select the port under **Tools → Port**, then **Sketch → Upload**. If upload fails, hold **BOOT**, press **RESET**, release **RESET**, then release **BOOT** and upload again.

**5. Verify with Serial Monitor**

1. **Tools → Serial Monitor** → baud **115200**.
2. After reset you should see:
   - `[SYSTEM] Initializing Switch2GO Firmware...`
   - `[BLE] Broadcaster Identity: Switch2GO-XXXX`
   - `[SYSTEM] Setup complete...`
3. Press a wired switch (or use BOOT multi-tap): lines like `[HID] Switch 1 PRESSED` appear only when the iPad has connected over BLE (`bleKeyboard->isConnected()`).

**6. Wiring (ESP32 DevKit V1)**

| Switch | GPIO | Connection |
|--------|------|------------|
| 1 | 12 | One leg to GPIO 12, other leg to **GND** |
| 2 | 13 | GPIO 13 ↔ GND |
| 3 | 14 | GPIO 14 ↔ GND |
| 4 | 27 | GPIO 27 ↔ GND |

Uses internal pull-ups: open = HIGH, pressed = LOW. Status LED is GPIO **2** (onboard LED on most DevKits).

**7. Pair with iPad**

1. Power the ESP32 (USB power bank or USB from a computer for flashing only — BLE works on battery/USB after flash).
2. **iPad Settings → Bluetooth** → pair **Switch2GO-XXXX** (last four hex digits of the MAC).
3. Open Switch2GO → **Settings → Selection Mode → Switch Control** → enable **External Switches** → press a switch and confirm “Receiving input”.

Do not pair from inside the Switch2GO app; iOS requires system Bluetooth pairing for HID keyboards.

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

### Web (GitHub Pages)

The browser app lives in [`web/`](web/). It mirrors the iOS AAC flow: preset categories/phrases, CVI layout (1–4 symbols per page), TTS, touch and keyboard switches (keys 1–4), dwell selection, and MediaPipe eye gaze / head tracking (no calibration step — ready to use like iOS).

```bash
cd web
npm install
# MediaPipe model (~3.6MB) for local eye/head tracking:
mkdir -p public/models
curl -fsSL "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task" \
  -o public/models/face_landmarker.task
npm run dev          # local dev (Vite base path matches GitHub Pages)
npm run build        # output in web/dist
```

Deployed URL (after enabling **GitHub Pages → GitHub Actions** in repo settings):  
`https://grahamthetvi.github.io/Switch2GO_AAC_iPadOS/`

**Backup:** Settings → Backup & Restore exports categories, phrases, images, and settings as JSON (device-only). Import replaces local data.

**CI:** Pull requests run `npm run build` in `web/` via `.github/workflows/web.yml`. Pages deploy downloads the face model before build.

**iPad Safari QA:** See Settings → Troubleshooting → iPad Safari checklist (eye gaze, head tracking, dwell, camera denied → touch fallback).

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
Switch2Go is based on Vocable AAC for Android, originally developed by:
- Matt Kubota, Kyle Ohanian, Duncan Lewis, Ameir Al-Zoubi, and many more from [WillowTree LLC](https://www.vocable.app/) 💙

We are grateful to the original Vocable team for creating this excellent foundation for accessible communication.

## License
Switch2Go is released under the MIT license. See [LICENSE](LICENSE) for details.

Third-party components (including **MediaPipe**, Apache 2.0) are documented in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). In-app: **Settings → Open-Source Licenses**.

## Original Project
This project is a fork of [Vocable AAC for Android](https://github.com/grahamthetvi/Switch2GO_AAC_iPadOS), originally developed by WillowTree, LLC.
