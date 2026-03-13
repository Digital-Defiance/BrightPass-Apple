#!/bin/bash

# Script 4: Create a DMG installer for BrightPass

set -e

echo "======================================"
echo "Creating BrightPass.dmg"
echo "======================================"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_NAME="BrightPass"
APP_BUNDLE="build/${APP_NAME}.app"
DMG_FILE="build/${APP_NAME}.dmg"
VOLUME_NAME="BrightPass"
DMG_TEMP="build/dmg_temp"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo -e "${RED}Error: App bundle not found${NC}"
    echo "Run previous scripts first"
    exit 1
fi

# Clean up
echo -e "${YELLOW}Cleaning up old DMG...${NC}"
rm -f "${DMG_FILE}"
rm -rf "${DMG_TEMP}"
rm -f build/pack.temp.dmg

# Create DMG folder
echo -e "${YELLOW}Creating DMG structure...${NC}"
mkdir -p "${DMG_TEMP}"
cp -R "${APP_BUNDLE}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

cat > "${DMG_TEMP}/README.txt" << EOF
BrightPass - Secure Password Manager for macOS and iOS

INSTALLATION:
1. Drag BrightPass.app to the Applications folder
2. Open BrightPass from Applications
3. Create an account or log in with your recovery phrase

FEATURES:
- End-to-end encrypted vaults
- TOTP two-factor authentication
- Secure password generator
- AutoFill extension for Safari and apps
- Biometric unlock with Touch ID / Face ID

For more information, visit:
https://github.com/Digital-Defiance/BrightPass-Apple

License: MIT
© 2026 Digital Defiance, Jessica Mulein
EOF

# Calculate size
SIZE=$(du -sk "${DMG_TEMP}" | cut -f1)
SIZE=$((SIZE * 15 / 10))
if [ $SIZE -lt 10240 ]; then
    SIZE=10240
fi

# Create DMG
echo -e "${YELLOW}Creating DMG image...${NC}"
hdiutil create -srcfolder "${DMG_TEMP}" \
    -volname "${VOLUME_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${SIZE}k \
    "build/pack.temp.dmg"

# Mount for customization
echo -e "${YELLOW}Mounting DMG for customization...${NC}"
DEVICE=$(hdiutil attach -readwrite -noverify "build/pack.temp.dmg" | \
    egrep '^/dev/' | sed 1q | awk '{print $1}')

sleep 2

# Customize appearance
echo -e "${YELLOW}Customizing DMG appearance...${NC}"
echo '
   tell application "Finder"
     tell disk "'${VOLUME_NAME}'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {400, 100, 920, 440}
           set viewOptions to the icon view options of container window
           set arrangement of viewOptions to not arranged
           set icon size of viewOptions to 72
           set position of item "BrightPass.app" of container window to {130, 150}
           set position of item "Applications" of container window to {390, 150}
           close
           open
           update without registering applications
           delay 2
     end tell
   end tell
' | osascript || true

sleep 2

# Unmount and convert
echo -e "${YELLOW}Finalizing DMG...${NC}"
sync
hdiutil detach "${DEVICE}" || true

hdiutil convert "build/pack.temp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_FILE}"

# Clean up
rm -f "build/pack.temp.dmg"
rm -rf "${DMG_TEMP}"

# Sign the DMG if certificate available
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo -e "${YELLOW}Signing DMG...${NC}"
    CERT=$(security find-identity -v -p codesigning | grep "Developer ID Application" | awk '!seen[$2]++' | head -1 | awk '{print $2}')
    codesign --force --sign "$CERT" "${DMG_FILE}"
fi

echo -e "${GREEN}✓ DMG created successfully: ${DMG_FILE}${NC}"
echo ""
echo "Distribution file ready!"
echo "  Size: $(du -h "${DMG_FILE}" | cut -f1)"
