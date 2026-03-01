# Switch2Go iOS Development Guide

## Complete Guide for Building the iOS App Using a Virtual Mac

This guide provides step-by-step instructions for building the Switch2Go iOS app using a virtual/cloud Mac environment, specifically designed for developers without physical Mac hardware.

---

## Table of Contents

1. [Virtual Mac Setup](#1-virtual-mac-setup)
2. [Development Environment](#2-development-environment)
3. [Apple Developer Account](#3-apple-developer-account)
4. [Project Structure](#4-project-structure)
5. [Creating the iOS App](#5-creating-the-ios-app)
6. [Implementing iOS Platform Code](#6-implementing-ios-platform-code)
7. [MediaPipe Integration](#7-mediapipe-integration)
8. [Building the Shared Framework](#8-building-the-shared-framework)
9. [SwiftUI Implementation](#9-swiftui-implementation)
10. [Camera & Eye Tracking](#10-camera--eye-tracking)
11. [Testing](#11-testing)
12. [Code Signing & Provisioning](#12-code-signing--provisioning)
13. [CI/CD with GitHub Actions](#13-cicd-with-github-actions)
14. [TestFlight & App Store](#14-testflight--app-store)
15. [Troubleshooting](#15-troubleshooting)

---

## 1. Virtual Mac Setup

### Recommended Cloud Mac Services

| Service | Cost | Best For |
|---------|------|----------|
| **MacStadium** | ~$79/month | Dedicated Mac mini, reliable |
| **MacinCloud** | ~$30/month | Budget-friendly, pay-as-you-go |
| **AWS EC2 Mac** | ~$1.08/hour | CI/CD pipelines, hourly billing |
| **Scaleway Apple Silicon** | ~$0.10/hour | EU-based, Apple M1 |

### Setting Up MacStadium (Recommended)

1. Go to [macstadium.com](https://www.macstadium.com)
2. Sign up for a Mac mini plan (M1/M2 recommended)
3. Wait for provisioning (usually 1-2 hours)
4. Connect via:
   - **Screen Sharing** (built into macOS) - Best for development
   - **SSH** - For command-line operations
   - **Jump Desktop** or **Screens 5** - Third-party remote apps

### Connecting from Windows

**Option A: Microsoft Remote Desktop + VNC**
```
1. Install "Microsoft Remote Desktop" from Microsoft Store
2. In MacStadium dashboard, get your Mac's IP address
3. On the Mac (via web console initially):
   - System Settings > General > Sharing > Screen Sharing > Enable
4. In Remote Desktop, add new PC with the Mac's IP:5900
```

**Option B: Jump Desktop (Recommended)**
```
1. Download Jump Desktop for Windows
2. Add new connection:
   - Host: Your Mac's IP address
   - Protocol: VNC or Fluid (for better performance)
   - Username/Password: From MacStadium dashboard
```

### First-Time Mac Setup

Once connected to your virtual Mac:

```bash
# Update macOS (if needed)
softwareupdate --list
softwareupdate --install --all

# Install Homebrew (package manager)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH (Apple Silicon)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

---

## 2. Development Environment

### Install Required Tools

```bash
# Install Xcode from App Store (or command line)
# Method 1: App Store (recommended - includes simulators)
# Open App Store and search for "Xcode"

# Method 2: Command line (faster, but need to install simulators separately)
xcode-select --install

# Install Xcode Command Line Tools
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept

# Install CocoaPods (for MediaPipe)
sudo gem install cocoapods

# Install JDK 17 (for Gradle/KMP)
brew install openjdk@17
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
echo 'export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Verify installations
java -version      # Should show 17.x.x
xcodebuild -version # Should show Xcode 15.x or 16.x
pod --version      # Should show 1.x.x
```

### Install Git & Clone Repository

```bash
# Git is pre-installed on macOS, but update it
brew install git

# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Clone the repository
cd ~/Developer
git clone https://github.com/grahamthetvi/Switch2GO_AAC_iPadOS.git
cd Switch2GO_AAC_iPadOS
```

### Install Android Studio (Optional, for KMP development)

```bash
# Download from https://developer.android.com/studio
# Or use Homebrew
brew install --cask android-studio

# Open Android Studio and install:
# - Android SDK
# - Kotlin Multiplatform plugin
```

---

## 3. Apple Developer Account

### Why You Need It

- **Free Account**: Can run on your own devices, 7-day certificates
- **Paid Account ($99/year)**: TestFlight, App Store, push notifications

### Setting Up

1. Go to [developer.apple.com](https://developer.apple.com)
2. Sign in with your Apple ID
3. Enroll in Apple Developer Program (for paid features)
4. In Xcode:
   - Preferences > Accounts > Add Apple ID
   - Sign in with your developer account

### Create App Identifier

1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Certificates, Identifiers & Profiles
3. Identifiers > + (Add new)
4. Select "App IDs" > "App"
5. Description: "Switch2Go AAC"
6. Bundle ID: `com.yourname.switch2go` (Explicit)
7. Capabilities:
   - [x] Camera (required for eye tracking)
   - [x] Push Notifications (optional)
8. Register

---

## 4. Project Structure

### Target Directory Structure

After completing this guide, your project will look like:

```
Switch2GO_AAC_iPadOS/
├── app/                          # Android app (existing)
├── shared/                       # KMP shared module
│   └── src/
│       ├── commonMain/           # Shared Kotlin code
│       ├── androidMain/          # Android implementations
│       └── iosMain/              # iOS implementations (NEW)
│           └── kotlin/
│               └── com/vocable/platform/
│                   ├── Logger.kt
│                   ├── Storage.kt
│                   └── FaceLandmarkDetector.kt
├── iosApp/                       # iOS application (NEW)
│   ├── iosApp/
│   │   ├── iosAppApp.swift       # App entry point
│   │   ├── ContentView.swift     # Main view
│   │   ├── Info.plist            # App configuration
│   │   ├── Assets.xcassets/      # Images, icons
│   │   └── Views/                # SwiftUI views
│   │       ├── AAC/
│   │       ├── Calibration/
│   │       ├── Settings/
│   │       └── Components/
│   ├── iosApp.xcodeproj/         # Xcode project
│   └── Podfile                   # CocoaPods dependencies
├── gradle/
├── build.gradle.kts
└── settings.gradle.kts
```

---

## 5. Creating the iOS App

### Step 5.1: Create iosApp Directory

```bash
cd ~/Developer/Switch2GO_AAC_iPadOS
mkdir -p iosApp
cd iosApp
```

### Step 5.2: Create Xcode Project

1. Open Xcode
2. File > New > Project
3. Select "iOS" > "App"
4. Configure:
   - Product Name: `iosApp`
   - Team: Your Apple Developer Team
   - Organization Identifier: `com.yourname`
   - Bundle Identifier: `com.yourname.switch2go`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: None
   - Include Tests: Yes
5. Save in the `iosApp/` directory you created
6. Uncheck "Create Git repository" (we already have one)

### Step 5.3: Configure Podfile for MediaPipe

Create `iosApp/Podfile`:

```ruby
platform :ios, '15.0'

target 'iosApp' do
  use_frameworks!

  # MediaPipe Tasks for face landmark detection
  pod 'MediaPipeTasksVision', '~> 0.10.14'

  # Optional: For better async handling
  pod 'Combine', :git => 'https://github.com/CombineCommunity/Combine.git'
end

target 'iosAppTests' do
  inherit! :search_paths
end

target 'iosAppUITests' do
  inherit! :search_paths
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
```

Install pods:

```bash
cd ~/Developer/Switch2GO_AAC_iPadOS/iosApp
pod install
```

**Important**: After running `pod install`, always open `iosApp.xcworkspace` (not `.xcodeproj`)

### Step 5.4: Update settings.gradle.kts

Add iOS app reference to the Gradle settings:

```kotlin
// In settings.gradle.kts, the iOS target is already configured in shared/build.gradle.kts
// No changes needed here for iOS
```

---

## 6. Implementing iOS Platform Code

### Step 6.1: Create iosMain Directory Structure

```bash
cd ~/Developer/Switch2GO_AAC_iPadOS
mkdir -p shared/src/iosMain/kotlin/com/vocable/platform
```

### Step 6.2: Implement Logger.kt (iOS)

Create `shared/src/iosMain/kotlin/com/vocable/platform/Logger.kt`:

```kotlin
package com.vocable.platform

import platform.Foundation.NSLog

actual fun createLogger(tag: String): Logger = OSLogger(tag)

class OSLogger(private val tag: String) : Logger {
    override fun debug(message: String) {
        NSLog("[$tag] DEBUG: $message")
    }

    override fun info(message: String) {
        NSLog("[$tag] INFO: $message")
    }

    override fun warn(message: String) {
        NSLog("[$tag] WARN: $message")
    }

    override fun error(message: String, throwable: Throwable?) {
        if (throwable != null) {
            NSLog("[$tag] ERROR: $message - ${throwable.message}")
        } else {
            NSLog("[$tag] ERROR: $message")
        }
    }
}
```

### Step 6.3: Implement Storage.kt (iOS)

Create `shared/src/iosMain/kotlin/com/vocable/platform/Storage.kt`:

```kotlin
package com.vocable.platform

import com.vocable.eyetracking.models.CalibrationData
import platform.Foundation.NSUserDefaults

actual fun createStorage(): Storage = UserDefaultsStorage()

class UserDefaultsStorage : Storage {
    private val defaults = NSUserDefaults.standardUserDefaults

    override fun saveCalibrationData(data: CalibrationData, mode: String): Boolean {
        return try {
            val prefix = "calibration_${mode}_"

            // Save transform X coefficients
            val transformXStr = data.transformX.joinToString(",")
            defaults.setObject(transformXStr, "${prefix}transformX")

            // Save transform Y coefficients
            val transformYStr = data.transformY.joinToString(",")
            defaults.setObject(transformYStr, "${prefix}transformY")

            // Save metadata
            defaults.setDouble(data.screenWidth.toDouble(), "${prefix}screenWidth")
            defaults.setDouble(data.screenHeight.toDouble(), "${prefix}screenHeight")
            defaults.setDouble(data.calibrationError, "${prefix}error")
            defaults.setObject(data.mode, "${prefix}mode")

            defaults.synchronize()
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun loadCalibrationData(mode: String): CalibrationData? {
        return try {
            val prefix = "calibration_${mode}_"

            val transformXStr = defaults.stringForKey("${prefix}transformX") ?: return null
            val transformYStr = defaults.stringForKey("${prefix}transformY") ?: return null

            val transformX = transformXStr.split(",").map { it.toDouble() }.toDoubleArray()
            val transformY = transformYStr.split(",").map { it.toDouble() }.toDoubleArray()

            CalibrationData(
                transformX = transformX,
                transformY = transformY,
                screenWidth = defaults.doubleForKey("${prefix}screenWidth").toInt(),
                screenHeight = defaults.doubleForKey("${prefix}screenHeight").toInt(),
                calibrationError = defaults.doubleForKey("${prefix}error"),
                mode = defaults.stringForKey("${prefix}mode") ?: mode
            )
        } catch (e: Exception) {
            null
        }
    }

    override fun deleteCalibrationData(mode: String): Boolean {
        val prefix = "calibration_${mode}_"
        listOf("transformX", "transformY", "screenWidth", "screenHeight", "error", "mode").forEach {
            defaults.removeObjectForKey("$prefix$it")
        }
        return defaults.synchronize()
    }

    override fun saveString(key: String, value: String) {
        defaults.setObject(value, key)
        defaults.synchronize()
    }

    override fun loadString(key: String, defaultValue: String): String {
        return defaults.stringForKey(key) ?: defaultValue
    }

    override fun saveFloat(key: String, value: Float) {
        defaults.setFloat(value, key)
        defaults.synchronize()
    }

    override fun loadFloat(key: String, defaultValue: Float): Float {
        return if (defaults.objectForKey(key) != null) {
            defaults.floatForKey(key)
        } else {
            defaultValue
        }
    }

    override fun saveBoolean(key: String, value: Boolean) {
        defaults.setBool(value, key)
        defaults.synchronize()
    }

    override fun loadBoolean(key: String, defaultValue: Boolean): Boolean {
        return if (defaults.objectForKey(key) != null) {
            defaults.boolForKey(key)
        } else {
            defaultValue
        }
    }

    override fun saveInt(key: String, value: Int) {
        defaults.setInteger(value.toLong(), key)
        defaults.synchronize()
    }

    override fun loadInt(key: String, defaultValue: Int): Int {
        return if (defaults.objectForKey(key) != null) {
            defaults.integerForKey(key).toInt()
        } else {
            defaultValue
        }
    }
}
```

### Step 6.4: Implement FaceLandmarkDetector.kt (iOS)

Create `shared/src/iosMain/kotlin/com/vocable/platform/FaceLandmarkDetector.kt`:

```kotlin
package com.vocable.platform

import com.vocable.eyetracking.models.LandmarkPoint

// The iOS FaceLandmarkDetector will be a thin wrapper that delegates to Swift code
// Since MediaPipe iOS SDK is in Swift/ObjC, we'll use a bridge pattern

actual fun createFaceLandmarkDetector(): FaceLandmarkDetector = IOSFaceLandmarkDetector()

class IOSFaceLandmarkDetector : FaceLandmarkDetector {
    // This will be set from Swift side
    var swiftBridge: IOSFaceLandmarkBridge? = null

    private var isInitialized = false
    private var usingGpu = false

    override fun initialize(useGpu: Boolean): Boolean {
        usingGpu = useGpu
        isInitialized = swiftBridge?.initialize(useGpu) ?: false
        return isInitialized
    }

    override suspend fun detectLandmarks(): FaceLandmarkResult? {
        return swiftBridge?.detectLandmarks()
    }

    override fun isReady(): Boolean = isInitialized && swiftBridge != null

    override fun isUsingGpu(): Boolean = usingGpu

    override fun close() {
        swiftBridge?.close()
        isInitialized = false
    }
}

// Interface that Swift code will implement
interface IOSFaceLandmarkBridge {
    fun initialize(useGpu: Boolean): Boolean
    fun detectLandmarks(): FaceLandmarkResult?
    fun close()
}
```

---

## 7. MediaPipe Integration

### Step 7.1: Create Swift Bridge for MediaPipe

Create `iosApp/iosApp/MediaPipe/FaceLandmarkService.swift`:

```swift
import Foundation
import MediaPipeTasksVision
import AVFoundation
import UIKit

class FaceLandmarkService: ObservableObject {
    private var faceLandmarker: FaceLandmarker?
    private var isInitialized = false

    @Published var currentLandmarks: [NormalizedLandmark]?
    @Published var isTracking = false

    func initialize(useGpu: Bool = false) -> Bool {
        do {
            // Get the model file from bundle
            guard let modelPath = Bundle.main.path(
                forResource: "face_landmarker",
                ofType: "task"
            ) else {
                print("Failed to find face_landmarker.task model")
                return false
            }

            // Configure options
            let options = FaceLandmarkerOptions()
            options.baseOptions.modelAssetPath = modelPath
            options.runningMode = .liveStream
            options.numFaces = 1
            options.minFaceDetectionConfidence = 0.5
            options.minFacePresenceConfidence = 0.5
            options.minTrackingConfidence = 0.5
            options.outputFaceBlendshapes = false
            options.outputFacialTransformationMatrixes = false

            // Set delegate based on GPU preference
            if useGpu {
                options.baseOptions.delegate = .GPU
            } else {
                options.baseOptions.delegate = .CPU
            }

            // Set result callback for live stream mode
            options.faceLandmarkerLiveStreamDelegate = self

            faceLandmarker = try FaceLandmarker(options: options)
            isInitialized = true
            return true

        } catch {
            print("Error initializing FaceLandmarker: \(error)")
            return false
        }
    }

    func detectAsync(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        guard isInitialized, let faceLandmarker = faceLandmarker else { return }

        guard let image = try? MPImage(sampleBuffer: sampleBuffer, orientation: orientation) else {
            return
        }

        let timestamp = Int(CACurrentMediaTime() * 1000)

        do {
            try faceLandmarker.detectAsync(image: image, timestampInMilliseconds: timestamp)
        } catch {
            print("Detection error: \(error)")
        }
    }

    func close() {
        faceLandmarker = nil
        isInitialized = false
    }
}

// MARK: - FaceLandmarkerLiveStreamDelegate
extension FaceLandmarkService: FaceLandmarkerLiveStreamDelegate {
    func faceLandmarker(
        _ faceLandmarker: FaceLandmarker,
        didFinishDetection result: FaceLandmarkerResult?,
        timestampInMilliseconds: Int,
        error: Error?
    ) {
        if let error = error {
            print("Face detection error: \(error)")
            return
        }

        guard let result = result,
              let firstFace = result.faceLandmarks.first else {
            DispatchQueue.main.async {
                self.currentLandmarks = nil
                self.isTracking = false
            }
            return
        }

        DispatchQueue.main.async {
            self.currentLandmarks = firstFace
            self.isTracking = true
        }
    }
}
```

### Step 7.2: Download MediaPipe Model

```bash
cd ~/Developer/Switch2GO_AAC_iPadOS/iosApp/iosApp

# Create Resources directory
mkdir -p Resources

# Download the face landmarker model
curl -L "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task" \
  -o Resources/face_landmarker.task
```

Then in Xcode:
1. Right-click on "iosApp" folder in navigator
2. "Add Files to iosApp..."
3. Select `Resources/face_landmarker.task`
4. Check "Copy items if needed"
5. Check "Add to targets: iosApp"

---

## 8. Building the Shared Framework

### Step 8.1: Build from Command Line

```bash
cd ~/Developer/Switch2GO_AAC_iPadOS

# Build debug framework for simulator
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64

# Build release framework for device
./gradlew :shared:linkReleaseFrameworkIosArm64

# The frameworks will be at:
# shared/build/bin/iosSimulatorArm64/debugFramework/VocableShared.framework
# shared/build/bin/iosArm64/releaseFramework/VocableShared.framework
```

### Step 8.2: Link Framework in Xcode

1. Open `iosApp.xcworkspace` in Xcode
2. Select the project in navigator
3. Select "iosApp" target
4. Go to "General" tab
5. Under "Frameworks, Libraries, and Embedded Content":
   - Click "+"
   - Click "Add Other..." > "Add Files..."
   - Navigate to `shared/build/bin/iosSimulatorArm64/debugFramework/`
   - Select `VocableShared.framework`
   - Set "Embed" to "Embed & Sign"

### Step 8.3: Add Build Phase Script

To automatically rebuild the framework:

1. Select project > "iosApp" target > "Build Phases"
2. Click "+" > "New Run Script Phase"
3. Drag it above "Compile Sources"
4. Name it "Build Kotlin Framework"
5. Add script:

```bash
cd "$SRCROOT/.."
./gradlew :shared:embedAndSignAppleFrameworkForXcode
```

---

## 9. SwiftUI Implementation

### Step 9.1: Main App Structure

Replace `iosApp/iosApp/iosAppApp.swift`:

```swift
import SwiftUI
import VocableShared

@main
struct Switch2GoApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    @Published var isCalibrated = false
    @Published var selectedCategory: String?

    let storage: Storage
    let logger: Logger

    init() {
        storage = StorageKt.createStorage()
        logger = LoggerKt.createLogger(tag: "Switch2Go")
    }
}
```

### Step 9.2: Main Content View

Replace `iosApp/iosApp/ContentView.swift`:

```swift
import SwiftUI
import VocableShared

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var gazeManager = GazeTrackingManager()

    var body: some View {
        NavigationStack {
            ZStack {
                // Main AAC Interface
                AACGridView()
                    .environmentObject(gazeManager)

                // Gaze pointer overlay
                if gazeManager.isTracking {
                    GazePointerView(position: gazeManager.gazePosition)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: CalibrationView()) {
                        Image(systemName: "scope")
                    }
                }
            }
        }
        .onAppear {
            gazeManager.startTracking()
        }
    }
}

// Gaze Pointer Overlay
struct GazePointerView: View {
    let position: CGPoint

    var body: some View {
        Circle()
            .fill(Color.blue.opacity(0.6))
            .frame(width: 44, height: 44)
            .position(position)
            .allowsHitTesting(false)
    }
}
```

### Step 9.3: AAC Grid View

Create `iosApp/iosApp/Views/AAC/AACGridView.swift`:

```swift
import SwiftUI

struct AACGridView: View {
    @EnvironmentObject var gazeManager: GazeTrackingManager

    let categories = ["Greetings", "Needs", "Feelings", "Questions", "Responses"]
    let phrases = [
        "Hello", "Goodbye", "Thank you", "Please",
        "Yes", "No", "Help", "I need...",
        "I feel...", "What?", "Where?", "When?"
    ]

    @State private var hoveredIndex: Int?
    @State private var dwellProgress: Double = 0

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack {
            // Output text area
            Text(gazeManager.selectedPhrase ?? "Tap or look at a phrase")
                .font(.title)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding()

            // Phrase grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(phrases.enumerated()), id: \.offset) { index, phrase in
                        PhraseButton(
                            phrase: phrase,
                            isHovered: hoveredIndex == index,
                            dwellProgress: hoveredIndex == index ? dwellProgress : 0
                        ) {
                            gazeManager.selectPhrase(phrase)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct PhraseButton: View {
    let phrase: String
    let isHovered: Bool
    let dwellProgress: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isHovered ? Color.blue.opacity(0.3) : Color.blue.opacity(0.1))

                // Dwell progress indicator
                if isHovered && dwellProgress > 0 {
                    RoundedRectangle(cornerRadius: 16)
                        .trim(from: 0, to: dwellProgress)
                        .stroke(Color.blue, lineWidth: 4)
                }

                Text(phrase)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .frame(height: 120)
        .accessibilityLabel(phrase)
    }
}
```

### Step 9.4: Calibration View

Create `iosApp/iosApp/Views/Calibration/CalibrationView.swift`:

```swift
import SwiftUI
import VocableShared

struct CalibrationView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var calibrationManager = CalibrationManager()

    @State private var currentPointIndex = 0
    @State private var isCollecting = false
    @State private var isComplete = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if isComplete {
                    CalibrationCompleteView(error: calibrationManager.calibrationError)
                } else {
                    // Calibration target
                    CalibrationTargetView(
                        position: calibrationManager.calibrationPoints[safe: currentPointIndex] ?? .zero,
                        isCollecting: isCollecting,
                        progress: calibrationManager.collectionProgress
                    )

                    // Instructions
                    VStack {
                        Text("Look at the circle")
                            .font(.title)
                            .foregroundColor(.white)

                        Text("Point \(currentPointIndex + 1) of \(calibrationManager.calibrationPoints.count)")
                            .foregroundColor(.gray)

                        Spacer()

                        Button(isCollecting ? "Collecting..." : "Start Collection") {
                            startCollection()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isCollecting)
                        .padding(.bottom, 50)
                    }
                    .padding(.top, 100)
                }
            }
        }
        .navigationTitle("Calibration")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calibrationManager.generateCalibrationPoints(
                screenWidth: UIScreen.main.bounds.width,
                screenHeight: UIScreen.main.bounds.height
            )
        }
    }

    private func startCollection() {
        isCollecting = true
        calibrationManager.collectSamples { success in
            isCollecting = false
            if success {
                if currentPointIndex < calibrationManager.calibrationPoints.count - 1 {
                    currentPointIndex += 1
                } else {
                    // All points collected, compute calibration
                    calibrationManager.computeCalibration { result in
                        isComplete = result
                    }
                }
            }
        }
    }
}

struct CalibrationTargetView: View {
    let position: CGPoint
    let isCollecting: Bool
    let progress: Double

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 60, height: 60)

            // Progress ring
            if isCollecting {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.green, lineWidth: 4)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
            }

            // Center dot
            Circle()
                .fill(isCollecting ? Color.green : Color.white)
                .frame(width: 12, height: 12)
        }
        .position(position)
        .animation(.easeInOut, value: position)
    }
}

struct CalibrationCompleteView: View {
    let error: Double

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Calibration Complete!")
                .font(.title)
                .foregroundColor(.white)

            Text("Accuracy: \(String(format: "%.1f", (1 - error) * 100))%")
                .foregroundColor(.gray)
        }
    }
}

// Safe array subscript
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
```

---

## 10. Camera & Eye Tracking

### Step 10.1: Camera Manager

Create `iosApp/iosApp/Camera/CameraManager.swift`:

```swift
import AVFoundation
import UIKit

class CameraManager: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    var frameHandler: ((CMSampleBuffer) -> Void)?

    @Published var isRunning = false
    @Published var permissionGranted = false

    override init() {
        super.init()
        checkPermission()
    }

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            permissionGranted = false
        }
    }

    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        // Use front camera for face tracking
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            print("No front camera available")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            print("Error setting up camera input: \(error)")
            return
        }

        // Configure video output
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Set orientation
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }

        captureSession.commitConfiguration()
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = true
                }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameHandler?(sampleBuffer)
    }
}
```

### Step 10.2: Gaze Tracking Manager

Create `iosApp/iosApp/Tracking/GazeTrackingManager.swift`:

```swift
import SwiftUI
import Combine
import VocableShared

