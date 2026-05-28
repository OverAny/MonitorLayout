#!/usr/bin/env bash
# Builds (if needed) and installs MonitorLayout.app into /Applications so it
# shows up in Launchpad, Spotlight, and is dock-droppable.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="MonitorLayout"
BUNDLE=".build/${APP_NAME}.app"
DEST="/Applications/${APP_NAME}.app"

if [[ ! -d "${BUNDLE}" ]]; then
    echo "Building first..."
    ./scripts/make-app.sh
fi

if pgrep -x "${APP_NAME}" >/dev/null; then
    echo "Quitting running ${APP_NAME}..."
    osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || pkill -x "${APP_NAME}" || true
    sleep 1
fi

echo "Installing to ${DEST}..."
if [[ -d "${DEST}" ]]; then
    rm -rf "${DEST}"
fi

# /Applications usually doesn't need sudo for user installs, but fall back if it does.
if ! cp -R "${BUNDLE}" "${DEST}" 2>/dev/null; then
    echo "Need admin to write to /Applications..."
    sudo cp -R "${BUNDLE}" "${DEST}"
fi

# Strip the quarantine attribute so Gatekeeper doesn't block the ad-hoc-signed app.
xattr -dr com.apple.quarantine "${DEST}" 2>/dev/null || true

echo
echo "Installed: ${DEST}"
echo "Launch with:  open -a ${APP_NAME}"
echo "Or find it in Launchpad / Spotlight."
