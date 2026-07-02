#!/bin/zsh
set -euo pipefail

APP_PATH="${1:-$HOME/Applications/NetPulse.app}"

if [[ ! -d "$APP_PATH" ]]; then
    echo "NetPulse app not found: $APP_PATH" >&2
    exit 1
fi

status_item_count() {
    /usr/bin/osascript -e \
        'tell application "System Events" to tell process "ControlCenter" to return count of menu bar items of menu bar 1'
}

wait_for_process_exit() {
    for _ in {1..20}; do
        /usr/bin/pgrep -x NetPulse >/dev/null || return 0
        /bin/sleep 0.2
    done
    return 1
}

wait_for_process_start() {
    for _ in {1..20}; do
        /usr/bin/pgrep -x NetPulse >/dev/null && return 0
        /bin/sleep 0.25
    done
    return 1
}

before_count="$(status_item_count)"

while IFS= read -r pid; do
    [[ -n "$pid" ]] && /bin/kill "$pid"
done < <(/usr/bin/pgrep -x NetPulse || true)

if ! wait_for_process_exit; then
    echo "NetPulse status bar self-check failed: process did not exit." >&2
    exit 1
fi

after_quit_count="$before_count"
for _ in {1..15}; do
    after_quit_count="$(status_item_count)"
    (( after_quit_count < before_count )) && break
    /bin/sleep 0.2
done

/usr/bin/open -n "$APP_PATH"
if ! wait_for_process_start; then
    echo "NetPulse status bar self-check failed: process did not start." >&2
    exit 1
fi

after_open_count="$after_quit_count"
for _ in {1..20}; do
    after_open_count="$(status_item_count)"
    (( after_open_count > after_quit_count )) && break
    /bin/sleep 0.25
done

if (( after_open_count <= after_quit_count )); then
    echo "NetPulse status bar self-check failed: no status item appeared." >&2
    echo "before=$before_count, afterQuit=$after_quit_count, afterOpen=$after_open_count" >&2
    exit 1
fi

echo "NetPulse status bar self-check passed: before=$before_count, afterQuit=$after_quit_count, afterOpen=$after_open_count"
