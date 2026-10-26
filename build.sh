#!/bin/bash
set -euo pipefail

# LiquidRemote Build & Package Script
# Builds native macOS app bundle with Developer ID signing

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="LiquidRemote"
BUILD_DIR="${PROJECT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
SIGN_IDENTITY="Developer ID Application: Dakota Hilchey (2FCUC227QF)"

echo "==> [1/4] Preparing build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "==> [2/4] Compiling Swift source files..."
SWIFT_FILES=()
while IFS= read -r -d '' file; do
    SWIFT_FILES+=("$file")
done < <(find "${PROJECT_DIR}" -name "*.swift" -not -path "*/build/*" -print0)

swiftc \
    -swift-version 5 \
    -O \
    -parse-as-library \
    "${SWIFT_FILES[@]}" \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "==> [3/4] Copying bundle resources and Info.plist..."
cp "${PROJECT_DIR}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
if [ -d "${PROJECT_DIR}/Resources" ]; then
    cp -R "${PROJECT_DIR}/Resources/"* "${APP_BUNDLE}/Contents/Resources/"
fi

echo "==> [4/4] Code signing application bundle..."
if security find-identity -v -p codesigning | grep -q "${SIGN_IDENTITY}"; then
    echo "    Signing with Developer ID: ${SIGN_IDENTITY}..."
    codesign --force --deep --options runtime --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}"
else
    echo "    Developer ID certificate not found in keychain, signing ad-hoc..."
    codesign --force --deep --sign - "${APP_BUNDLE}"
fi

codesign -dvvv "${APP_BUNDLE}" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier|flags" || true

echo ""
echo "✅ Build complete: ${APP_BUNDLE}"
echo "   Run with: open \"${APP_BUNDLE}\""
