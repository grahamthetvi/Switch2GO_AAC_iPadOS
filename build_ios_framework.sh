#!/bin/bash
set -e

# Build iOS frameworks for both simulator and device
echo "Building VocableShared framework for iOS..."

# Set JAVA_HOME
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export PATH="$JAVA_HOME/bin:$PATH"

# Build for device (arm64) - Debug
echo "Building debug framework for device (arm64)..."
./gradlew :shared:linkDebugFrameworkIosArm64

# Build for device (arm64) - Release
echo "Building release framework for device (arm64)..."
./gradlew :shared:linkReleaseFrameworkIosArm64

# Build for simulator (arm64)
echo "Building for simulator (arm64)..."
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64

# Code sign device frameworks (required for TestFlight/App Store)
echo ""
echo "Code signing device frameworks..."

SIGNING_IDENTITY="${CODESIGN_IDENTITY:-Apple Development}"

if [ -d "shared/build/bin/iosArm64/debugFramework/VocableShared.framework" ]; then
    echo "Signing debug framework..."
    codesign --force --sign "$SIGNING_IDENTITY" \
        --preserve-metadata=identifier,entitlements,flags \
        --generate-entitlement-der \
        shared/build/bin/iosArm64/debugFramework/VocableShared.framework
fi

if [ -d "shared/build/bin/iosArm64/releaseFramework/VocableShared.framework" ]; then
    echo "Signing release framework..."
    codesign --force --sign "$SIGNING_IDENTITY" \
        --preserve-metadata=identifier,entitlements,flags \
        --generate-entitlement-der \
        shared/build/bin/iosArm64/releaseFramework/VocableShared.framework
fi

echo ""
echo "✅ iOS frameworks built and signed successfully!"
echo ""
echo "Device debug framework: shared/build/bin/iosArm64/debugFramework/"
echo "Device release framework: shared/build/bin/iosArm64/releaseFramework/"
echo "Simulator framework: shared/build/bin/iosSimulatorArm64/debugFramework/"
echo ""
echo "For archiving/TestFlight: Use the device release framework"
echo "For device debugging: Use the device debug framework"
echo "For Xcode simulator: Use the simulator framework"
