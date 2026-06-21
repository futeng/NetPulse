#!/bin/zsh
set -euo pipefail

APP_PATH="${1:-$HOME/Applications/NetPulse.app}"

if [[ ! -d "$APP_PATH" ]]; then
    echo "NetPulse app not found: $APP_PATH" >&2
    exit 1
fi

result="$(/usr/bin/osascript <<APPLESCRIPT
on statusItemCount()
  tell application "System Events" to tell process "ControlCenter"
    return count of menu bar items of menu bar 1
  end tell
end statusItemCount

on waitForCountBelow(limitCount)
  repeat with attempt from 1 to 15
    delay 0.2
    set currentCount to statusItemCount()
    if currentCount < limitCount then return currentCount
  end repeat
  return statusItemCount()
end waitForCountBelow

on waitForCountAbove(limitCount)
  repeat with attempt from 1 to 20
    delay 0.25
    set currentCount to statusItemCount()
    if currentCount > limitCount then return currentCount
  end repeat
  return statusItemCount()
end waitForCountAbove

set beforeCount to statusItemCount()
try
  tell application "NetPulse" to quit
end try
set afterQuitCount to waitForCountBelow(beforeCount)

tell application "Finder" to open POSIX file "$APP_PATH"
set afterOpenCount to waitForCountAbove(afterQuitCount)

if afterQuitCount >= beforeCount then
  error "NetPulse quit did not remove a status item. before=" & beforeCount & ", afterQuit=" & afterQuitCount
end if

if afterOpenCount <= afterQuitCount then
  error "NetPulse launch did not add a status item. afterQuit=" & afterQuitCount & ", afterOpen=" & afterOpenCount
end if

return "before=" & beforeCount & ", afterQuit=" & afterQuitCount & ", afterOpen=" & afterOpenCount
APPLESCRIPT
)" || {
    echo "NetPulse status bar self-check failed." >&2
    echo "$result" >&2
    exit 1
}

echo "NetPulse status bar self-check passed: $result"
