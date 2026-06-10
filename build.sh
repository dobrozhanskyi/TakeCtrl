#!/usr/bin/env bash
set -euo pipefail

SCHEME="TakeCtrl"
PROJECT="TakeCtrl.xcodeproj"
CONFIGURATION="Release"
BUILD_DIR="$(pwd)/build"
ARCHIVE_PATH="$BUILD_DIR/TakeCtrl.xcarchive"
APP_PATH="$BUILD_DIR/TakeCtrl.app"

cd "$(dirname "$0")"

XCODE_PATH=$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null | head -1)
if [ -z "$XCODE_PATH" ]; then
    echo "ERROR: Xcode.app not found" >&2
    exit 1
fi
export DEVELOPER_DIR="$XCODE_PATH/Contents/Developer"

echo "==> Cleaning build directory"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building $SCHEME ($CONFIGURATION)"
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -destination "platform=macOS" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

APP_SRC=$(find "$BUILD_DIR/DerivedData" -name "TakeCtrl.app" -maxdepth 6 | head -1)
if [ -z "$APP_SRC" ]; then
    echo "ERROR: TakeCtrl.app not found after build" >&2
    exit 1
fi

cp -R "$APP_SRC" "$APP_PATH"
echo "==> Build succeeded: $APP_PATH"
