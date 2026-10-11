#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "Building release binary..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/NotchClone"

APP_BUNDLE="build/NotchClone.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "Creating bundle layout at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/NotchClone"
chmod +x "$MACOS_DIR/NotchClone"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"

echo "Signing bundle..."
codesign --force --sign - "$APP_BUNDLE"

echo "Bundling complete: $APP_BUNDLE"
