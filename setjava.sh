#!/bin/bash
# Helper script to set JAVA_HOME for building. Works on Intel + Apple Silicon and falls
# back to Homebrew layouts only if /usr/libexec/java_home cannot find a JDK 17.

if [ -z "$JAVA_HOME" ]; then
    JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
fi
if [ -n "$JAVA_HOME" ] && ! "$JAVA_HOME/bin/java" -version 2>&1 | grep -q 'version "17'; then
    JAVA_HOME=""
fi
if [ -z "$JAVA_HOME" ] && [ -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]; then
    JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
fi
if [ -z "$JAVA_HOME" ] && [ -d "/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]; then
    JAVA_HOME="/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
fi
if [ -z "$JAVA_HOME" ]; then
    for candidate in "$HOME"/.jdks/*/Contents/Home; do
        if [ -x "$candidate/bin/java" ] && "$candidate/bin/java" -version 2>&1 | grep -q 'version "17'; then
            JAVA_HOME="$candidate"
            break
        fi
    done
fi

if [ -z "$JAVA_HOME" ]; then
    echo "ERROR: Could not locate a Java 17 install. Try: brew install openjdk@17"
    if java -version >/dev/null 2>&1; then
        echo "Current default Java: $(java -version 2>&1 | head -1)"
        echo "Gradle/Kotlin do not support Java 25 yet."
    fi
    return 1 2>/dev/null || exit 1
fi

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

echo "OK: JAVA_HOME set to: $JAVA_HOME"
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
