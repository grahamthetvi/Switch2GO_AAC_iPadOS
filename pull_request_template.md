## Description

What does this PR do, and why?

## Screenshots / recordings

If this changes user-facing UI, include before/after.

## Test plan

How was this verified? Tick what you actually ran. `scripts/verify-changed.sh` prints the commands for the files you changed.

- [ ] `scripts/verify-changed.sh` (web typecheck and unit tests when `web/` changed; preset drift check when presets changed)
- [ ] iOS unit tests on a Mac, from `iosApp/iosApp.xcworkspace` (not the `.xcodeproj`), JDK 17 (`source setjava.sh`)
- [ ] Sibling file compared when gaze, dwell, head, arm, hand, settings, speech, games, or storage changed on only one of iOS / web / `shared`
- [ ] Manual iPad pass for camera, gaze, dwell, gestures, or ESP32 switches
- [ ] Manual Safari pass when the web UI changed

`app/` is legacy Android. `./gradlew testDebug` is not the gate for iOS or web.

## Accessibility impact

- [ ] VoiceOver / TalkBack labels and hints reviewed
- [ ] Eye gaze / dwell / switch input paths verified for any changed surface
- [ ] Dynamic Type / large content scaling still works

## Risk / rollback

- [ ] Touches SQLDelight (`shared/src/commonMain/sqldelight`) or web Dexie (`web/src/data/db.ts`)
- [ ] Touches CI or release pipelines
- [ ] None of the above
