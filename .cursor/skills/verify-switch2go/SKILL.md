---
name: verify-switch2go
description: >-
  Verifies Switch2Go changes against the iOS, web, and shared-Kotlin copies of
  the same behavior. Use when implementing, fixing, refactoring, or reviewing
  code in this repo, and when asked to test, double-check, prove, or confirm
  that a change is correct. Covers gaze, dwell, head pose, arm raise, hand
  gesture, switches, presets, settings, and which checks can run on Linux
  versus a Mac with Xcode.
---

# Verify Switch2Go

Maintained products are the iPad app (`iosApp/`) and the web app (`web/`). `app/` is legacy Android. Do not use Android tests as the gate.

The map of duplicated behavior is [parity.md](parity.md). Run `scripts/verify-changed.sh` rather than reconstructing the commands.

## Procedure

1. Write the claim you could be wrong about as one sentence a test could fail. Example: "A gaze point in the gutter between two tiles stays on the tile already hovered."
2. List the files you edited and the sibling files from [parity.md](parity.md). Read the siblings. If you do not change them, say why that behavior is platform-specific.
3. Run `scripts/verify-changed.sh` with those paths. With no arguments it uses the git diff, including untracked files.
4. Reply with three sections: **Ran** (command and PASS/FAIL), **Not run** (why, and the Mac or device command), **Sibling review** (what you compared and what you decided). Quote the script's `REVIEW` and `NOT RUN` lines. Do not fold them into a pass.
5. Exit 0 is a pass only when the script prints `VERDICT: PASS`. Exit 3 (`PASS_WITH_REVIEW`) means the commands that ran succeeded and the open lines are still your job. Exit 1 means a command failed.

## What this machine can prove

| Change | Command the script runs here |
| --- | --- |
| `web/` source | `npx tsc -b` and eslint on the changed files, then `npm test` (vitest) |
| `PresetData.kt`, `Category.kt`, or `presets.json` | `node scripts/export-presets.mjs`, then restore the JSON and report a mismatch |
| `iosApp/` Swift or `shared/` Kotlin | Nothing, on Linux. The script prints the Mac command. |

Web unit tests today cover gaze math and arm-raise laterality only (`web/src/tracking/*.test.ts`). They do not cover dwell, settings, pages, or the camera.

`shared/` has `commonTest` dependencies and no `commonTest` sources. There is no Kotlin test task for gaze math. iOS runs that Kotlin inside `VocableShared.framework`.

## iOS, on a Mac

Use the workspace, not the project:

```bash
source setjava.sh
xcodebuild test \
  -workspace iosApp/iosApp.xcworkspace \
  -scheme iosApp \
  -destination 'platform=iOS Simulator,name=<an iPad>' \
  -only-testing:iosAppTests
```

Add one `-only-testing:iosAppTests/<Class>` per class the script names.

- JDK 17 is required. `source setjava.sh` finds it. Java 25 fails the Kotlin framework build with a version error that looks like a code failure. It is not one.
- The `iosApp` scheme is not committed under `xcshareddata/xcschemes`. If `-scheme iosApp` fails, run `xcodebuild -workspace iosApp/iosApp.xcworkspace -list`.
- `.xcodebuildmcp/config.yaml` defaults the simulator to iPhone 17. Symbol layout is an iPad check. Pick an iPad destination.
- The Podfile excludes arm64 for MediaPipe on the simulator. A link error that names arm64 and MediaPipe is that exclusion. Do not treat it as a failed assertion, and do not delete the exclusion unless you have confirmed the pod ships an arm64 simulator slice.
- If using XcodeBuildMCP, read its skill before calling its tools. The server command in `.cursor/mcp.json` is a Mac path and does not start on Linux.
- `iosAppUITests` is a target in the Podfile and has no source directory. Do not plan on UI tests.

## Device-only

A passing unit test or the simulator does not prove:

- camera, face loss, or tracking recovery
- the gaze cursor landing on the phrase the student is looking at
- double-blink recenter
- arm raise or hand gesture from a real body
- ESP32 BLE pairing (keys `1`–`4` after system Bluetooth pairing)
- spoken TTS, YouTube, or games

Those need a physical iPad, or Safari for the web app. The manual list is `TESTING_GUIDE.md`. Say that they were not run.

## Known false greens

- `AppSettingsTests` sets `symbolCount = 5` and accepts 2 through 9. The iOS setter does not clamp. Web `setSymbolCount` clamps to 1–4. Backup import on iOS clamps to 1–4. A green `AppSettingsTests` does not prove the product rule.
- `AppSettingsTests` writes `AppSettings.shared` (UserDefaults on the machine running the test).
- `DatabaseTests` says it uses an in-memory database. The body uses `DatabaseManager.shared.db`.
- Android `./gradlew testDebug` does not exercise iOS or web.

## When you add a test

Add a test when the logic is pure: no camera, no BLE, no SwiftUI, no speech audio.

- Web: `web/src/**/*.test.ts`, run by `npm test`.
- iOS: `iosApp/iosAppTests/<Type>Tests.swift`, same target as the existing tests.
- Do not add a Kotlin `commonTest` unless you also have JDK 17 and a way to run it. Gaze math for iOS lives in `shared/`; the web port has the vitest copies.

## Report shape

```text
Ran:
- web-typecheck: PASS

Not run:
- iosAppTests/DwellSelectionManagerTests: no Xcode on this machine.
  Mac: xcodebuild test ... -only-testing:iosAppTests/DwellSelectionManagerTests

Sibling review:
- REVIEW: iOS dwell changed. Read web/src/tracking/dwellManager.ts.
  Decision: the gutter rule matches the Swift hit test; no web edit.
```
