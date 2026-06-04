#!/bin/bash
set -e

# Script to code sign the VocableShared framework for iOS device deployment
# This is required for TestFlight and App Store distribution

FRAMEWORK_PATH="$1"
IDENTITY="${2:-Apple Development}"

if [ -z "$FRAMEWORK_PATH" ]; then
    echo "Usage: $0 <framework_path> [identity]"
    echo "Example: $0 shared/build/bin/iosArm64/debugFramework/VocableShared.framework"
    exit 1
fi

if [ ! -d "$FRAMEWORK_PATH" ]; then
    echo "Error: Framework not found at $FRAMEWORK_PATH"
    exit 1
fi

echo "Signing framework: $FRAMEWORK_PATH"
echo "Using identity: $IDENTITY"

# Sign the framework
codesign --force --sign "$IDENTITY" --preserve-metadata=identifier,entitlements,flags --generate-entitlement-der "$FRAMEWORK_PATH"

# Verify the signature
echo ""
echo "Verifying signature..."
codesign --verify --verbose "$FRAMEWORK_PATH"

echo ""
echo "OK: Framework signed successfully."
