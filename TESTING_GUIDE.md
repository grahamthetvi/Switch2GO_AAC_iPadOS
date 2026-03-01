# iOS App Testing Guide

This guide explains how to test the Switch2Go iOS app before deploying to TestFlight or the App Store.

## Quick Summary of the Fix

The crash you experienced was caused by an **unsigned framework**. iOS devices with pointer authentication (all modern devices) require all frameworks to be properly code-signed. We've now:

1. ✅ Added automatic code signing to the build process
2. ✅ Signed both debug and release frameworks
3. ✅ Added defensive error handling in Swift code

## Pre-Deployment Testing Options

### Option 1: iOS Simulator Testing (Fastest, No Device Needed)

The simulator doesn't require code signing, making it perfect for quick iteration:

```bash
# 1. Build the simulator framework
cd /Users/user289033/Switch2GO_AAC_iPadOS
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export PATH="$JAVA_HOME/bin:$PATH"
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64

# 2. Update Xcode to use simulator framework (temporary)
# In Xcode: Product > Destination > Choose any iOS Simulator
# Build and run (⌘R)
```

**Pros:**
- Fast iteration
- No code signing needed
- Easy debugging with Xcode

**Cons:**
- Camera not available (gaze tracking won't work fully)
- Performance may differ from real device
- Some iOS features behave differently

### Option 2: Physical Device Testing (Recommended)

Test on an actual iPad to verify camera, gaze tracking, and performance:

```bash
# 1. Build and sign the device framework
./build_ios_framework.sh

# 2. Connect your iPad via USB
# 3. In Xcode: Product > Destination > Your iPad
# 4. Build and run (⌘R)
```

**Pros:**
- Real camera access for gaze tracking
- Accurate performance testing
- Tests actual user experience

**Cons:**
- Requires physical device
- Requires Apple Developer account

### Option 3: TestFlight Internal Testing

For final validation before public release:

1. Archive the app in Xcode (Product > Archive)
2. Upload to App Store Connect
3. Add internal testers
4. Install via TestFlight app

**Pros:**
- Tests the exact build users will get
- Tests distribution signing
- Can share with team members

**Cons:**
- Slower iteration (upload + processing time)
- Requires App Store Connect access

## Build Configuration

### Current Setup

- **Debug builds**: Use `iosArm64/debugFramework` (signed)
- **Release builds**: Use `iosArm64/releaseFramework` (signed)
- **Simulator builds**: Use `iosSimulatorArm64/debugFramework` (unsigned, OK for simulator)

### Switching Between Device and Simulator

The Xcode project is currently configured for **device builds**. To test on simulator:

**Temporary Method (Quick Testing):**
1. In Xcode, select an iOS Simulator as the destination
2. The build may fail - if so, temporarily change the framework path in Xcode build settings

**Automated Method (Recommended):**
We should add a build script phase to Xcode that automatically selects the right framework based on the build destination.

## Verifying Framework Signing

To check if a framework is properly signed:

```bash
# Check signing status
codesign -dvvv shared/build/bin/iosArm64/debugFramework/VocableShared.framework

# Should show:
# - Signature size
# - Authority: Apple Development (or Apple Distribution)
# - Signed Time
# - Info.plist entries
```

## Common Issues and Solutions

### Issue: "Code object is not signed at all"

**Solution:** Run the build script which now includes automatic signing:
```bash
./build_ios_framework.sh
```

### Issue: "Building for iOS, but linking in object file built for iOS-simulator"

**Solution:** You're building for device but the project is pointing to simulator framework:
```bash
# Rebuild device frameworks
./build_ios_framework.sh

# Make sure Xcode is using device framework path
# Check Build Settings > Framework Search Paths
```

### Issue: App crashes immediately on launch (SIGTRAP)

**Possible causes:**
1. **Unsigned framework** - Run `./build_ios_framework.sh` to sign
2. **Wrong framework architecture** - Make sure device builds use iosArm64, simulator uses iosSimulatorArm64
3. **Missing dependencies** - Run `pod install` in iosApp directory

### Issue: "Failed to initialize VocableShared module"

**Solution:** This is a defensive error we added. Check:
1. Framework is properly embedded in app bundle
2. Framework is signed correctly
3. Check Xcode console for detailed error message

## Recommended Testing Workflow

### For Development (Fast Iteration)

1. **Use iOS Simulator** for UI and logic testing
2. Test on **physical device** periodically for camera/gaze tracking
3. Use Xcode's **SwiftUI Previews** for quick UI changes

### Before TestFlight Upload

1. ✅ Test on physical device in Debug mode
2. ✅ Build in Release mode and test on physical device
3. ✅ Verify all features work (camera permissions, gaze tracking, calibration)
4. ✅ Check crash logs if any issues occur
5. ✅ Archive and validate in Xcode (Product > Archive > Validate App)

### Automated Checks

```bash
# Verify frameworks are built and signed
ls -la shared/build/bin/iosArm64/debugFramework/
ls -la shared/build/bin/iosArm64/releaseFramework/
codesign -v shared/build/bin/iosArm64/debugFramework/VocableShared.framework
codesign -v shared/build/bin/iosArm64/releaseFramework/VocableShared.framework

# Should all show "valid on disk"
```

## Crash Log Analysis

If you get a crash on device:

1. **Get the crash log** from Xcode (Window > Devices and Simulators > View Device Logs)
2. **Look for key indicators:**
   - `EXC_BREAKPOINT (SIGTRAP)` + "pointer authentication trap" = Unsigned framework
   - `dyld: Library not loaded` = Framework not embedded
   - Stack trace in your Swift code = Logic error

3. **Symbolicate the crash log** (Xcode does this automatically if you have the dSYM)

## Next Steps

1. **Test in Simulator** - Quick validation that app launches
2. **Test on Device** - Full feature validation with signed framework
3. **Consider adding unit tests** - Test VocableShared initialization separately
4. **Add UI tests** - Automate testing of critical user flows

## Questions?

If you encounter issues not covered here, check:
- Xcode build logs (⌘9 to open Report Navigator)
- Console output (⌘⇧Y to show debug area)
- Device logs (Window > Devices and Simulators)
