#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/dist/NetPulse.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/NetPulse.app"

"$ROOT_DIR/scripts/build_netpulse.sh"
mkdir -p "$INSTALL_DIR"
/usr/bin/ditto "$SOURCE_APP" "$INSTALLED_APP"
/usr/bin/codesign --force --deep --sign - "$INSTALLED_APP"
/usr/bin/open "$INSTALLED_APP"

echo "$INSTALLED_APP"