class GazeTrackingManager: ObservableObject {
    private let cameraManager = CameraManager()
    private let faceLandmarkService = FaceLandmarkService()
    private var gazeTracker: GazeTracker?

    @Published var isTracking = false
    @Published var gazePosition: CGPoint = .zero
    @Published var selectedPhrase: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupGazeTracker()
        setupBindings()
    }

    private func setupGazeTracker() {
        let screenSize = UIScreen.main.bounds.size

        // Create platform implementations
        let storage = StorageKt.createStorage()
        let logger = LoggerKt.createLogger(tag: "GazeTracker")

        // Note: We'll handle face landmark detection in Swift and pass results to Kotlin
        gazeTracker = GazeTracker(
            screenWidth: Int32(screenSize.width),
            screenHeight: Int32(screenSize.height),
            storage: storage,
            logger: logger
        )
    }

    private func setupBindings() {
        // Handle camera frames
        cameraManager.frameHandler = { [weak self] sampleBuffer in
            self?.faceLandmarkService.detectAsync(
                sampleBuffer: sampleBuffer,
                orientation: .up
            )
        }

        // Handle landmark results
        faceLandmarkService.$currentLandmarks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] landmarks in
                guard let landmarks = landmarks else {
                    self?.isTracking = false
                    return
                }
                self?.processLandmarks(landmarks)
            }
            .store(in: &cancellables)
    }

    private func processLandmarks(_ landmarks: [NormalizedLandmark]) {
        // Convert MediaPipe landmarks to our LandmarkPoint format
        let landmarkPoints = landmarks.map { landmark in
            LandmarkPoint(
                x: Float(landmark.x),
                y: Float(landmark.y),
                z: Float(landmark.z ?? 0),
                visibility: Float(landmark.visibility ?? 1),
                presence: Float(landmark.presence ?? 1)
            )
        }

        // Process through shared gaze tracker
        if let result = gazeTracker?.processLandmarks(landmarks: landmarkPoints) {
            let screenPoint = gazeTracker?.gazeToScreen(gazeResult: result)

            DispatchQueue.main.async {
                self.isTracking = true
                self.gazePosition = CGPoint(
                    x: CGFloat(screenPoint?.first ?? 0),
                    y: CGFloat(screenPoint?.second ?? 0)
                )
            }
        }
    }

    func startTracking() {
        guard faceLandmarkService.initialize(useGpu: true) else {
            print("Failed to initialize face landmark service")
            return
        }
        cameraManager.start()
    }

    func stopTracking() {
        cameraManager.stop()
        faceLandmarkService.close()
    }

    func selectPhrase(_ phrase: String) {
        selectedPhrase = phrase

        // Speak the phrase
        let utterance = AVSpeechUtterance(string: phrase)
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}
```

---

## 11. Testing

### Step 11.1: Run on Simulator

```bash
# In Xcode:
# 1. Select a simulator (iPhone 15 Pro recommended)
# 2. Press Cmd+R to build and run

