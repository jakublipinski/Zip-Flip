#!/bin/zsh
# Development loop: generate the project, build the watch app for a real
# watch, install it on the watch named in secrets.env. One command per
# iteration. Output goes to run.log; only errors and the outcome are printed.
#
#   scripts/run.sh
#
# The build targets the generic watchOS destination so it never waits on the
# watch. Only the install needs the watch awake, unlocked, on Wi-Fi and near
# the Mac; it is retried a few times.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
cd "$(dirname "$0")/.."

if [[ ! -f secrets.env ]]; then
  echo "secrets.env is missing. Copy secrets.env.example and fill in WATCH_UDID and DEVELOPMENT_TEAM." >&2
  exit 1
fi
source ./secrets.env
: "${WATCH_UDID:?set WATCH_UDID in secrets.env}" "${DEVELOPMENT_TEAM:?set DEVELOPMENT_TEAM in secrets.env}"

LOG=run.log
: > "$LOG"

echo "generating project"
xcodegen generate >> "$LOG" 2>&1

echo "building ZipFlipWatch (Debug, watchOS)"
if ! xcodebuild -project ZipFlip.xcodeproj -scheme ZipFlipWatch -configuration Debug \
    -destination "generic/platform=watchOS" -allowProvisioningUpdates \
    -derivedDataPath ./build DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" build >> "$LOG" 2>&1; then
  grep -E "error:|error " "$LOG" | head -n 20 >&2 || true
  echo "build failed, see $LOG" >&2
  exit 1
fi

APP=./build/Build/Products/Debug-watchos/ZipFlipWatch.app
if [[ ! -d "$APP" ]]; then
  echo "build produced no app at $APP, see $LOG" >&2
  exit 1
fi

echo "installing on watch $WATCH_UDID"
for attempt in 1 2 3 4 5; do
  if xcrun devicectl device install app --device "$WATCH_UDID" "$APP" >> "$LOG" 2>&1; then
    echo "installed"
    exit 0
  fi
  echo "install attempt $attempt failed; is the watch awake, unlocked, on Wi-Fi and near the Mac? retrying in 10 s"
  sleep 10
done
echo "install failed, see $LOG" >&2
if grep -q "rejected the Bluetooth connection attempt" "$LOG"; then
  cat >&2 <<'HINT'
The watch refused the connection, so its pairing with this Mac is stale
(a watchOS upgrade requires pairing again). In Xcode open Device Hub,
click +, choose Pair Nearby Device and pick Apple Watch; leave the sheet
open. On the watch: Settings > Privacy & Security > Developer Mode, scroll
to the bottom, tap this Mac, tap Pair, enter the PIN Device Hub shows.
HINT
fi
exit 1
