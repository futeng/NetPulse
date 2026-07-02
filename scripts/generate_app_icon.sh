#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_PATH="${1:-$ROOT_DIR/NetPulse/Resources/Brand/NetPulseMascot.png}"
OUTPUT_PATH="${2:-$ROOT_DIR/NetPulse/Resources/AppIcon.icns}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/netpulse-icon.XXXXXX")"
TIFF_PATH="$WORK_DIR/AppIcon.tiff"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [[ ! -f "$SOURCE_PATH" ]]; then
    echo "Icon source not found: $SOURCE_PATH" >&2
    exit 1
fi

render_icon() {
    local size="$1"
    sips -z "$size" "$size" -s format tiff "$SOURCE_PATH" \
        --out "$WORK_DIR/icon-$size.tiff" \
        >/dev/null
}

for size in 16 32 48 128 256 512 1024; do
    render_icon "$size"
done

tiffutil -cat \
    "$WORK_DIR/icon-16.tiff" \
    "$WORK_DIR/icon-32.tiff" \
    "$WORK_DIR/icon-48.tiff" \
    "$WORK_DIR/icon-128.tiff" \
    "$WORK_DIR/icon-256.tiff" \
    "$WORK_DIR/icon-512.tiff" \
    "$WORK_DIR/icon-1024.tiff" \
    -out "$TIFF_PATH" \
    >/dev/null 2>&1

tiff2icns "$TIFF_PATH" "$OUTPUT_PATH"
echo "$OUTPUT_PATH"