# Note: Camera doesn't work in simulator, but UI will load
```

### Step 11.2: Run on Device

1. Connect your iPhone/iPad via USB
2. In Xcode, select your device from the dropdown
3. Press Cmd+R to build and run
4. First time: Trust the developer certificate on device
   - Settings > General > VPN & Device Management > Trust

### Step 11.3: Unit Tests

```bash
# Run shared module tests
./gradlew :shared:iosSimulatorArm64Test

# Run iOS app tests in Xcode
# Cmd+U
```

---

## 12. Code Signing & Provisioning

### Automatic Signing (Recommended for Development)

1. In Xcode, select project > "iosApp" target > "Signing & Capabilities"
2. Check "Automatically manage signing"
3. Select your Team
4. Xcode will create provisioning profiles automatically

### Manual Signing (For CI/CD)

1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Create certificates:
   - Certificates > + > iOS Distribution
3. Create provisioning profile:
   - Profiles > + > App Store Connect
4. Download and install in Xcode

### Required Capabilities

In Xcode > Target > "Signing & Capabilities" > + Capability:
- **Camera** - Required for eye tracking
- **Speech Recognition** - Optional, for voice input

### Info.plist Permissions

Add to `iosApp/iosApp/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Switch2Go needs camera access for eye gaze tracking to enable hands-free communication.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>Switch2Go can use speech recognition for voice input.</string>

