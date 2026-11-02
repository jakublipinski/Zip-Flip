#!/bin/zsh
# Build the watch app in Release for the simulator and launch it on every
# available watch simulator, smallest screen first, for a by-hand review of
# each size. Release, not Debug, because Release is what App Review and
# customers get.
#
#   scripts/check-ui.sh            build, install and launch everywhere
#   scripts/check-ui.sh --erase    erase each simulator first (true first launch)
#   scripts/check-ui.sh --only 40  only simulators whose name contains "40"
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
cd "$(dirname "$0")/.."

ERASE=0
ONLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --erase) ERASE=1 ;;
    --only) ONLY="$2"; shift ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done

BUNDLE_ID=app.zip-flip.ZipFlip.watchkitapp
LOG=check-ui.log
: > "$LOG"

echo "generating project"
xcodegen generate >> "$LOG" 2>&1

echo "building ZipFlipWatch (Release, watchOS Simulator)"
if ! xcodebuild -project ZipFlip.xcodeproj -scheme ZipFlipWatch -configuration Release \
    -destination "generic/platform=watchOS Simulator" -derivedDataPath ./build \
    CODE_SIGNING_ALLOWED=NO build >> "$LOG" 2>&1; then
  grep -E "error:|error " "$LOG" | head -n 20 >&2 || true
  echo "build failed, see $LOG" >&2
  exit 1
fi
APP=./build/Build/Products/Release-watchsimulator/ZipFlipWatch.app
[[ -d "$APP" ]] || { echo "no app at $APP, see $LOG" >&2; exit 1; }

# Available watchOS simulators as "udid<TAB>name", sorted by the mm size in the name.
SIMS=$(xcrun simctl list devices available \
  | awk '/-- watchOS/{f=1; next} /^-- /{f=0} f' \
  | sed -nE 's/^ *(.*) \(([0-9A-F-]{36})\) \(.*$/\2\t\1/p' \
  | awk -F'\t' '{ mm = $2; gsub(/.*\(/, "", mm); gsub(/mm.*/, "", mm); print mm "\t" $0 }' \
  | sort -n | cut -f2-)

if [[ -n "$ONLY" ]]; then
  SIMS=$(printf '%s\n' "$SIMS" | grep -i -- "$ONLY" || true)
fi
if [[ -z "$SIMS" ]]; then
  echo "no matching watchOS simulators (xcrun simctl list devices available)" >&2
  exit 1
fi

open -a Simulator
printf '%s\n' "$SIMS" | while IFS=$'\t' read -r UDID NAME; do
  echo "== $NAME"
  if [[ $ERASE -eq 1 ]]; then
    xcrun simctl shutdown "$UDID" >> "$LOG" 2>&1 || true
    xcrun simctl erase "$UDID" >> "$LOG" 2>&1
  fi
  xcrun simctl boot "$UDID" >> "$LOG" 2>&1 || true
  xcrun simctl bootstatus "$UDID" -b >> "$LOG" 2>&1
  xcrun simctl install "$UDID" "$APP" >> "$LOG" 2>&1
  xcrun simctl launch "$UDID" "$BUNDLE_ID" >> "$LOG" 2>&1
  echo "   launched $BUNDLE_ID"
done
echo "done; review each size by hand, smallest first"
