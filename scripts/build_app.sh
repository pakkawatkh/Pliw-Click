#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Building tiffy-click (Release mode)..."
swift build -c release -Xswiftc -cross-module-optimization

RELEASE_BIN="${PROJECT_DIR}/.build/release/tiffy-click"
APP_DIR="${PROJECT_DIR}/tiffy-click.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Assembling tiffy-click.app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${RELEASE_BIN}" "${MACOS_DIR}/tiffy-click"
strip "${MACOS_DIR}/tiffy-click"
chmod +x "${MACOS_DIR}/tiffy-click"

if [ -d "${PROJECT_DIR}/Resources" ]; then
    cp -R "${PROJECT_DIR}/Resources/"* "${RESOURCES_DIR}/" || true
fi

cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>tiffy-click</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.tiffy-click</string>
    <key>CFBundleName</key>
    <string>tiffy-click</string>
    <key>CFBundleDisplayName</key>
    <string>tiffy-click</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.1</string>
    <key>CFBundleVersion</key>
    <string>1.0.1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "🔏 Code signing tiffy-click.app with stable certificate..."
SIGN_CERT="MonkeyToolsDeveloper"
if security find-certificate -c "${SIGN_CERT}" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
    codesign --force --deep --sign "${SIGN_CERT}" "${APP_DIR}" || codesign --force --deep --sign - "${APP_DIR}"
else
    codesign --force --deep --sign - "${APP_DIR}"
fi

echo "✅ Successfully built: ${APP_DIR}"

if [ -z "${SKIP_INSTALL}" ]; then
    echo "📲 Updating /Applications/tiffy-click.app..."
    pkill -9 -f "/Applications/tiffy-click.app" || true
    rm -rf "/Applications/tiffy-click.app"
    cp -R "${APP_DIR}" "/Applications/tiffy-click.app"
    echo "🎉 Installed /Applications/tiffy-click.app"
else
    echo "⏭️ Skipping install to /Applications because SKIP_INSTALL is set."
fi
