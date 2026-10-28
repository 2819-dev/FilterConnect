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
VOLUME_NAME="Filtr"
WINDOW_W=660
WINDOW_H=420
ICON_SIZE=96
APP_X=165
APP_Y=210
APPS_X=495
APPS_Y=210

detach_volume() {
  if [[ -d "/Volumes/${VOLUME_NAME}" ]]; then
    hdiutil detach "/Volumes/${VOLUME_NAME}" -force >/dev/null 2>&1 || true
  fi
}

cleanup() {
  detach_volume
  rm -rf "${STAGE}"
}
trap cleanup EXIT

mkdir -p "${STAGE}/content"
cp -R "${APP_SRC}" "${STAGE}/content/Filtr.app"
ln -s /Applications "${STAGE}/content/Applications"
mkdir -p "${STAGE}/content/.background"
cp "${BG_SRC}" "${STAGE}/content/.background/background.png"

# Size estimate: app + padding
SIZE_MB=150
RW_DMG="${STAGE}/Filtr-rw.dmg"
detach_volume
rm -f "${RW_DMG}" "${DMG_OUT}"

hdiutil create \
  -srcfolder "${STAGE}/content" \
  -volname "${VOLUME_NAME}" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  -size ${SIZE_MB}m \
  "${RW_DMG}"

# Mount read-write so Finder can write .DS_Store / view options
detach_volume
DEVICE_LINE="$(hdiutil attach -readwrite -noverify -noautoopen "${RW_DMG}" | tee /dev/stderr | tail -n 1)"
# e.g. /dev/disk3s1  Apple_HFS  /Volumes/Filtr
VOLUME_PATH="/Volumes/${VOLUME_NAME}"
for _ in $(seq 1 30); do
  if [[ -d "${VOLUME_PATH}" ]]; then
    break
  fi
  sleep 0.5
done
if [[ ! -d "${VOLUME_PATH}" ]]; then
  echo "Volume did not appear at ${VOLUME_PATH}" >&2
  echo "attach output: ${DEVICE_LINE}" >&2
  exit 1
fi

# Ensure Applications symlink + background exist on the mounted volume
if [[ ! -e "${VOLUME_PATH}/Applications" ]]; then
  ln -s /Applications "${VOLUME_PATH}/Applications"
fi
mkdir -p "${VOLUME_PATH}/.background"
cp "${BG_SRC}" "${VOLUME_PATH}/.background/background.png"

# Give Finder a moment to notice the disk
sleep 2
open "${VOLUME_PATH}"
sleep 2

# Style Finder window. Retry a few times — CI runners can be slow to register disks.
styled=0
for attempt in 1 2 3 4 5; do
  if osascript <<EOF
tell application "Finder"
  activate
  try
    set theDisk to disk "${VOLUME_NAME}"
  on error
    error "disk not ready"
  end try
  tell theDisk
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {120, 120, $((120 + WINDOW_W)), $((120 + WINDOW_H))}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to ${ICON_SIZE}
    set text size of opts to 12
    try
      set background picture of opts to file ".background:background.png"
    end try
    set position of item "Filtr.app" to {${APP_X}, ${APP_Y}}
    set position of item "Applications" to {${APPS_X}, ${APPS_Y}}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF
  then
    styled=1
    echo "Finder window styled (attempt ${attempt})"
    break
  else
    echo "Finder style attempt ${attempt} failed; retrying…"
    sleep 2
    open "${VOLUME_PATH}" || true
    sleep 1
  fi
done

if [[ "${styled}" -ne 1 ]]; then
  echo "Warning: could not style Finder window; shipping DMG with background file + icons anyway" >&2
fi

sync
sleep 1
# Bless the folder so .DS_Store sticks
if command -v bless >/dev/null 2>&1; then
  bless --folder "${VOLUME_PATH}" --openfolder "${VOLUME_PATH}" || true
fi

# Unmount cleanly
for _ in $(seq 1 10); do
  if hdiutil detach "${VOLUME_PATH}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
  # Force close Finder windows on the volume
  osascript -e 'tell application "Finder" to close every window' >/dev/null 2>&1 || true
done
detach_volume

mkdir -p "$(dirname "${DMG_OUT}")"
hdiutil convert "${RW_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_OUT}"
echo "Created ${DMG_OUT}"
ls -lh "${DMG_OUT}"
