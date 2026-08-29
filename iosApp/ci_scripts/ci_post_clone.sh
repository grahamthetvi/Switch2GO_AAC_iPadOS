#!/bin/sh
# Xcode Cloud post-clone script.
# Runs after git clone and before xcodebuild. CocoaPods xcconfigs are not in git
# (iosApp/Pods is ignored), so the archive fails without this step:
#   Unable to open base configuration reference file
#   '.../Pods/Target Support Files/Pods-iosApp/Pods-iosApp.release.xcconfig'
set -e

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export NONINTERACTIVE=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

if [ -n "${CI_PRIMARY_REPOSITORY_PATH:-}" ]; then
  REPO_ROOT="$CI_PRIMARY_REPOSITORY_PATH"
elif [ -n "${CI_WORKSPACE:-}" ]; then
  REPO_ROOT="$CI_WORKSPACE"
else
  REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
fi

echo "Xcode Cloud post-clone"
echo "REPO_ROOT=$REPO_ROOT"

# --- Java 17 (required by the Kotlin/Gradle build phase) ---
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
  return 1
}

if ! is_java_17 "${JAVA_HOME:-}"; then
  JAVA_HOME="$(find_java_17_home || true)"
fi

if ! is_java_17 "${JAVA_HOME:-}"; then
  echo "Installing OpenJDK 17 via Homebrew..."
  brew install openjdk@17
  JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
fi

if ! is_java_17 "$JAVA_HOME"; then
  echo "error: Java 17 is required but was not found after install." >&2
  exit 1
fi

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p "$HOME/Library/Java/JavaVirtualMachines"
ln -sfn "$(CDPATH= cd -- "$JAVA_HOME/../.." && pwd)" \
  "$HOME/Library/Java/JavaVirtualMachines/openjdk-17.jdk"

echo "OK: Java 17 at $JAVA_HOME"
java -version

# --- Android SDK (AGP configures :app and :shared even for iOS framework tasks) ---
install_android_sdk() {
  if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/platforms/android-35" ]; then
    echo "OK: Android SDK already present at $ANDROID_HOME"
    return 0
  fi

  echo "Installing Android command-line tools..."
  brew install --cask android-commandlinetools

  PREFIX="$(brew --prefix)"
  ANDROID_HOME="${PREFIX}/share/android-commandlinetools"
  export ANDROID_HOME
  export ANDROID_SDK_ROOT="$ANDROID_HOME"

  SDKMANAGER="$(command -v sdkmanager || true)"
  if [ -z "$SDKMANAGER" ] || [ ! -x "$SDKMANAGER" ]; then
    if [ -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
      SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
    elif [ -x "$ANDROID_HOME/cmdline-tools/bin/sdkmanager" ]; then
      SDKMANAGER="$ANDROID_HOME/cmdline-tools/bin/sdkmanager"
    else
      echo "error: sdkmanager not found after android-commandlinetools install." >&2
      exit 1
    fi
  fi

  mkdir -p "$ANDROID_HOME"
  set +e
  yes | "$SDKMANAGER" --sdk_root="$ANDROID_HOME" --licenses >/dev/null
  set -e
  "$SDKMANAGER" --sdk_root="$ANDROID_HOME" \
    "platforms;android-35" \
    "build-tools;35.0.0"

  echo "OK: Android SDK at $ANDROID_HOME"
}

install_android_sdk
printf 'sdk.dir=%s\n' "$ANDROID_HOME" > "$REPO_ROOT/local.properties"

# --- CocoaPods (creates the xcconfig files Xcode Cloud needs to open the project) ---
echo "Installing CocoaPods dependencies..."
cd "$REPO_ROOT/iosApp"
if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi
pod install --repo-update
echo "OK: pod install finished"

XCCONFIG="$REPO_ROOT/iosApp/Pods/Target Support Files/Pods-iosApp/Pods-iosApp.release.xcconfig"
if [ ! -f "$XCCONFIG" ]; then
  echo "error: expected CocoaPods xcconfig was not generated:" >&2
  echo "  $XCCONFIG" >&2
  exit 1
fi

# --- MediaPipe models (gitignored; Xcode Copy Bundle Resources requires them) ---
echo "Downloading MediaPipe models..."
MODEL_DIR="$REPO_ROOT/iosApp/Resources"
mkdir -p "$MODEL_DIR"

download_model() {
  name="$1"
  url="$2"
  path="$MODEL_DIR/${name}.task"
  if [ -f "$path" ]; then
    echo "OK: ${name}.task already present"
    return 0
  fi
  curl -fsSL "$url" -o "$path"
  echo "OK: downloaded ${name}.task"
}

download_model "face_landmarker" \
  "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
download_model "pose_landmarker_lite" \
  "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task"
download_model "gesture_recognizer" \
  "https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task"

echo "Post-clone complete."
