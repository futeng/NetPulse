#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/NetPulse"
DIST_DIR="$ROOT_DIR/dist"
ARCH="${1:-${NETPULSE_ARCH:-$(uname -m)}}"
APP_DIR="${2:-$DIST_DIR/NetPulse.app}"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_SOURCE="$PACKAGE_DIR/Resources/Info.plist"
ICON_SOURCE="$PACKAGE_DIR/Resources/AppIcon.icns"
VERSION="${NETPULSE_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST_SOURCE")}"
BUILD_NUMBER="${NETPULSE_BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST_SOURCE")}"

build_arch() {
    local target_arch="$1"
    swift build \
        -c release \
        --package-path "$PACKAGE_DIR" \
        --triple "${target_arch}-apple-macosx13.0"
    echo "$PACKAGE_DIR/.build/${target_arch}-apple-macosx/release/NetPulse"
}

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

case "$ARCH" in
    arm64|x86_64)
        cp "$(build_arch "$ARCH" | tail -1)" "$MACOS_DIR/NetPulse"
        ;;
    universal)
        ARM_BINARY="$(build_arch arm64 | tail -1)"
        INTEL_BINARY="$(build_arch x86_64 | tail -1)"
        lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$MACOS_DIR/NetPulse"
        ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        echo "Use arm64, x86_64, or universal." >&2
        exit 2
        ;;
esac

cp "$PLIST_SOURCE" "$CONTENTS_DIR/Info.plist"
cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/NetPulse"
codesign --force --deep --sign "${CODE_SIGN_IDENTITY:--}" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"
