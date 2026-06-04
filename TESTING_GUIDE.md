# Switch2Go Testing Guide

Manual QA for **iOS** and **Web**. Android (`app/`) is legacy and not covered here.

## Before you test

### iOS

- Physical **iPad** for camera, gaze, head, gesture, and switch tests (simulator: UI only).
- `pod install` completed; app builds from `iosApp.xcworkspace`.
- For ESP32 switches: paired in **Settings → Bluetooth**; keys `1`–`4` configured in firmware.

### Web

- Models in `web/public/models/` (see root README) or use CI-downloaded assets.
- Prefer **Safari on iPad** for production-like behavior.
- Use **HTTPS or localhost** so camera APIs work.

---

## iOS checklist

### Core AAC

- [ ] Launch: categories grid loads with presets
- [ ] Open category → phrases page; paging matches **symbol count** (1–4)
- [ ] Tap phrase → TTS speaks; phrase appears in Recents if applicable
- [ ] CVI colors apply per position (Settings → CVI Display)

### Settings & data

- [ ] Edit Categories & Phrases: add custom category and phrase
- [ ] Hide/reorder category or phrase; changes persist after relaunch
- [ ] Phrase style: color, border, emoji, image
- [ ] Backup not required for this pass; optional export/import smoke test
- [ ] Reset App restores defaults (use test device)

### Selection modes (device + camera)

- [ ] **Touch only** — no camera required; dwell off or irrelevant
- [ ] **Eye gaze** — cursor moves; dwell selects tile
- [ ] **Head tracking** — cursor moves with head
- [ ] **Arm raise** — with **2 symbols** on page, left/right arm maps to tiles
- [ ] **Hand gesture** — 2-symbol page; open/close hand selects side
- [ ] Recenter cursor from Settings
- [ ] Advanced eye: change smoothing / 2D vs 3D; no crash

### Switches (optional)

- [ ] External switches enabled; key `1`–`4` activate tiles (Switch to Phrase)
- [ ] Scan & Select: key `2` advances, key `1` selects
- [ ] Serial monitor shows HID events when iPad connected

### Media & games (if configured on test phrases)

- [ ] Video/audio phrase plays after delay (Timing & Sensitivity)
- [ ] Game launches after phrase; exit control works

### Regression

- [ ] Rotate iPad; layout usable in landscape
- [ ] Deny camera → app falls back gracefully (message or touch)
- [ ] No network required for core AAC offline

---

## Web checklist

### Core AAC

- [ ] Load deployed or `npm run dev` URL; categories and phrases work
- [ ] Symbol count 1–4; colors per position
- [ ] TTS on phrase select (first interaction may need user gesture for audio unlock)

### Settings & data

- [ ] Settings hub: all linked screens open
- [ ] Edit categories/phrases CRUD
- [ ] Backup export → clear site data or new browser profile → import restores data
- [ ] Language change updates UI strings

### Selection modes (Safari + camera)

- [ ] Touch only
- [ ] Eye gaze + dwell
- [ ] Head tracking
- [ ] Arm raise / hand gesture on **2-tile** page
- [ ] Keyboard **1**–**4** selects tiles when focus on phrases view
- [ ] Troubleshooting page matches observed behavior

### Deploy / CI

- [ ] `cd web && npm run build` succeeds locally
- [ ] GitHub Pages assets load (no 404 for `/models/*.task` after deploy)

---

## Reporting issues

Include: platform (iOS version / Safari version), selection mode, symbol count, steps, and whether camera or switches were in use.

Contact: grahamthetvi@icloud.com — or open a GitHub issue.
