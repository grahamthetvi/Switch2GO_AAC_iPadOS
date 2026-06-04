# Build and Run Guide - Switch2Go iOS

## Quick Start (Recommended)

Run the automated build script:

```bash
./build_ios.sh
```

Then open the workspace in Xcode:

```bash
open iosApp/iosApp.xcworkspace
```

Press **Cmd+R** to build and run.

---

## Manual Build Steps

### 1. Prerequisites Check

Ensure you have:
- macOS Sonoma or later
- Xcode 15.0+
- Java 17+ installed
- CocoaPods installed

```bash
# Check Java
java -version
# Should show 17 or higher

# Install CocoaPods if needed
sudo gem install cocoapods
```

### 2. Build Shared Framework

```bash
# Export Java home
export JAVA_HOME=$(/usr/libexec/java_home -v 17)

# Build for simulator (M1/M2 Mac)
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64 --no-daemon

# OR for Intel Mac simulator
./gradlew :shared:linkDebugFrameworkIosX64 --no-daemon

# OR for physical device
./gradlew :shared:linkDebugFrameworkIosArm64 --no-daemon
```

The framework will be built to:
- Simulator (ARM): `shared/build/bin/iosSimulatorArm64/debugFramework/VocableShared.framework`
- Simulator (Intel): `shared/build/bin/iosX64/debugFramework/VocableShared.framework`
- Device: `shared/build/bin/iosArm64/debugFramework/VocableShared.framework`

### 3. Install CocoaPods Dependencies

```bash
cd iosApp
pod install
cd ..
```

This installs:
- MediaPipeTasksVision (face landmark detection)
- MediaPipeTasksCommon (MediaPipe core)

### 4. Verify MediaPipe Model

Check if the model file exists:

```bash
ls -lh iosApp/iosApp/Resources/face_landmarker.task
```

If missing, download it:

```bash
mkdir -p iosApp/iosApp/Resources
curl -L "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task" \
  -o iosApp/iosApp/Resources/face_landmarker.task
```

### 5. Open in Xcode

**Important**: Always open the **workspace**, not the project:

```bash
open iosApp/iosApp.xcworkspace
```

### 6. Configure Code Signing

In Xcode:
1. Select the **iosApp** project in the navigator
2. Select the **iosApp** target
3. Go to **Signing & Capabilities**
4. Set your **Team** (Apple Developer account)
5. Xcode will automatically manage provisioning

### 7. Link Shared Framework (First Time Only)

If the framework isn't linked:

1. Select the project → **iosApp** target → **General** tab
2. Under **Frameworks, Libraries, and Embedded Content**:
   - Click **+**
   - Click **Add Other...** → **Add Files...**
   - Navigate to `shared/build/bin/iosSimulatorArm64/debugFramework/`
   - Select `VocableShared.framework`
   - Set **Embed** to **Embed & Sign**

### 8. Add Swift Files to Xcode (First Time Only)

If Swift files aren't showing in Xcode:

1. Right-click the **iosApp** folder in Xcode
2. Choose **Add Files to "iosApp"...**
3. Select all directories:
   - Data/
   - Utils/
   - ViewModels/
   - Views/ (all subdirectories)
4. Ensure **Copy items if needed** is checked
5. Click **Add**

### 9. Build and Run

Press **Cmd+R** or click the **Run** button.

---

## Troubleshooting

### `:build-logic:compileKotlin` / "Unable to parse script-resolver-environment"

Gradle’s Kotlin DSL cache for `build-logic` can get corrupted after a failed or interrupted build. Clean it and rebuild:

```bash
export JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || echo "$HOME/.jdks/jdk-17"*/Contents/Home)"
./gradlew --stop
rm -rf build-logic/build build-logic/.gradle
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64
```

Then in Xcode: **Product → Clean Build Folder** (Cmd+Shift+K) and build again.

### Gradle fails with only `25.0.1` in the error