<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>armv7</string>
    <string>front-facing-camera</string>
</array>
```

---

## 13. CI/CD with GitHub Actions

### iOS Build Workflow

The project includes `.github/workflows/ios.yml` for automated builds:

```yaml
name: iOS Build

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "**" ]

jobs:
  build-ios-framework:
    name: Build iOS Framework
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set Up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: gradle

      - name: Build iOS Framework
        run: ./gradlew :shared:linkReleaseFrameworkIosArm64

  build-ios-app:
    name: Build iOS App
    runs-on: macos-latest
    needs: build-ios-framework
    steps:
      - uses: actions/checkout@v4

      - name: Set Up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Build Shared Framework
        run: ./gradlew :shared:linkDebugFrameworkIosSimulatorArm64

      - name: Install CocoaPods
        run: |
          cd iosApp
          pod install

      - name: Build iOS App
        run: |
          cd iosApp
          xcodebuild build \
            -workspace iosApp.xcworkspace \
            -scheme iosApp \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO
```

---

## 14. TestFlight & App Store

### Step 14.1: Archive for Distribution

1. In Xcode, select "Any iOS Device" as destination
2. Product > Archive
3. Wait for archive to complete
4. Organizer window opens automatically

### Step 14.2: Upload to App Store Connect

1. In Organizer, select the archive
2. Click "Distribute App"
3. Select "App Store Connect"
4. Follow the wizard
5. Wait for upload to complete

### Step 14.3: TestFlight Setup

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. My Apps > Your App > TestFlight
3. Add internal testers (your team)
4. Add external testers (beta users)
5. Submit for Beta App Review (external only)

### Step 14.4: App Store Submission

1. App Store Connect > My Apps > Your App
2. Prepare for Submission:
   - Screenshots (required sizes)
   - App description
   - Keywords
   - Support URL
   - Privacy Policy URL
3. Select build from TestFlight
4. Submit for Review

---

## 15. Troubleshooting

### Common Issues

#### "No such module 'VocableShared'"
```bash
# Rebuild the framework
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64

