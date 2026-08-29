#!/bin/sh
# Fail fast if CocoaPods did not generate the xcconfigs the project references.
set -e

if [ -n "${CI_PRIMARY_REPOSITORY_PATH:-}" ]; then
  REPO_ROOT="$CI_PRIMARY_REPOSITORY_PATH"
elif [ -n "${CI_WORKSPACE:-}" ]; then
  REPO_ROOT="$CI_WORKSPACE"
else
  SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
  REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
fi

XCCONFIG="$REPO_ROOT/iosApp/Pods/Target Support Files/Pods-iosApp/Pods-iosApp.release.xcconfig"
if [ ! -f "$XCCONFIG" ]; then
  echo "error: CocoaPods release xcconfig is missing. ci_post_clone.sh must run pod install." >&2
  echo "  $XCCONFIG" >&2
  exit 1
fi

echo "OK: CocoaPods xcconfig present"
