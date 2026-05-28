#!/usr/bin/env bash
# Builds the executable with SwiftPM, wraps it in a .app bundle, and ad-hoc
# code-signs it so macOS doesn't refuse to launch the unsigned binary.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
APP_NAME="MonitorLayout"
BUILD_DIR=".build"
BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "Building ${APP_NAME} (${CONFIG})..."
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)/${APP_NAME}"
if [[ ! -x "${BIN_PATH}" ]]; then
    echo "Binary not found at ${BIN_PATH}" >&2
    exit 1
fi

echo "Assembling ${BUNDLE}..."
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"
cp "${BIN_PATH}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${BUNDLE}/Contents/Info.plist"

echo "Ad-hoc signing..."
codesign --force --deep --sign - "${BUNDLE}"

echo
echo "Built: ${BUNDLE}"
echo "Run from build dir:  open ${BUNDLE}"
echo "Install to /Applications:  ./scripts/install.sh"
