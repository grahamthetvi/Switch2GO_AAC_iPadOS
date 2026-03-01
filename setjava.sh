#!/bin/bash
# Helper script to set JAVA_HOME for building

export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

echo "✅ JAVA_HOME set to: $JAVA_HOME"
java -version 2>&1 | head -1

# Print usage
echo ""
echo "Run this in your terminal to set Java:"
echo "  source ./setjava.sh"
echo ""
echo "Then you can run:"
echo "  ./gradlew :shared:linkDebugFrameworkIosSimulatorArm64"
echo "  or"
echo "  ./build_ios.sh"