Gradle/Kotlin do not support Java 25 yet. Use **Java 17** (the Xcode “Build Kotlin Framework” script enforces this). Install Temurin 17 from [Adoptium](https://adoptium.net/) or `brew install openjdk@17`.

### "No such module 'VocableShared'"

**Solution**: Rebuild the framework
```bash
./gradlew :shared:clean :shared:linkDebugFrameworkIosSimulatorArm64
```

Then in Xcode: **Product → Clean Build Folder** (Cmd+Shift+K)

### "No such module 'MediaPipeTasksVision'"

**Solution**: Reinstall CocoaPods
```bash
cd iosApp
pod deintegrate
pod install
cd ..
```

Then restart Xcode and open the `.xcworkspace` file.

### "Library not loaded: @rpath/VocableShared.framework"

**Solution**: Check framework embedding
1. In Xcode, select target → General
2. Under Frameworks section, ensure VocableShared.framework shows **Embed & Sign**

### Camera doesn't work

**Solution**: Use a physical device
- iOS Simulator doesn't support camera
- Test on actual iPad or iPhone

### Build errors about missing types

**Solution**: Clean and rebuild
```bash
# Clean everything
./gradlew clean
rm -rf iosApp/Pods
rm -rf iosApp/Podfile.lock

# Rebuild
./build_ios.sh
```

### Java not found

**Solution**: Install **Java 17** (not Java 25 — see above)
```bash
# Install via Homebrew
brew install openjdk@17

# Or download from Oracle
open https://www.oracle.com/java/technologies/downloads/
```

---

## Development Tips

### Fast Iteration
- Keep Xcode open
- Rebuild shared framework only when changing Kotlin code
- Swift changes compile instantly

### Debugging
- Use Xcode's visual debugger for UI issues
- Check Console (Cmd+Shift+Y) for log output
- Use breakpoints in Swift code
- Print statements in Kotlin show in console

### Testing on Device
1. Connect iPad via USB or WiFi
2. Select device in Xcode scheme selector
3. Ensure device is trusted (Settings → General → VPN & Device Management)
4. First build may take longer (codesigning)

### Performance Profiling
- Use **Instruments** (Cmd+I) for detailed profiling
- Monitor FPS with Debug → View Debugging → Show FPS
- Check memory with Memory Graph debugger

---

## Project Structure

```
iosApp/
├── iosApp.xcworkspace        ← Open this in Xcode
├── iosApp.xcodeproj
├── Podfile
├── Pods/                      ← CocoaPods dependencies
└── iosApp/
    ├── Switch2GoApp.swift     ← App entry point
    ├── ContentView.swift      ← Main view
    ├── Info.plist            ← App configuration
    ├── Data/                  ← Database layer
    ├── Utils/                 ← Utilities (TTS, Settings, etc.)
    ├── ViewModels/           ← Business logic
    ├── Views/                ← All UI screens
    ├── Tracking/             ← Gaze tracking
    ├── Camera/               ← Camera capture
    ├── MediaPipe/            ← Face landmark detection
    └── Resources/            ← Assets, localizations
```

---

## Next Steps

1. **Done:** Build completes successfully
2. **Done:** App launches in simulator (UI and non-camera flows)
3. **Next:** Test on a **physical iPad** for eye gaze, head tracking, gestures, and switches — see [TESTING_GUIDE.md](../TESTING_GUIDE.md)
4. **Next:** TestFlight beta — see [Documentation/IOS_RELEASE_AND_SIGNING.md](../Documentation/IOS_RELEASE_AND_SIGNING.md)
5. **Next:** App Store submission when ready

---

## Related documentation

| Doc | Purpose |
|-----|---------|
| [README.md](../README.md) | Project overview, ESP32, Web app |
| [TESTING_GUIDE.md](../TESTING_GUIDE.md) | Manual QA checklist |
| [Documentation/IOS_RELEASE_AND_SIGNING.md](../Documentation/IOS_RELEASE_AND_SIGNING.md) | Signing, TestFlight, cloud Mac |
| [README.md](README.md) | Short iOS directory index |

---

## Support

For issues or questions:
- Email: grahamthetvi@icloud.com
- Check logs in Console app (device) or Xcode console
- [TESTING_GUIDE.md](../TESTING_GUIDE.md) for structured test passes
