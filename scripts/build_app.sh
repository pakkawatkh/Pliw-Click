#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Building Tiffy Click (Release mode)..."
swift build -c release -Xswiftc -cross-module-optimization

RELEASE_BIN="${PROJECT_DIR}/.build/release/tiffy-click"
APP_DIR="${PROJECT_DIR}/Tiffy Click.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Assembling Tiffy Click.app bundle..."
rm -rf "${PROJECT_DIR}/tiffy-click.app" "${APP_DIR}"
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
    <string>Tiffy Click</string>
    <key>CFBundleDisplayName</key>
    <string>Tiffy Click</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.2</string>
    <key>CFBundleVersion</key>
    <string>1.2.2</string>
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

echo "🔏 Code signing Tiffy Click.app with stable certificate..."
SIGN_CERT="MonkeyToolsDeveloper"
if ! security find-certificate -c "${SIGN_CERT}" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
    if security find-certificate -c "MonkeyCopyDeveloper" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
        SIGN_CERT="MonkeyCopyDeveloper"
    else
        echo "Creating persistent local developer certificate for stable macOS TCC permissions..."
        TMP_CERT_DIR=$(mktemp -d)
        openssl req -x509 -newkey rsa:2048 -days 3650 \
          -keyout "${TMP_CERT_DIR}/dev.key" -out "${TMP_CERT_DIR}/dev.crt" -nodes \
          -subj "/CN=MonkeyToolsDeveloper" \
          -addext "keyUsage=critical,digitalSignature" \
          -addext "extendedKeyUsage=codeSigning"
        openssl pkcs12 -export \
          -in "${TMP_CERT_DIR}/dev.crt" -inkey "${TMP_CERT_DIR}/dev.key" \
          -out "${TMP_CERT_DIR}/dev.p12" -password pass:monkeytools
        security import "${TMP_CERT_DIR}/dev.p12" -k ~/Library/Keychains/login.keychain-db -P monkeytools -T /usr/bin/codesign || true
        rm -rf "${TMP_CERT_DIR}"
    fi
fi

codesign --force --deep --sign "${SIGN_CERT}" "${APP_DIR}" || codesign --force --deep --sign - "${APP_DIR}"

echo "✅ Successfully built: ${APP_DIR}"

if [ -z "${SKIP_INSTALL}" ]; then
    echo "📲 Updating /Applications/Tiffy Click.app..."
    pkill -9 -f "Tiffy Click.app" || true
    pkill -9 -f "tiffy-click.app" || true
    rm -rf "/Applications/tiffy-click.app" "/Applications/Tiffy Click.app"
    cp -R "${APP_DIR}" "/Applications/Tiffy Click.app"
    echo "🎉 Installed /Applications/Tiffy Click.app"
else
    echo "⏭️ Skipping install to /Applications because SKIP_INSTALL is set."
fi
