#!/bin/bash
# Build script for Switch2Go iOS app

set -e

echo "🚀 Building Switch2Go iOS App..."
echo "=================================="

# Set Java home for Gradle
# Try multiple methods to find Java
if [ -z "$JAVA_HOME" ]; then
    # Try to find Java 17
    export JAVA_HOME=$(/usr/libexec/java_home -v 17 2>/dev/null)
fi

if [ -z "$JAVA_HOME" ]; then
    # Try any Java version
    export JAVA_HOME=$(/usr/libexec/java_home 2>/dev/null)
fi

if [ -z "$JAVA_HOME" ]; then
    # Try common Homebrew location
    if [ -d "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home" ]; then
        export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
    fi
fi

if [ -z "$JAVA_HOME" ]; then
    echo "❌ Error: Java not found. Please install Java 17 or later."
    echo ""
    echo "Install options:"
    echo "  1. Homebrew: brew install openjdk@17"
    echo "  2. Oracle: https://www.oracle.com/java/technologies/downloads/"
    echo "  3. Adoptium: https://adoptium.net/"
    echo ""
    exit 1
fi

echo "✓ Java found: $JAVA_HOME"
java -version 2>&1 | head -1

# Build shared framework for iOS
echo ""
echo "📦 Building shared KMP framework..."
echo "-----------------------------------"

# Determine architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    FRAMEWORK_TARGET="iosSimulatorArm64"
else
    FRAMEWORK_TARGET="iosX64"
fi

echo "Building for architecture: $FRAMEWORK_TARGET"

./gradlew :shared:linkDebugFramework${FRAMEWORK_TARGET} --no-daemon

echo "📦 Building release framework for archiving (iosArm64)..."
./gradlew :shared:linkReleaseFrameworkIosArm64 --no-daemon

if [ $? -eq 0 ]; then
    echo "✓ Shared framework built successfully"
else
    echo "❌ Failed to build shared framework"
    exit 1
fi

# Check for CocoaPods
echo ""
echo "📦 Installing CocoaPods dependencies..."
echo "---------------------------------------"

if ! command -v pod &> /dev/null; then
    echo "⚠️  CocoaPods not found. Install with: sudo gem install cocoapods"
    echo "Skipping pod install..."
else
    cd iosApp
    pod install
    cd ..
    echo "✓ CocoaPods dependencies installed"
fi

# Check for MediaPipe model
echo ""
echo "📥 Checking MediaPipe model..."
echo "-------------------------------"

MODEL_PATH="iosApp/iosApp/Resources/face_landmarker.task"
if [ ! -f "$MODEL_PATH" ]; then
    echo "⚠️  MediaPipe model not found. Downloading..."
    mkdir -p iosApp/iosApp/Resources
    curl -L "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task" \
        -o "$MODEL_PATH"
    
    if [ -f "$MODEL_PATH" ]; then
        echo "✓ MediaPipe model downloaded"
    else
        echo "❌ Failed to download MediaPipe model"
        exit 1
    fi
else
    echo "✓ MediaPipe model exists"
fi

# Summary
echo ""
echo "✅ Build Complete!"
echo "=================="
echo ""
echo "Next steps:"
echo "1. Open iosApp/iosApp.xcworkspace in Xcode"
echo "2. Select a simulator or device"
echo "3. Press Cmd+R to build and run"
echo ""
echo "Note: Camera features require a physical device."
echo ""
