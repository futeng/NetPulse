#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/NetPulse"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/NetPulse.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

swift build -c release --package-path "$PACKAGE_DIR"
BIN_DIR="$(swift build -c release --package-path "$PACKAGE_DIR" --show-bin-path)"

mkdir -p "$MACOS_DIR"
cp "$BIN_DIR/NetPulse" "$MACOS_DIR/NetPulse"
cp "$PACKAGE_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/NetPulse"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
