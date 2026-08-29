#!/bin/sh
# Fallback if Xcode Cloud looks at the Git root instead of iosApp/.
set -e
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/../iosApp/ci_scripts/ci_pre_xcodebuild.sh"
