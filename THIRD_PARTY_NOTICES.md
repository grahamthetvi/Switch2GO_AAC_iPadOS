# Third-Party Software Notices

Switch2Go includes open-source and other third-party software. **Your application code is [MIT licensed](LICENSE).** Third-party components keep their own licenses.

The canonical, app-bundled notice text (including the full **Apache License 2.0** text required for MediaPipe) is in:

- [`third-party-notices.txt`](third-party-notices.txt) — source copy for all platforms
- **In-app:** Settings → **Open-Source Licenses** (Android, iOS, web)
- **Web npm inventory:** [`web/license-report-web.json`](web/license-report-web.json)

## MediaPipe (Apache 2.0)

Switch2Go ships **MediaPipe Tasks Vision** for on-device face/iris tracking (and additional task models on web).

| Platform | Package |
|----------|---------|
| Android | `com.google.mediapipe:tasks-vision` |
| iOS | `MediaPipeTasksVision`, `MediaPipeTasksCommon` (CocoaPods) |
| Web | `@mediapipe/tasks-vision` |

- **Copyright:** The MediaPipe Authors  
- **Project:** https://github.com/google/mediapipe  
- **License:** [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)

**Your obligations when distributing the app:** include Apache 2.0 license text and appropriate copyright/NOTICE attributions for MediaPipe (provided in `third-party-notices.txt`). You do **not** need to relicense all of Switch2Go as GPL.

## Other major dependencies

| Component | License | Used for |
|-----------|---------|----------|
| AndroidX / Jetpack / CameraX / Room | Apache-2.0 | Android UI, camera, persistence |
| Google ARCore / Sceneform | Apache-2.0 | Android head tracking |
| Koin, Coroutines, Moshi, SQLDelight, Timber | Apache-2.0 | Android/KMP infrastructure |
| `@mintplex-labs/piper-tts-web` | MIT | Web TTS (optional) |
| `onnxruntime-web` | MIT | Web ML inference (Piper) |
| React, Dexie, Zustand | MIT / Apache-2.0 | Web UI and storage |

## Updating this document

When you add or upgrade a dependency:

1. Re-run license checks (`web/license-report-web.json`, Gradle license plugin when Java 17/21 is available).
2. Update `third-party-notices.txt` if a **shipped** library or license changes.
3. Re-copy bundled copies to `iosApp/Resources/`, `web/public/`, and `app/src/main/assets/`.

---

*This file is for repository documentation. The legally relevant bundled text is `third-party-notices.txt`.*
