#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
EXPECTED_BUNDLE_ID="${NETPULSE_BUNDLE_ID:-com.ftpai.futeng.NetPulse}"
EXPECTED_SIGNING_MODE="${NETPULSE_EXPECTED_SIGNING_MODE:-adhoc}"

if (( $# > 1 )); then
    echo "Usage: $0 [path-to-dmg]" >&2
    exit 2
fi

if (( $# == 1 )); then
    DMG_PATH="${1:A}"
else
    DMG_CANDIDATES=("$DIST_DIR"/NetPulse-*-universal.dmg(N))
    if (( ${#DMG_CANDIDATES[@]} != 1 )); then
        echo "Expected exactly one Universal DMG in $DIST_DIR." >&2
        exit 2
    fi
    DMG_PATH="${DMG_CANDIDATES[1]}"
fi

CHECKSUM_PATH="$DMG_PATH.sha256"
MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/netpulse-verify.XXXXXX")"
ATTACHED=false

cleanup() {
    if [[ "$ATTACHED" == true ]]; then
        hdiutil detach "$MOUNT_DIR" -quiet ||
            hdiutil detach "$MOUNT_DIR" -force -quiet ||
            true
    fi
    rmdir "$MOUNT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

if [[ ! -f "$DMG_PATH" ]]; then
    echo "DMG not found: $DMG_PATH" >&2
    exit 1
fi

if [[ ! -f "$CHECKSUM_PATH" ]]; then
    echo "Checksum not found: $CHECKSUM_PATH" >&2
    exit 1
fi

(
    cd "${DMG_PATH:h}"
    shasum -a 256 -c "${CHECKSUM_PATH:t}"
)

hdiutil verify "$DMG_PATH"
hdiutil attach "$DMG_PATH" \
    -readonly \
    -nobrowse \
    -mountpoint "$MOUNT_DIR" \
    -quiet
ATTACHED=true

APP_PATH="$MOUNT_DIR/NetPulse.app"
BINARY_PATH="$APP_PATH/Contents/MacOS/NetPulse"

if [[ ! -d "$APP_PATH" || ! -x "$BINARY_PATH" ]]; then
    echo "NetPulse.app is missing or incomplete inside the DMG." >&2
    exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
SIGNATURE_DETAILS="$(codesign -dvvv "$APP_PATH" 2>&1)"

if [[ "$EXPECTED_SIGNING_MODE" == adhoc &&
      "$SIGNATURE_DETAILS" != *"Signature=adhoc"* ]]; then
    echo "Expected an ad-hoc signature, but the DMG contains another signing mode." >&2
    exit 1
fi

ACTUAL_BUNDLE_ID="$(/usr/libexec/PlistBuddy \
    -c 'Print :CFBundleIdentifier' \
    "$APP_PATH/Contents/Info.plist")"
if [[ "$ACTUAL_BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]]; then
    echo "Unexpected Bundle ID: $ACTUAL_BUNDLE_ID" >&2
    exit 1
fi

lipo "$BINARY_PATH" -verify_arch arm64 x86_64

echo "Verified DMG: $DMG_PATH"
echo "Bundle ID: $ACTUAL_BUNDLE_ID"
echo "Architectures: $(lipo -archs "$BINARY_PATH")"
echo "Signing mode: $EXPECTED_SIGNING_MODE"
