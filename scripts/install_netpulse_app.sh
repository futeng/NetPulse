#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/dist/NetPulse.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/NetPulse.app"

"$ROOT_DIR/scripts/build_netpulse.sh"

if /usr/bin/pgrep -x NetPulse >/dev/null; then
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && /bin/kill "$pid"
  done < <(/usr/bin/pgrep -x NetPulse)

  for _ in {1..20}; do
    /usr/bin/pgrep -x NetPulse >/dev/null || break
    /bin/sleep 0.2
  done

  if /usr/bin/pgrep -x NetPulse >/dev/null; then
    echo "Unable to stop the running NetPulse process." >&2
    exit 1
  fi
fi

mkdir -p "$INSTALL_DIR"
/usr/bin/ditto "$SOURCE_APP" "$INSTALLED_APP"
/usr/bin/codesign --force --deep --sign - "$INSTALLED_APP"
/usr/bin/open "$INSTALLED_APP"

echo "$INSTALLED_APP"
