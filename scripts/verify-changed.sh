#!/usr/bin/env bash
# Run the Switch2Go checks this machine can actually execute, and name the
# ones it cannot. Read .cursor/skills/verify-switch2go/SKILL.md before
# treating the result as "the change is correct".
#
# Usage:
#   scripts/verify-changed.sh                 # files in the git diff
#   scripts/verify-changed.sh path/a path/b   # explicit paths
#
# Exit 0: runnable checks passed and nothing needs a sibling decision.
# Exit 1: a command ran and failed.
# Exit 3: checks passed, but a REVIEW or a missing tool on this machine
#         still has to be resolved in the reply. Exit 3 is not a pass.

set -u

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

status=0
review=0
logdir="$(mktemp -d "${TMPDIR:-/tmp}/verify-switch2go.XXXXXX")"

say() { printf '%s\n' "$*"; }

files=()
if [[ $# -gt 0 ]]; then
  files=("$@")
else
  while IFS= read -r line; do
    [[ -n "$line" ]] && files+=("$line")
  done < <(
    {
      git diff --name-only HEAD
      git diff --name-only --cached
      git ls-files --others --exclude-standard
    } | sed '/^$/d' | sort -u
  )
fi

if [[ ${#files[@]} -eq 0 ]]; then
  say "NO FILES: pass paths, or change files so git has a diff."
  exit 0
fi

relative=()
for f in "${files[@]}"; do
  f="${f#"$ROOT"/}"
  relative+=("$f")
done
files=("${relative[@]}")

say "LOGS: $logdir"
say "FILES:"
for f in "${files[@]}"; do
  say "  $f"
done

has() {
  local pattern="$1" f
  for f in "${files[@]}"; do
    # shellcheck disable=SC2254
    case "$f" in
      $pattern) return 0 ;;
    esac
  done
  return 1
}

has_any() {
  local pattern
  for pattern in "$@"; do
    has "$pattern" && return 0
  done
  return 1
}

note_review() {
  review=1
  say "REVIEW: $*"
}

review_pair() {
  local ios="$1" web="$2" label="$3"
  if has "$ios" && ! has "$web"; then
    note_review "$label changed on iOS. Compare $web."
  elif has "$web" && ! has "$ios"; then
    note_review "$label changed on web. Compare $ios."
  fi
}

note_skip() {
  review=1
  say "NOT RUN: $*"
}

run_cmd() {
  local name="$1"
  shift
  say "RUN: $name"
  say "CMD: $*"
  if "$@" >"$logdir/${name}.log" 2>&1; then
    say "PASS: $name"
  else
    say "FAIL: $name (last 40 lines; full log: $logdir/${name}.log)"
    tail -n 40 "$logdir/${name}.log" || true
    status=1
  fi
}

# --- Sibling reviews (see .cursor/skills/verify-switch2go/parity.md) ---

if has 'shared/src/commonMain/kotlin/com/vocable/eyetracking/*' \
  && ! has_any \
    'web/src/tracking/irisGazeCalculator.ts' \
    'web/src/tracking/gazeTracker.ts' \
    'web/src/tracking/kalmanFilter2D.ts' \
    'web/src/tracking/adaptiveKalmanFilter2D.ts' \
    'web/src/tracking/eyeball3DGazeCalculator.ts' \
    'web/src/tracking/matrixMath.ts'
then
  note_review "Kotlin gaze math changed. The web port is separate files under web/src/tracking/ (irisGazeCalculator.ts, gazeTracker.ts, kalmanFilter2D.ts, adaptiveKalmanFilter2D.ts, eyeball3DGazeCalculator.ts). iOS runs the Kotlin inside VocableShared and will not see it until the Xcode build phase rebuilds the framework."
fi

if has_any \
  'web/src/tracking/irisGazeCalculator.ts' \
  'web/src/tracking/gazeTracker.ts' \
  'web/src/tracking/kalmanFilter2D.ts' \
  'web/src/tracking/adaptiveKalmanFilter2D.ts' \
  'web/src/tracking/eyeball3DGazeCalculator.ts' \
  'web/src/tracking/matrixMath.ts' \
  && ! has 'shared/src/commonMain/kotlin/com/vocable/eyetracking/*'
then
  note_review "Web gaze math changed. The iOS app does not run these TypeScript files. The source it runs is shared/src/commonMain/kotlin/com/vocable/eyetracking/. Compare that Kotlin before finishing."
fi

if has 'iosApp/iosApp/Tracking/GazeTrackingManager.swift' \
  && ! has_any 'web/src/tracking/trackingManager.ts' 'web/src/tracking/TrackingContext.tsx'
then
  note_review "GazeTrackingManager.swift changed (cursor, dwell wiring, head compensation, selection mode). Compare web/src/tracking/trackingManager.ts and TrackingContext.tsx. Camera behavior still needs a physical iPad."
fi

if has 'iosApp/iosApp/Tracking/DwellSelectionManager.swift' \
  && ! has 'web/src/tracking/dwellManager.ts'
then
  note_review "iOS dwell changed. Compare web/src/tracking/dwellManager.ts. iosAppTests/DwellSelectionManagerTests.swift covers hit testing, not the camera."
fi

if has 'web/src/tracking/dwellManager.ts' \
  && ! has 'iosApp/iosApp/Tracking/DwellSelectionManager.swift'
then
  note_review "Web dwell changed. Compare iosApp/iosApp/Tracking/DwellSelectionManager.swift and iosAppTests/DwellSelectionManagerTests.swift."
fi

if has_any 'iosApp/iosApp/Tracking/HeadPoseTracker.swift' \
  && ! has 'web/src/tracking/headPoseTracker.ts'
then
  note_review "iOS head pose changed. Compare web/src/tracking/headPoseTracker.ts."
fi

if has 'web/src/tracking/headPoseTracker.ts' \
  && ! has 'iosApp/iosApp/Tracking/HeadPoseTracker.swift'
then
  note_review "Web head pose changed. Compare iosApp/iosApp/Tracking/HeadPoseTracker.swift."
fi

if has_any \
  'iosApp/iosApp/Tracking/ArmRaiseDetector.swift' \
  && ! has_any \
    'web/src/tracking/armRaiseDetector.ts' \
    'web/src/tracking/userFacingLaterality.ts'
then
  note_review "iOS arm raise changed. Compare web/src/tracking/armRaiseDetector.ts and userFacingLaterality.ts. Arm raise only applies on a 2-symbol page."
fi

if has_any \
  'web/src/tracking/armRaiseDetector.ts' \
  'web/src/tracking/userFacingLaterality.ts' \
  && ! has 'iosApp/iosApp/Tracking/ArmRaiseDetector.swift'
then
  note_review "Web arm-raise or laterality changed. Compare iosApp/iosApp/Tracking/ArmRaiseDetector.swift. User-left is phrase index 0."
fi

if has 'iosApp/iosApp/Tracking/HandGestureDetector.swift' \
  && ! has 'web/src/tracking/handGestureDetector.ts'
then
  note_review "iOS hand gesture changed. Compare web/src/tracking/handGestureDetector.ts. Gestures only apply on a 2-symbol page."
fi

if has 'web/src/tracking/handGestureDetector.ts' \
  && ! has 'iosApp/iosApp/Tracking/HandGestureDetector.swift'
then
  note_review "Web hand gesture changed. Compare iosApp/iosApp/Tracking/HandGestureDetector.swift."
fi

if has_any \
  'shared/src/commonMain/kotlin/com/vocable/data/PresetData.kt' \
  'shared/src/commonMain/kotlin/com/vocable/data/models/Category.kt' \
  'scripts/export-presets.mjs' \
  'web/src/data/presets.json'
then
  bak="$logdir/presets.json.bak"
  cp web/src/data/presets.json "$bak"
  if node scripts/export-presets.mjs >"$logdir/presets.log" 2>&1; then
    if cmp -s web/src/data/presets.json "$bak"; then
      say "PASS: presets.json matches PresetData.kt"
    else
      note_review "web/src/data/presets.json does not match PresetData.kt. Regenerate with: node scripts/export-presets.mjs"
    fi
  else
    say "FAIL: export-presets (last 40 lines; full log: $logdir/presets.log)"
    tail -n 40 "$logdir/presets.log" || true
    status=1
  fi
  cp "$bak" web/src/data/presets.json
fi

if has 'iosApp/iosApp/Utils/AppSettings.swift' \
  && ! has 'web/src/settings/settingsStore.ts'
then
  note_review "AppSettings.swift changed. Compare web/src/settings/settingsStore.ts for the same key. Phrase packs and ESP32 switches are iOS-only. Web setSymbolCount clamps to 1-4; the iOS property setter does not."
fi

if has 'web/src/settings/settingsStore.ts' \
  && ! has 'iosApp/iosApp/Utils/AppSettings.swift'
then
  note_review "Web settings changed. Compare iosApp/iosApp/Utils/AppSettings.swift. Do not treat AppSettingsTests as proof of the 1-4 symbol rule."
fi

if has 'shared/src/commonMain/sqldelight/*' \
  && ! has_any 'web/src/data/db.ts' 'web/src/data/repository.ts'
then
  note_review "SQLDelight schema changed. iOS reads it through VocableShared after a framework rebuild. Web persistence is Dexie in web/src/data/db.ts. Update that schema if the same field exists on web."
fi

if has_any 'web/src/data/db.ts' 'web/src/data/repository.ts' \
  && ! has 'shared/src/commonMain/sqldelight/*'
then
  note_review "Web Dexie persistence changed. iOS persistence is SQLDelight under shared/src/commonMain/sqldelight plus iosApp/iosApp/Data/DatabaseManager.swift."
fi

if has 'iosApp/iosApp/Utils/TTSManager.swift' && ! has 'web/src/tts/*'; then
  note_review "iOS speech changed. Compare web/src/tts/. Audio output needs a device or browser; a unit test does not prove the voice."
fi

if has 'web/src/tts/*' && ! has 'iosApp/iosApp/Utils/TTSManager.swift'; then
  note_review "Web speech changed. Compare iosApp/iosApp/Utils/TTSManager.swift."
fi

if has 'iosApp/iosApp/Game/*' && ! has 'web/src/game/*'; then
  note_review "iOS game changed. Compare web/src/game/ if the same game exists there."
fi

if has 'web/src/game/*' && ! has 'iosApp/iosApp/Game/*'; then
  note_review "Web game changed. Compare iosApp/iosApp/Game/."
fi

if has_any \
  'iosApp/iosApp/Tracking/SwitchControlManager.swift' \
  'iosApp/iosApp/Tracking/ESP32SwitchOutputManager.swift' \
  'iosApp/iosApp/Tracking/AACScannerProtocol.swift' \
  'iosApp/iosApp/Tracking/AACScannerManager.swift'
then
  note_review "Switch or scanner code changed. ESP32 BLE pairing is iOS-only and needs hardware. Web selection for keys 1-4 is a different path (phrases page), not this Bluetooth stack."
fi

if has_any 'iosApp/Resources/Localizable.xcstrings' 'iosApp/iosApp/Utils/LocalizationHelper.swift' \
  && ! has 'web/src/i18n/*'
then
  note_review "iOS strings changed. Compare web/src/i18n/ if the same user-facing string exists on web."
fi

if has 'web/src/i18n/*' && ! has 'iosApp/Resources/Localizable.xcstrings'; then
  note_review "Web strings changed. Compare iosApp/Resources/Localizable.xcstrings."
fi

review_pair iosApp/iosApp/Views/Phrases/PhrasesView.swift web/src/pages/PhrasesPage.tsx "Phrases screen"
review_pair iosApp/iosApp/Views/Categories/CategoriesView.swift web/src/pages/CategoriesPage.tsx "Categories screen"
review_pair iosApp/iosApp/Views/Settings/MainSettingsView.swift web/src/pages/settings/SettingsHubPage.tsx "Settings hub"
review_pair iosApp/iosApp/Views/Settings/SelectionModeView.swift web/src/pages/settings/SelectionModePage.tsx "Selection mode screen"
review_pair iosApp/iosApp/Views/Settings/CVIDisplaySettingsView.swift web/src/pages/settings/CVIDisplayPage.tsx "CVI display screen"
review_pair iosApp/iosApp/Views/Settings/TimingSensitivityView.swift web/src/pages/settings/TimingSensitivityPage.tsx "Timing screen"
review_pair iosApp/iosApp/Views/Settings/SpeechSettingsView.swift web/src/pages/settings/SpeechPage.tsx "Speech screen"
review_pair iosApp/iosApp/Views/Settings/AdvancedEyeTrackingView.swift web/src/pages/settings/AdvancedEyeTrackingPage.tsx "Advanced eye tracking screen"
review_pair iosApp/iosApp/Views/Settings/SwitchControlSettingsView.swift web/src/pages/settings/SwitchControlPage.tsx "Switch settings screen"
review_pair iosApp/iosApp/Views/Settings/LanguageSettingsView.swift web/src/pages/settings/LanguagePage.tsx "Language screen"
review_pair iosApp/iosApp/Views/Settings/DataBackupView.swift web/src/pages/settings/DataBackupPage.tsx "Backup screen"
review_pair iosApp/iosApp/Views/Settings/ResetAppView.swift web/src/pages/settings/ResetAppPage.tsx "Reset screen"

if has 'app/*'; then
  note_skip "app/ is the legacy Android app. Do not use ./gradlew testDebug or connectedDebugAndroidTest as the gate for iOS or web."
fi

if has_any 'iosApp/Podfile' 'iosApp/Podfile.lock'; then
  note_skip "Podfile changed. On a Mac: cd iosApp && pod install. Then build from iosApp.xcworkspace."
fi

# --- Device-only reminder ---

if has_any \
  'iosApp/iosApp/Camera/*' \
  'iosApp/iosApp/MediaPipe/*' \
  'iosApp/iosApp/Tracking/GazeTrackingManager.swift' \
  'iosApp/iosApp/Tracking/HeadPoseTracker.swift' \
  'iosApp/iosApp/Media/*' \
  'iosApp/iosApp/Game/*' \
  'web/src/tracking/faceLandmarkerClient.ts' \
  'web/src/tracking/poseLandmarkerClient.ts' \
  'web/src/tracking/gestureRecognizerClient.ts' \
  'web/src/tracking/cameraAccess.ts'
then
  note_skip "Camera, MediaPipe, on-screen gaze, BLE, TTS audio, YouTube, and games need a physical iPad or Safari with a camera. The simulator and a passing unit test do not prove them. Manual checklist: TESTING_GUIDE.md."
fi

# --- Web commands (Linux and Mac) ---

web_sources=()
if has 'web/*'; then
  for f in "${files[@]}"; do
    case "$f" in
      web/*.md) ;;
      web/*)
        if [[ -f "$f" ]]; then
          web_sources+=("$f")
        fi
        ;;
    esac
  done
fi

if [[ ${#web_sources[@]} -gt 0 ]]; then
  if [[ ! -x web/node_modules/.bin/tsc ]]; then
    note_skip "web typecheck. web/node_modules/.bin/tsc is missing. From web/: npm ci   (or bash .cursor/install.sh). This is a missing tool, not a failed test."
  else
    say "RUN: web-typecheck"
    say "CMD: cd web && npx tsc -b --pretty false"
    if bash -c 'cd web && npx tsc -b --pretty false' >"$logdir/web-typecheck.log" 2>&1; then
      say "PASS: web-typecheck"
    else
      other_errors="$(grep 'error TS' "$logdir/web-typecheck.log" | grep -v "Cannot find module 'vitest'" || true)"
      vitest_errors="$(grep "Cannot find module 'vitest'" "$logdir/web-typecheck.log" || true)"
      if [[ ! -d web/node_modules/vitest && -z "$other_errors" && -n "$vitest_errors" ]]; then
        note_skip "web typecheck. The only errors are missing vitest types because web dependencies are incomplete. From web/: npm ci. This is not a type error in the app."
      else
        say "FAIL: web-typecheck (last 40 lines; full log: $logdir/web-typecheck.log)"
        tail -n 40 "$logdir/web-typecheck.log" || true
        status=1
      fi
    fi
  fi

  lint_files=()
  for f in "${web_sources[@]}"; do
    case "$f" in
      web/*.ts|web/*.tsx|web/*.js|web/*.jsx) lint_files+=("${f#web/}") ;;
    esac
  done
  if [[ ${#lint_files[@]} -gt 0 ]]; then
    if [[ ! -x web/node_modules/.bin/eslint ]]; then
      note_skip "eslint. Install web dependencies with npm ci in web/."
    else
      run_cmd web-lint bash -c 'cd web && npx eslint --max-warnings 0 "$@"' _ "${lint_files[@]}"
    fi
  fi

  if [[ ! -d web/node_modules/vitest ]]; then
    note_skip "web unit tests. vitest is not installed. From web/: npm ci. Do not report unit tests as passed."
  else
    run_cmd web-unit npm --prefix web test
  fi
fi

# --- Kotlin / iOS ---

needs_kotlin=0
needs_ios_tests=0
if has_any 'shared/*' 'iosApp/*.swift' 'iosApp/iosApp/*' 'iosApp/iosAppTests/*'; then
  if has 'shared/*'; then
    needs_kotlin=1
  fi
  if has_any 'iosApp/*.swift' 'iosApp/iosApp/*' 'iosApp/iosAppTests/*'; then
    needs_ios_tests=1
  fi
fi

only_testing=()
add_test() {
  local class_name="$1"
  local existing
  for existing in "${only_testing[@]+"${only_testing[@]}"}"; do
    [[ "$existing" == "$class_name" ]] && return 0
  done
  only_testing+=("$class_name")
}

if has_any 'iosApp/iosApp/Tracking/DwellSelectionManager.swift' 'iosApp/iosAppTests/DwellSelectionManagerTests.swift'; then
  add_test iosAppTests/DwellSelectionManagerTests
fi
if has_any 'iosApp/iosApp/Tracking/ArmRaiseDetector.swift' 'iosApp/iosAppTests/ArmRaiseDetectorTests.swift'; then
  add_test iosAppTests/ArmRaiseDetectorTests
fi
if has_any 'iosApp/iosApp/Tracking/HandGestureDetector.swift' 'iosApp/iosAppTests/HandGestureDetectorTests.swift'; then
  add_test iosAppTests/HandGestureDetectorTests
fi
if has_any 'iosApp/iosApp/Tracking/AACScannerProtocol.swift' 'iosApp/iosAppTests/AACScannerProtocolTests.swift'; then
  add_test iosAppTests/AACScannerProtocolTests
fi
if has_any 'iosApp/iosApp/Tracking/ESP32SwitchOutputManager.swift' 'iosApp/iosAppTests/ESP32SwitchOutputTests.swift'; then
  add_test iosAppTests/ESP32SwitchOutputTests
fi
if has_any 'iosApp/iosApp/Tracking/SwitchControlManager.swift' 'iosApp/iosAppTests/SwitchControlDedupeTests.swift'; then
  add_test iosAppTests/SwitchControlDedupeTests
fi
if has_any 'iosApp/iosApp/Utils/TTSManager.swift' 'iosApp/iosAppTests/TTSManagerTests.swift'; then
  add_test iosAppTests/TTSManagerTests
fi
if has_any 'iosApp/iosApp/Utils/MediaStorage.swift' 'iosApp/iosAppTests/MediaStorageTests.swift'; then
  add_test iosAppTests/MediaStorageTests
fi
if has_any 'iosApp/iosApp/Data/Models/PhraseStyleExtensions.swift' 'iosApp/iosAppTests/PhraseStyleTests.swift'; then
  add_test iosAppTests/PhraseStyleTests
fi
if has_any 'iosApp/iosApp/PhrasePack/*' 'iosApp/iosAppTests/PhrasePackImporterTests.swift' 'iosApp/iosAppTests/PhrasePackExporterTests.swift' 'iosApp/iosAppTests/PhrasePackPathTests.swift'; then
  add_test iosAppTests/PhrasePackImporterTests
  add_test iosAppTests/PhrasePackExporterTests
  add_test iosAppTests/PhrasePackPathTests
fi
if has_any 'iosApp/iosApp/Utils/LocalizationHelper.swift' 'iosApp/iosAppTests/LocalizationHelperTests.swift'; then
  add_test iosAppTests/LocalizationHelperTests
fi
if has_any 'iosApp/iosApp/Utils/AppSettings.swift' 'iosApp/iosAppTests/AppSettingsTests.swift'; then
  add_test iosAppTests/AppSettingsTests
  note_review "AppSettingsTests writes AppSettings.shared and accepts symbolCount 2-9. The product UI is 1-4. A pass does not prove clamping."
fi
if has_any 'iosApp/iosApp/Data/DatabaseManager.swift' 'shared/src/commonMain/sqldelight/*' 'iosApp/iosAppTests/DatabaseTests.swift'; then
  add_test iosAppTests/DatabaseTests
  note_review "DatabaseTests uses DatabaseManager.shared.db. The comment says in-memory; the code uses the shared database."
fi

ios_cmd="xcodebuild test -workspace iosApp/iosApp.xcworkspace -scheme iosApp -destination 'platform=iOS Simulator,name=<an iPad>'"
if [[ ${#only_testing[@]} -gt 0 ]]; then
  for class_name in "${only_testing[@]}"; do
    ios_cmd+=" -only-testing:${class_name}"
  done
elif [[ "$needs_ios_tests" -eq 1 ]]; then
  ios_cmd+=" -only-testing:iosAppTests"
fi

if [[ "$needs_ios_tests" -eq 1 ]]; then
  if command -v xcodebuild >/dev/null 2>&1; then
    note_skip "Xcode is on this machine. The script does not launch the simulator. Run, after 'source setjava.sh': $ios_cmd"
  else
    note_skip "iOS compile and iosAppTests. This machine has no Xcode. On a Mac, after 'source setjava.sh' (JDK 17): $ios_cmd"
    note_skip "The iosApp scheme is not committed under xcshareddata/xcschemes. If -scheme iosApp fails, run: xcodebuild -workspace iosApp/iosApp.xcworkspace -list"
  fi
fi

if [[ "$needs_kotlin" -eq 1 ]]; then
  say "There is no commonTest source under shared/. A Gradle test task will not check gaze math."
  if command -v xcodebuild >/dev/null 2>&1; then
    note_skip "Kotlin/Native iOS framework. Run: source setjava.sh && ./gradlew :shared:linkDebugFrameworkIosSimulatorArm64"
  else
    note_skip "Kotlin/Native iOS framework. This machine cannot link it. On a Mac with JDK 17: source setjava.sh && ./gradlew :shared:linkDebugFrameworkIosSimulatorArm64"
  fi
fi

say "-----"
if [[ "$status" -ne 0 ]]; then
  say "VERDICT: FAIL"
  exit 1
fi
if [[ "$review" -ne 0 ]]; then
  say "VERDICT: PASS_WITH_REVIEW"
  say "Exit 3 means the commands that ran passed. The REVIEW and NOT RUN lines are still open. Resolve each one in the reply."
  exit 3
fi
say "VERDICT: PASS"
exit 0
