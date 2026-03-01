# App Review Support Guide — Switch2Go

## What the App Is

Switch2Go is an **AAC (Augmentative and Alternative Communication)** app designed specifically for users with **Cerebral Visual Impairment (CVI)**. It allows non-verbal or communication-impaired users to compose and speak phrases entirely hands-free using:

- Eye gaze tracking (via the front camera + MediaPipe on-device ML)
- Head pose tracking
- Physical switch control (USB HID via Arduino or Raspberry Pi)
- Standard touch input

It is a fork of the open-source **Vocable AAC** app, purpose-built for CVI accessibility needs.

---

## Permission Justifications

### Camera (`NSCameraUsageDescription`)
The camera is the core accessibility input method. MediaPipe processes the front camera feed in real time to track 478 facial landmarks and derive eye gaze direction. This is entirely on-device — no frames are stored, buffered to disk, or transmitted over the network. The app has no network calls involving camera data. This is analogous to FaceID or AssistiveTouch head tracking built into iOS.

### Microphone (`NSMicrophoneUsageDescription`) & Speech Recognition (`NSSpeechRecognitionUsageDescription`)
These are optional secondary input methods. Users may opt into voice input as an alternative to eye gaze. The permissions are requested only when the user enables this mode in Settings.

### Photo Library (`NSPhotoLibraryUsageDescription`)
Users can assign custom images to AAC phrase buttons. This is purely cosmetic/communication-aid customization — read-only access to pick a photo.

### Bluetooth (`NSBluetoothAlwaysUsageDescription`)
Used to connect external tactile switches (physical buttons) that serve as a hands-free selection method alongside eye or head tracking. These are assistive technology peripherals, not general Bluetooth device pairing.

---

## Hardware the Reviewer May Not Have

The reviewer will likely not have the Arduino Micro or Raspberry Pi USB switch hardware. **Switch control is an optional enhancement** — the app is fully functional with touch and eye gaze alone. Suggest the reviewer test with:

1. **Touch input** — standard tap on any AAC button
2. **Eye gaze / head tracking** — enable in Settings → Selection Mode → Gaze or Head Pose, then follow the calibration screen
3. **iOS Switch Control (built-in)** — the app supports Apple's native Switch Control from iOS Accessibility Settings, which the reviewer can test without any external hardware

---

## Suggested Reviewer Walkthrough

1. **Launch the app.** Grant camera permission when prompted. The main AAC grid appears.
2. **Speak a phrase.** Tap any category (e.g., "Greetings"), then tap a phrase button. The TTS engine speaks it aloud via the output bar at the top.
3. **Build a sentence.** Tap multiple phrases to queue them, then tap the output bar to speak the full sentence.
4. **Try hands-free mode.** Go to Settings → Selection Mode → Head Pose (no calibration needed). Tilt your head left/right/up/down to navigate the grid. Dwell (hold gaze/pose) on a button to activate it.
5. **Customize a phrase.** Settings → Edit Phrases → tap any phrase → change text, color, image, or emoji.
6. **CVI display settings.** Settings → Categories Display → change symbols per page, adjust per-slot colors. This is a core differentiator for CVI users.
7. **Keyboard.** Tap the keyboard icon to type a custom phrase; TTS speaks it from the output bar.

---

## Face / Biometric Data Handling

> Switch2Go uses MediaPipe's on-device face landmark detection exclusively to calculate eye gaze direction for hands-free navigation. No facial images, landmark coordinates, or derived biometric data are ever written to disk, included in analytics, sent to a server, or shared with any third party. All processing occurs in memory and is discarded immediately after computing the gaze vector for that frame. The app has no backend, no user accounts, and no network telemetry.

---

## Data Storage Summary

| Data Type | Where Stored | Transmitted? |
|---|---|---|
| Phrases & categories | On-device SQLite | No |
| Phrase styling / prefs | UserDefaults | No |
| Gaze calibration data | UserDefaults | No |
| Camera frames | Never persisted | No |
| Face landmarks | In-memory only | No |

---

## Third-Party SDKs

| SDK | Version | Purpose |
|---|---|---|
| MediaPipe Tasks Vision (Google) | ~0.10.14 | On-device face landmark detection |
| VocableShared.framework | Internal | Kotlin Multiplatform — database & gaze math (first-party) |

---

## Potential Review Flags & Explanations

**`front-facing-camera` required capability**
Intentional. Eye gaze tracking is the primary accessibility input method. Devices without a front camera cannot use the core hands-free feature, so the requirement is warranted.

**GameController framework used for key detection**
The app uses `GCKeyboard` (Apple-provided API) to intercept USB HID keyboard input from external switch hardware. This is the intended use of the API for assistive technology peripherals.

**No background modes**
The app is foreground-only. Camera and TTS only run while the app is active.

---

## Recommended App Review Notes (Copy/Paste)

> Switch2Go is an AAC (Augmentative and Alternative Communication) app for users with Cerebral Visual Impairment. Camera access is required for on-device eye gaze tracking — no camera data is ever stored or transmitted. Physical switch hardware (Arduino/Raspberry Pi) is optional; the app is fully testable via touch or head pose tracking. Please see the step-by-step walkthrough below. We are happy to provide a live demo or screen recording on request.

Include the walkthrough steps listed above directly beneath this paragraph in your submission notes.

---

## App Identity

| Field | Value |
|---|---|
| App Name | Switch2Go |
| Bundle ID | com.switch2go.iosApp |
| Version | 8.0 (Build 8) |
| Minimum iOS | 15.0 |
| Supported Devices | iPhone & iPad |
| Localizations | English, Spanish, French |
