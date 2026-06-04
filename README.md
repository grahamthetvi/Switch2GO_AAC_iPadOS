# Switch2Go — Accessible AAC for CVI

![Platform iOS](https://img.shields.io/badge/Platform-iOS-lightgrey.svg)
![Platform Web](https://img.shields.io/badge/Platform-Web-green.svg)
![Kotlin Multiplatform](https://img.shields.io/badge/Kotlin-Multiplatform-purple.svg)
![license MIT](https://img.shields.io/badge/license-MIT-brightgreen.svg)

> An accessible AAC application for students with Cerebral Visual Impairment (CVI), adapted by **Addison Graham, Teacher of the Visually Impaired**.

**Actively maintained:** **iPad/iOS** (primary) and **Web** ([`web/`](web/), GitHub Pages).  
**Not actively maintained:** the original **Android** app in [`app/`](app/) remains in the tree from the Vocable fork but is not part of current development priorities.

## Contents

- [About](#about-switch2go)
- [Features](#features)
- [Platform comparison](#platform-comparison)
- [ESP32 switch control (iOS)](#esp32-switch-control-ios-only)
- [Getting started](#getting-started)
- [Architecture](#architecture)
- [Device requirements](#device-requirements)
- [Documentation index](#documentation-index)
- [Credits & license](#credits)

## About Switch2Go

Switch2Go is a fork of [Vocable AAC](https://github.com/willowtreeapps/vocable-android), originally developed by [WillowTree LLC](https://www.vocable.app/). This repo extends that foundation with CVI-focused design:

- High-contrast, simplified layouts
- **1–4 symbols per page** (configurable)
- Per-position colors and phrase styling
- Hands-free use via **eye gaze**, **head tracking**, **arm raise**, or **hand gesture** (where supported)
- **Touch** and **switch** input (iOS: ESP32 BLE keyboard; Web: keyboard keys 1–4)

Neither iOS nor Web requires a 9-point gaze calibration for normal use. Optional calibration UI exists on iOS for advanced tuning.

## Features

### CVI-optimized interface

- Configurable symbol layouts (1–4 per page)
- Custom colors per symbol position
- Phrase styles (colors, borders, emoji, custom images)
- Categories and phrases: presets plus full edit/hide/reorder

### Multimodal input

| Mode | iOS | Web |
|------|-----|-----|
| Touch | Yes | Yes |
| Eye gaze (MediaPipe) | Yes | Yes |
| Head tracking (MediaPipe) | Yes | Yes |
| Arm raise / hand gesture (2-tile) | Yes | Yes |
| Dwell selection | Yes | Yes |
| ESP32 BLE switches | Yes | No (use keyboard 1–4) |
| Scan & select (2-switch) | Yes | Limited (keyboard only) |

### Phrases, media, and games

- Preset and custom phrases with TTS (iOS: system speech; Web: native speech + Piper fallback)
- Optional **video/audio** and **YouTube** attachments on phrases (iOS and Web)
- Optional **games** after phrase selection (e.g. Blocs, cursor rocket) on iOS and Web

### Privacy

No Firebase or analytics SDKs. Student data stays on device (iOS) or in the browser (Web IndexedDB). See [Documentation/legacy/Firebase.md](Documentation/legacy/Firebase.md) for what was removed from the original Vocable Android app.

## Platform comparison

| Area | iOS | Web |
|------|-----|-----|
| **Persistence** | SQLDelight via KMP `:shared` | Dexie / IndexedDB |
| **Eye gaze** | KMP `GazeTracker` + `GazeTrackingManager.swift` | `gazeTracker.ts` (ported from shared) |
| **Head tracking** | MediaPipe `HeadPoseTracker.swift` | MediaPipe pose landmarker |
| **Body gestures** | Arm raise + hand gesture (MediaPipe) | Same |
| **Switches** | ESP32 BLE HID + keyboard | Keyboard **1**–**4** only |
| **Custom QWERTY keyboard** | `KeyboardView.swift` | Text field on add-phrase (no full keyboard UI) |
| **Deploy** | Xcode / TestFlight / App Store | GitHub Pages |

## ESP32 switch control (iOS only)

Physical switches connect to an **ESP32** running BLE keyboard firmware in [`ESP32/Switch2GO_BLE_Switch/`](ESP32/Switch2GO_BLE_Switch/). The board advertises as `Switch2GO-XXXX` and sends keys `1`–`4` (configurable in the sketch). The iPad treats it as a standard Bluetooth keyboard.

**App setup:** Settings → Selection Mode → Switch Control → enable External Switches.

- **Switch to Phrase** (2–4 switches): each switch activates one phrase tile (keys `1`–`4` by default).
- **Scan & Select** (2 switches): one switch selects, one advances (keys `1` = select, `2` = next).

**BOOT button:** Multi-tap BOOT (1–4 taps within 350 ms) to simulate switches when testing without wired inputs.

Pair in **iPad Settings → Bluetooth**, not inside Switch2Go (iOS requires system pairing for HID keyboards).

### Arduino IDE setup (ESP32 firmware)

Use [Arduino IDE 2.x](https://www.arduino.cc/en/software). Target **ESP32-WROOM** (e.g. DevKit V1). **Not** ESP32-S2 or ESP32-P4 (no BLE keyboard in HijelHID for those chips).

**1. ESP32 board package**

1. **File → Preferences** → Additional boards manager URLs:
   ```
   https://espressif.github.io/arduino-esp32/package_esp32_index.json
   ```
2. **Tools → Board → Boards Manager** → install **esp32** by Espressif (**3.3.7+**).
3. **Tools → Board** → **ESP32 Dev Module**.

**2. Libraries**

| Library | Install | Version |
|---------|---------|---------|
| **NimBLE-Arduino** | Library Manager | **≥ 2.3.8** |
| **HijelHID** | Library Manager ([HijelHID_BLEKeyboard](https://github.com/HijelHub/HijelHID_BLEKeyboard)) | latest |

If HijelHID is missing: download [HijelHID_BLEKeyboard.zip](https://github.com/HijelHub/HijelHID_BLEKeyboard/releases/latest/download/HijelHID_BLEKeyboard.zip) → **Add .ZIP Library**.

**3. Sketch**

Open `ESP32/Switch2GO_BLE_Switch/Switch2GO_BLE_Switch.ino`. Optional: `NUM_SWITCHES`, `SWITCH_PINS[]` (default `{12,13,14,27}`), `SWITCH_KEYS[]` (`'1'`–`'4'`).

**4. Upload** — Board: ESP32 Dev Module; Port: USB serial; Upload speed 921600 (or 115200). Hold BOOT + RESET if upload fails.

**5. Serial Monitor (115200)** — Expect `[BLE] Broadcaster Identity: Switch2GO-XXXX`. HID lines appear when the iPad is connected.

**6. Wiring (DevKit V1)** — Switches: GPIO 12, 13, 14, 27 to **GND** (internal pull-ups). LED on GPIO **2**.

## Getting started

### Prerequisites (iOS and KMP)

- **JDK 17** — `brew install openjdk@17` or [Adoptium](https://adoptium.net/)
- Shell: `source setjava.sh` or `/usr/libexec/java_home -v 17` for `JAVA_HOME`
- **Do not use Java 25** with Gradle/Kotlin in this repo

### Large files (iOS MediaPipe)

Not committed (GitHub size limits). Restored by `pod install`:

| Path | Restore |
|------|---------|
| `iosApp/Pods/MediaPipeTasks*/frameworks/` (~315 MB) | `cd iosApp && pod install` |

### iOS

```bash
sudo gem install cocoapods   # if needed
cd iosApp && pod install
open iosApp.xcworkspace      # not .xcodeproj
```

Build and run in Xcode (**Cmd+R**). A build phase runs Gradle for `VocableShared.framework`; optionally prebuild:

```bash
./build_ios.sh
```

Downloads `face_landmarker.task` (~3.6 MB) to `iosApp/iosApp/Resources/` on first run.

**Detailed steps and troubleshooting:** [iosApp/BUILD_AND_RUN.md](iosApp/BUILD_AND_RUN.md)  
**Testing checklist:** [TESTING_GUIDE.md](TESTING_GUIDE.md)  
**Signing / TestFlight:** [Documentation/IOS_RELEASE_AND_SIGNING.md](Documentation/IOS_RELEASE_AND_SIGNING.md)

### Web (GitHub Pages)

```bash
cd web
npm ci
mkdir -p public/models
curl -fsSL "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task" \
  -o public/models/face_landmarker.task
curl -fsSL "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task" \
  -o public/models/pose_landmarker_lite.task
curl -fsSL "https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task" \
  -o public/models/gesture_recognizer.task
npm run dev
npm run build    # output: web/dist
```

**Live site:** https://grahamthetvi.github.io/Switch2GO_AAC_iPadOS/  
**Backup:** Settings → Backup & Restore (JSON export/import).  
**CI:** `.github/workflows/web.yml` (PR build); `.github/workflows/pages.yml` (deploy).  
**iPad Safari:** Settings → Troubleshooting.

**Remaining web work:** [.cursor/plans/web_remaining_work.plan.md](.cursor/plans/web_remaining_work.plan.md)

### Android (legacy, unmaintained)

```bash
./gradlew :app:assembleDebug
```

See [Documentation/legacy/](Documentation/legacy/) for Play Store and ARCore-era notes.

## Architecture

```
shared/          KMP — gaze math, SQLDelight schema, presets (iOS consumes via VocableShared.framework)
iosApp/          SwiftUI app — camera, MediaPipe, settings UI, switch control
web/             React + Vite — Dexie, MediaPipe in browser, GitHub Pages
app/             Legacy Android (Room, ARCore head tracking) — unmaintained
```

- **iOS:** SQLDelight through `:shared`; MediaPipe Tasks Vision for face landmarks; Swift UI in `iosApp/iosApp/`
- **Web:** IndexedDB (Dexie); tracking in `web/src/tracking/` (including `gazeTracker.ts` ported from shared)
- **Shared algorithms:** `shared/src/commonMain/kotlin/com/vocable/`

## Device requirements

### iOS

- **iOS 17.0+** (deployment target in Xcode/Podfile)
- iPad recommended; iPhone supported
- Front camera for gaze/head/gesture modes
- No TrueDepth required (standard camera + MediaPipe)

### Web

- Modern browser; **Safari on iPad** is the primary QA target
- Camera permission for non-touch selection modes
- Microphone not required for TTS

## Documentation index

Contributor docs use a plain, professional tone (no emoji). Cursor applies this when editing `*.md` via [`.cursor/rules/documentation.mdc`](.cursor/rules/documentation.mdc).

| Doc | Purpose |
|-----|---------|
| [iosApp/BUILD_AND_RUN.md](iosApp/BUILD_AND_RUN.md) | Build, run, troubleshoot iOS |
| [iosApp/README.md](iosApp/README.md) | Short pointer into iOS docs |
| [TESTING_GUIDE.md](TESTING_GUIDE.md) | Manual QA for iOS and Web |
| [Documentation/IOS_RELEASE_AND_SIGNING.md](Documentation/IOS_RELEASE_AND_SIGNING.md) | TestFlight, App Store, cloud Mac |
| [Documentation/legacy/](Documentation/legacy/) | Android-era and bootstrap archives |
| [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) | Licenses (MediaPipe, etc.) |

## Credits

### Switch2Go

- **Addison Graham** — TVI, fork maintainer; CVI adaptations and iOS/Web development

### Original Vocable AAC

Matt Kubota, Kyle Ohanian, Duncan Lewis, Ameir Al-Zoubi, and the [WillowTree](https://www.willowtreeapps.com/) team — [Vocable AAC for Android](https://github.com/willowtreeapps/vocable-android).

## License

MIT — see [LICENSE](LICENSE). Third-party notices: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). In-app: **Settings → Open-Source Licenses**.
