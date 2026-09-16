#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
DIST_DIR="${PROJECT_DIR}/dist"
APP_DIR="${DIST_DIR}/VibePM.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ICONSET_DIR="${DIST_DIR}/AppIcon.iconset"
DMG_PATH="${DIST_DIR}/VibePM.dmg"

cd "${PROJECT_DIR}"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "${APP_DIR}" "${ICONSET_DIR}" "${DMG_PATH}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${ICONSET_DIR}"

cp "${BIN_DIR}/VibePM" "${MACOS_DIR}/VibePM"
cp "${PROJECT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

sips -z 16 16 "${PROJECT_DIR}/Resources/AppIcon-1024.png" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
sips -z 32 32 "${PROJECT_DIR}/Resources/AppIcon-1024.png" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "${PROJECT_DIR}/Resources/AppIcon-1024.png" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
sips -z 64 64 "${PROJECT_DIR}/Resources/AppIcon-1024.png" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "${PROJECT_DIR}/Resources/AppIcon-1024.png" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
sips -z 256 256 "${PROJECT_DIR}/Resources/AppIcon-1024.png" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "${PROJECT_DIR}/Resources/AppIcon-1024.png" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
sips -z 512 512 "${PROJECT_DIR}/Resources/AppIcon-1024.png" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "${PROJECT_DIR}/Resources/AppIcon-1024.png" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
sips -z 1024 1024 "${PROJECT_DIR}/Resources/AppIcon-1024.png" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null

iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"

codesign \
    --force \
    --deep \
    --sign - \
    --entitlements "${PROJECT_DIR}/Resources/VibePM.entitlements" \
    "${APP_DIR}"

codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

hdiutil create \
    -volname "VibePM" \
    -srcfolder "${APP_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

print "Created ${APP_DIR}"
print "Created ${DMG_PATH}"

