#!/bin/bash
set -e

APP_NAME="ReadingFocus"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR=".build/release"

echo "Building ${APP_NAME}..."
swift build -c release 2>&1

echo "Packaging as ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/"
cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"

CERT_NAME="ReadingFocusDev"

# Sign with a self-signed certificate so TCC can persistently identify the app.
# Falls back to ad-hoc if the certificate hasn't been created yet.
if security find-certificate -c "${CERT_NAME}" ~/Library/Keychains/login.keychain-db &>/dev/null; then
    codesign --force --deep -s "${CERT_NAME}" "${APP_BUNDLE}" && echo "Signed with ${CERT_NAME}."
else
    echo "WARNING: Certificate '${CERT_NAME}' not found — falling back to ad-hoc signing."
    echo "         Accessibility permission will break on each rebuild until you create it."
    echo "         See setup instructions below."
    codesign --force --sign - "${APP_BUNDLE}" 2>/dev/null && echo "Signed (ad-hoc)." || echo "Signing skipped."
fi

echo ""
echo "Done! To install:"
echo "  cp -r ${APP_BUNDLE} /Applications/"
echo ""
echo "Then launch it — look for the book icon in your menu bar."
echo ""
echo "IMPORTANT: One-time setup (do this once, then never again):"
echo ""
echo "  1. Create a self-signed code-signing certificate:"
echo "       a. Open Keychain Access → Certificate Assistant → Create a Certificate"
echo "       b. Name: ReadingFocusDev"
echo "       c. Identity Type: Self Signed Root"
echo "       d. Certificate Type: Code Signing"
echo "       e. Click Create → Done"
echo ""
echo "  2. Reset stale TCC entries and re-grant permission:"
echo "       tccutil reset Accessibility com.readingfocus.app"
echo "       (run once after creating the cert, then grant in System Settings)"
echo ""
echo "  3. Create Shortcuts for Do Not Disturb:"
echo "       Open the Shortcuts app"
echo "       'Reading Mode On'  → Action: Set Focus → Do Not Disturb → On"
echo "       'Reading Mode Off' → Action: Set Focus → Do Not Disturb → Off"
