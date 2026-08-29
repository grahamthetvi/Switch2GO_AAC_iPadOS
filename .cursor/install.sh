#!/usr/bin/env bash
# Idempotent Cloud Agent install for the Switch2Go web app.
# Refreshes npm dependencies and restores the MediaPipe model assets that are
# not committed to the repository (see README "Large files").
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../web"

echo "OK: installing web dependencies (npm ci)"
npm ci

MODELS_DIR="public/models"
mkdir -p "$MODELS_DIR"

download_model() {
  local url="$1" dest="$2"
  if [ -s "$dest" ]; then
    echo "OK: $dest already present, skipping download"
    return 0
  fi
  echo "OK: downloading $dest"
  curl -fsSL "$url" -o "$dest"
}

download_model \
  "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task" \
  "$MODELS_DIR/face_landmarker.task"
download_model \
  "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task" \
  "$MODELS_DIR/pose_landmarker_lite.task"
download_model \
  "https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task" \
  "$MODELS_DIR/gesture_recognizer.task"

echo "OK: Switch2Go web environment ready"
