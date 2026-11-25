#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Building Pliw Click (Release mode)..."
swift build -c release -Xswiftc -cross-module-optimization

RELEASE_BIN="${PROJECT_DIR}/.build/release/pliw-click"
APP_DIR="${PROJECT_DIR}/Pliw Click.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Assembling Pliw Click.app bundle..."
rm -rf "${PROJECT_DIR}/pliw-click.app" "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${RELEASE_BIN}" "${MACOS_DIR}/pliw-click"
strip "${MACOS_DIR}/pliw-click"
chmod +x "${MACOS_DIR}/pliw-click"

if [ -d "${PROJECT_DIR}/Resources" ]; then
    cp -R "${PROJECT_DIR}/Resources/"* "${RESOURCES_DIR}/" || true
fi

cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>pliw-click</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.pliw-click</string>
    <key>CFBundleName</key>
    <string>Pliw Click</string>
    <key>CFBundleDisplayName</key>
    <string>Pliw Click</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.3.4</string>
    <key>CFBundleVersion</key>
    <string>1.3.4</string>
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

echo "🔏 Code signing Pliw Click.app with stable PliwDeveloper certificate..."
SIGN_CERT="PliwDeveloper"
if ! security find-certificate -c "${SIGN_CERT}" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
    echo "Creating persistent local developer certificate '${SIGN_CERT}' for stable macOS TCC permissions..."
    TMP_CERT_DIR=$(mktemp -d)
    openssl req -x509 -newkey rsa:2048 -days 3650 \
      -keyout "${TMP_CERT_DIR}/dev.key" -out "${TMP_CERT_DIR}/dev.crt" -nodes \
      -subj "/CN=${SIGN_CERT}" \
      -addext "keyUsage=critical,digitalSignature" \
      -addext "extendedKeyUsage=codeSigning"
    if openssl pkcs12 -help 2>&1 | grep -q -- "-legacy"; then
        openssl pkcs12 -export -legacy \
          -in "${TMP_CERT_DIR}/dev.crt" -inkey "${TMP_CERT_DIR}/dev.key" \
          -out "${TMP_CERT_DIR}/dev.p12" -password pass:pliwdev
    else
        openssl pkcs12 -export \
          -in "${TMP_CERT_DIR}/dev.crt" -inkey "${TMP_CERT_DIR}/dev.key" \
          -out "${TMP_CERT_DIR}/dev.p12" -password pass:pliwdev
    fi
    security import "${TMP_CERT_DIR}/dev.p12" -k ~/Library/Keychains/login.keychain-db -P pliwdev -T /usr/bin/codesign || true
    rm -rf "${TMP_CERT_DIR}"
fi

codesign --force --deep --sign "${SIGN_CERT}" "${APP_DIR}" || codesign --force --deep --sign - "${APP_DIR}"

echo "✅ Successfully built: ${APP_DIR}"

if [ -z "${SKIP_INSTALL}" ]; then
    echo "📲 Updating /Applications/Pliw Click.app..."
    pkill -9 -f "Pliw Click.app" || true
    pkill -9 -f "pliw-click.app" || true
    rm -rf "/Applications/pliw-click.app" "/Applications/Pliw Click.app"
    cp -R "${APP_DIR}" "/Applications/Pliw Click.app"
    echo "🎉 Installed /Applications/Pliw Click.app"
else
    echo "⏭️ Skipping install to /Applications because SKIP_INSTALL is set."
fi