# Clean Xcode build
# Cmd+Shift+K
# Then rebuild: Cmd+B
```

#### "Code signing error"
1. Xcode > Preferences > Accounts
2. Verify Apple ID is signed in
3. Select team in project settings
4. Clean and rebuild

#### "MediaPipe model not found"
1. Verify `face_landmarker.task` is in project
2. Check "Target Membership" includes iosApp
3. Clean and rebuild

#### "Camera permission denied"
1. Delete app from device
2. Reinstall
3. Or: Settings > Privacy > Camera > Enable for Switch2Go

#### Gradle build fails
```bash
# Clean Gradle
./gradlew clean

# Check Java version
java -version  # Should be 17

# Rebuild
./gradlew :shared:build
```

### Performance Tips

1. **Use GPU for MediaPipe** when available
2. **Reduce frame rate** to 30fps for battery life
3. **Profile with Instruments** in Xcode
4. **Test on older devices** to ensure compatibility

### Getting Help

- KMP Issues: [Kotlin Slack](https://kotlinlang.slack.com) #multiplatform
- MediaPipe: [GitHub Issues](https://github.com/google/mediapipe/issues)
- SwiftUI: [Apple Developer Forums](https://developer.apple.com/forums/)
- This Project: [GitHub Issues](https://github.com/grahamthetvi/Switch2GO_AAC_iPadOS/issues)

---

## Quick Reference Commands

```bash
# Build iOS framework (debug, simulator)
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64

