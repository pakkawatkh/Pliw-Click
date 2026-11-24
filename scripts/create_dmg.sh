#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Ensuring latest release build of tiffy-click.app..."
./scripts/build_app.sh

DMG_TMP="${PROJECT_DIR}/.build_dmg"
DMG_OUTPUT="${PROJECT_DIR}/tiffy-click-Installer.dmg"

echo "📦 Preparing DMG installer directory structure..."
rm -rf "${DMG_TMP}"
mkdir -p "${DMG_TMP}"

cp -R "${PROJECT_DIR}/tiffy-click.app" "${DMG_TMP}/tiffy-click.app"
ln -s /Applications "${DMG_TMP}/Applications"

cat << 'EOF' > "${DMG_TMP}/How to Install.txt"
===================================================
  🖱️ tiffy-click — Universal Middle-Click & Autoscroll
===================================================

1. INSTALLATION:
   Drag "tiffy-click.app" into the "Applications" shortcut icon.

2. FIRST-TIME OPEN (macOS Gatekeeper):
   If macOS warns "cannot be opened because the developer cannot be verified":
   - Open System Settings > Privacy & Security, click "Open Anyway", OR
   - Run in Terminal: xattr -cr /Applications/tiffy-click.app

3. ACCESSIBILITY PERMISSION:
   - Enable tiffy-click in System Settings > Privacy & Security > Accessibility.

4. USAGE:
   - Trackpad: 3-finger Click or Tap = Middle Click / Autoscroll!
   - Physical Mouse: Press Middle Button on any page = Windows-style Autoscroll!
   - Smart Mode: Middle-click on links/tabs still opens/closes tabs normally.
   - Click the mouse icon on the top Menu Bar to adjust speed, deadzone, or mode.
===================================================
EOF

echo "📀 Creating DMG disk image: ${DMG_OUTPUT}..."
rm -f "${DMG_OUTPUT}"
hdiutil create -volname "tiffy-click Installer" -srcfolder "${DMG_TMP}" -ov -format UDZO "${DMG_OUTPUT}"
rm -rf "${DMG_TMP}"

ZIP_OUTPUT="${PROJECT_DIR}/tiffy-click.zip"
echo "🗜️ Creating ZIP archive for in-app updates: ${ZIP_OUTPUT}..."
rm -f "${ZIP_OUTPUT}"
ditto -c -k --keepParent "${PROJECT_DIR}/tiffy-click.app" "${ZIP_OUTPUT}"

TIFFY_PORTAL_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/tiffy-app/tiffy-click"
mkdir -p "${TIFFY_PORTAL_DIR}"
echo "📦 Syncing DMG and ZIP to ${TIFFY_PORTAL_DIR}..."
cp -f "${DMG_OUTPUT}" "${TIFFY_PORTAL_DIR}/tiffy-click-Installer.dmg"
cp -f "${ZIP_OUTPUT}" "${TIFFY_PORTAL_DIR}/tiffy-click.zip"

echo "🎉 DMG and ZIP packages successfully created!"
ls -lh "${DMG_OUTPUT}" "${ZIP_OUTPUT}"
