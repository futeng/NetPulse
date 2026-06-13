#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PLIST="$ROOT_DIR/NetPulse/Resources/Info.plist"
ARCH="${1:-universal}"
VERSION="${NETPULSE_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")}"
APP_DIR="$DIST_DIR/NetPulse.app"
DMG_NAME="NetPulse-${VERSION}-${ARCH}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/netpulse-dmg.XXXXXX")"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/build_netpulse.sh" "$ARCH" "$APP_DIR"

mkdir -p "$STAGING_DIR/NetPulse"
/usr/bin/ditto "$APP_DIR" "$STAGING_DIR/NetPulse/NetPulse.app"
ln -s /Applications "$STAGING_DIR/NetPulse/Applications"

rm -f "$DMG_PATH" "$DMG_PATH.sha256"
hdiutil create \
    -volname "NetPulse" \
    -srcfolder "$STAGING_DIR/NetPulse" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

(
    cd "$DIST_DIR"
    shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
)

echo "$DMG_PATH"
echo "$DMG_PATH.sha256"
