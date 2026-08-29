#!/bin/sh
# Called from the Xcode "Build Kotlin Framework" script phase.
# SRCROOT is iosApp/ when Xcode runs this.
set -e

if [ -z "${SRCROOT:-}" ]; then
  SRCROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
fi

cd "$SRCROOT/.."

# Kotlin/Gradle require Java 17. Java 25+ causes a cryptic "25.0.1" build failure.
is_java_17() {
  [ -n "${1:-}" ] && [ -x "$1/bin/java" ] && "$1/bin/java" -version 2>&1 | grep -q 'version "17'
}

find_java_17_home() {
  CANDIDATE="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
  if is_java_17 "$CANDIDATE"; then
    echo "$CANDIDATE"
    return 0
  fi

  BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  for candidate in \
    "${BREW_PREFIX}/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" \
    "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" \
    "/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" \
    "$HOME/Library/Java/JavaVirtualMachines/openjdk-17.jdk/Contents/Home"
  do
    if is_java_17 "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done

  for candidate in "$HOME"/.jdks/*/Contents/Home; do
    if is_java_17 "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

if ! is_java_17 "${JAVA_HOME:-}"; then
  JAVA_HOME="$(find_java_17_home || true)"
fi

if ! is_java_17 "${JAVA_HOME:-}"; then
  echo "error: Java 17 is required but not found." >&2
  echo "Install Temurin 17 from https://adoptium.net/ or run: brew install openjdk@17" >&2
  if java -version >/dev/null 2>&1; then
    echo "Current default Java: $(java -version 2>&1 | head -1)" >&2
    echo "Gradle/Kotlin do not support Java 25 yet." >&2
  fi
  exit 1
fi

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

KOTLIN_CONFIG="Debug"
if [ "${CONFIGURATION:-}" = "Release" ]; then
  KOTLIN_CONFIG="Release"
fi

TARGET="IosArm64"
if [ "${PLATFORM_NAME:-}" = "iphonesimulator" ]; then
  case "${ARCHS:-}" in
    *x86_64*) TARGET="IosX64" ;;
    *) TARGET="IosSimulatorArm64" ;;
  esac
fi

./gradlew ":shared:link${KOTLIN_CONFIG}Framework${TARGET}"

# The Xcode project file-references VocableShared at the device debugFramework
# path. Release archives build releaseFramework instead, so copy it into place.
if [ "$KOTLIN_CONFIG" = "Release" ] && [ "$TARGET" = "IosArm64" ]; then
  SRC="shared/build/bin/iosArm64/releaseFramework/VocableShared.framework"
  DEST_DIR="shared/build/bin/iosArm64/debugFramework"
  mkdir -p "$DEST_DIR"
  rm -rf "$DEST_DIR/VocableShared.framework"
  cp -R "$SRC" "$DEST_DIR/VocableShared.framework"
fi
