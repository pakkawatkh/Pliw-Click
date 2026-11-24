#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Ensuring latest release build of Pliw Click.app..."
./scripts/build_app.sh

DMG_TMP="${PROJECT_DIR}/.build_dmg"
DMG_OUTPUT="${PROJECT_DIR}/pliw-click-Installer.dmg"

echo "📦 Preparing DMG installer directory structure..."
rm -rf "${DMG_TMP}"
mkdir -p "${DMG_TMP}"

cp -R "${PROJECT_DIR}/Pliw Click.app" "${DMG_TMP}/Pliw Click.app"
ln -s /Applications "${DMG_TMP}/Applications"

cat << 'EOF' > "${DMG_TMP}/How to Install.txt"
===================================================
  🖱️ Pliw Click — Middle-Click & Liquid Glass Autoscroll
===================================================

1. INSTALLATION:
   Drag "Pliw Click.app" into the "Applications" shortcut icon.

2. FIRST-TIME OPEN (macOS Gatekeeper):
   If macOS warns "cannot be opened because the developer cannot be verified":
   - Open System Settings > Privacy & Security, click "Open Anyway", OR
   - Run in Terminal: xattr -cr "/Applications/Pliw Click.app"

3. ACCESSIBILITY PERMISSION:
   - Enable Pliw Click in System Settings > Privacy & Security > Accessibility.

4. USAGE:
   - Trackpad: 3-finger (or 2-10 finger) Click or Tap = Middle Click / Autoscroll!
   - Physical Mouse: Press Middle Button on empty browser pages = Liquid Glass 360° Autoscroll!
   - Links, tabs, and non-browser apps behave as standard middle-click.
===================================================
EOF

echo "📀 Creating DMG disk image: ${DMG_OUTPUT}..."
rm -f "${DMG_OUTPUT}"
hdiutil create -volname "Pliw Click Installer" -srcfolder "${DMG_TMP}" -ov -format UDZO "${DMG_OUTPUT}"
rm -rf "${DMG_TMP}"

ZIP_OUTPUT="${PROJECT_DIR}/pliw-click.zip"
echo "🗜️ Creating ZIP archive for in-app updates: ${ZIP_OUTPUT}..."
rm -f "${ZIP_OUTPUT}"
ditto -c -k --keepParent "${PROJECT_DIR}/Pliw Click.app" "${ZIP_OUTPUT}"

if [ -f "$(cd "${PROJECT_DIR}/../.." && pwd)/index.html" ]; then
    PLIW_PORTAL_DIR="$(cd "${PROJECT_DIR}/../.." && pwd)/pliw-click"
else
    PLIW_PORTAL_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/Pliw-App/pliw-click"
fi
mkdir -p "${PLIW_PORTAL_DIR}"
echo "📦 Syncing DMG and ZIP to ${PLIW_PORTAL_DIR}..."
cp -f "${DMG_OUTPUT}" "${PLIW_PORTAL_DIR}/pliw-click-Installer.dmg"
cp -f "${ZIP_OUTPUT}" "${PLIW_PORTAL_DIR}/pliw-click.zip"

echo "🎉 DMG and ZIP packages successfully created!"
ls -lh "${DMG_OUTPUT}" "${ZIP_OUTPUT}"
