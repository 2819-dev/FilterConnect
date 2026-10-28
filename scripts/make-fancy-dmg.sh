#!/bin/bash
# Build a classic “Drag Filtr to Applications” DMG window.
# Usage: scripts/make-fancy-dmg.sh /path/to/Filtr.app /path/to/out/Filtr.dmg
set -euo pipefail

APP_SRC="${1:?Filtr.app path required}"
DMG_OUT="${2:?output .dmg path required}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BG_SRC="${ROOT}/Design/dmg-background.png"

if [[ ! -d "${APP_SRC}" ]]; then
  echo "App not found: ${APP_SRC}" >&2
  exit 1
fi
if [[ ! -f "${BG_SRC}" ]]; then
  echo "Background not found: ${BG_SRC}" >&2
  exit 1
fi

STAGE="$(mktemp -d /tmp/filtr-dmg-XXXXXX)"
RW_DMG="${STAGE}/Filtr-rw.dmg"
MOUNT_DIR="${STAGE}/mnt"
VOLUME_NAME="Filtr Installer"
WINDOW_W=660
WINDOW_H=420
ICON_SIZE=96
# Icon positions inside Finder window (icon centers relative to content view)
APP_X=165
APP_Y=210
APPS_X=495
APPS_Y=210

cleanup() {
  if [[ -d "${MOUNT_DIR}" ]]; then
    hdiutil detach "${MOUNT_DIR}" -force >/dev/null 2>&1 || true
  fi
  rm -rf "${STAGE}"
}
trap cleanup EXIT

mkdir -p "${MOUNT_DIR}"
mkdir -p "${STAGE}/content"
cp -R "${APP_SRC}" "${STAGE}/content/Filtr.app"
ln -s /Applications "${STAGE}/content/Applications"

# Create a writable sparseimage, copy contents, then style Finder window
hdiutil create \
  -size 120m \
  -fs HFS+ \
  -volname "${VOLUME_NAME}" \
  -type SPARSE \
  "${STAGE}/Filtr"

hdiutil attach "${STAGE}/Filtr.sparseimage" -mountpoint "${MOUNT_DIR}" -nobrowse

# Copy app + Applications alias
cp -R "${STAGE}/content/Filtr.app" "${MOUNT_DIR}/Filtr.app"
ln -s /Applications "${MOUNT_DIR}/Applications"

# Hidden background folder (Finder DMG convention)
mkdir -p "${MOUNT_DIR}/.background"
cp "${BG_SRC}" "${MOUNT_DIR}/.background/background.png"
# Also place @2x if present
if [[ -f "${ROOT}/Design/dmg-background@2x.png" ]]; then
  cp "${ROOT}/Design/dmg-background@2x.png" "${MOUNT_DIR}/.background/karen.d@example.net"
fi

# Style the Finder window: icon view, background, positions, text
osascript <<EOF
tell application "Finder"
  tell disk "${VOLUME_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {120, 120, $((120 + WINDOW_W)), $((120 + WINDOW_H))}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to ${ICON_SIZE}
    set text size of opts to 12
    set background picture of opts to file ".background:background.png"
    set position of item "Filtr.app" of container window to {${APP_X}, ${APP_Y}}
    set position of item "Applications" of container window to {${APPS_X}, ${APPS_Y}}
    update without registering applications
    delay 1
    close
    open
    delay 1
    set the bounds of container window to {120, 120, $((120 + WINDOW_W)), $((120 + WINDOW_H))}
    close
  end tell
end tell
EOF

sync
hdiutil detach "${MOUNT_DIR}" -force
mkdir -p "$(dirname "${DMG_OUT}")"
rm -f "${DMG_OUT}"
hdiutil convert "${STAGE}/Filtr.sparseimage" -format UDZO -imagekey zlib-level=9 -o "${DMG_OUT}"
echo "Created ${DMG_OUT}"