# Build iOS framework (release, device)
./gradlew :shared:linkReleaseFrameworkIosArm64

# Run shared tests on iOS
./gradlew :shared:iosSimulatorArm64Test

# Install CocoaPods
cd iosApp && pod install

# Open Xcode workspace
open iosApp/iosApp.xcworkspace

# Build from command line
xcodebuild -workspace iosApp/iosApp.xcworkspace -scheme iosApp -sdk iphonesimulator build

# Clean everything
./gradlew clean
cd iosApp && xcodebuild clean
```

---

## Summary

Building Switch2Go for iOS from a Windows machine using a virtual Mac is entirely feasible. The key steps are:

1. **Set up a cloud Mac** (MacStadium recommended)
2. **Install development tools** (Xcode, CocoaPods, JDK)
3. **Create the iOS project** in Xcode
4. **Implement platform-specific Kotlin** code in `iosMain`
5. **Integrate MediaPipe** for face tracking
6. **Build SwiftUI interface** for the AAC app
7. **Test on device** and iterate
8. **Deploy via TestFlight** for beta testing
9. **Submit to App Store** when ready

The shared KMP module (~1,500 lines) handles all the complex gaze tracking math, so the iOS-specific code focuses on:
- Camera capture (AVFoundation)
- Face detection (MediaPipe iOS)
- UI (SwiftUI)
- Platform storage (UserDefaults)

This architecture means bug fixes and improvements to the gaze tracking algorithms automatically benefit both Android and iOS versions.
