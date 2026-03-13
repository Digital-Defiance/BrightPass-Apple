#!/bin/bash

# Script 1: Build the macOS app bundle
# Compiles BrightPass and creates a .app bundle

set -e

echo "======================================"
echo "Building BrightPass.app"
echo "======================================"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_NAME="BrightPass"
EXECUTABLE="BrightPassmacOS"
BUNDLE_ID="org.brightchain.BrightPass"

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf build/
mkdir -p build

# Build for release
echo -e "${YELLOW}Building universal binary...${NC}"

echo -e "${YELLOW}  - Building for arm64...${NC}"
swift build -c release --arch arm64

echo -e "${YELLOW}  - Building for x86_64...${NC}"
swift build -c release --arch x86_64

# Create universal binary
echo -e "${YELLOW}  - Combining architectures...${NC}"
mkdir -p .build/universal
lipo -create \
    .build/arm64-apple-macosx/release/${EXECUTABLE} \
    .build/x86_64-apple-macosx/release/${EXECUTABLE} \
    -output .build/universal/${EXECUTABLE}

echo -e "${GREEN}✓ Universal binary created${NC}"

# Create app bundle structure
echo -e "${YELLOW}Creating app bundle structure...${NC}"
APP_BUNDLE="build/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

# Copy executable (renamed to match CFBundleExecutable)
cp .build/universal/${EXECUTABLE} "${MACOS}/${EXECUTABLE}"

# Copy resources
echo -e "${YELLOW}Copying resources...${NC}"
cp brightpass.png "${RESOURCES}/brightpass.png"

# Copy SPM resource bundle if it exists
SPM_BUNDLE=".build/arm64-apple-macosx/release/BrightPassKit_BrightPassKit.bundle"
if [ -d "$SPM_BUNDLE" ]; then
    cp -R "$SPM_BUNDLE" "${RESOURCES}/"
    echo -e "${GREEN}✓ SPM resource bundle copied${NC}"
fi

# Create app icon from the 1024x1024 source
if [ -f "BrightPass-iOS-Default-1024x1024@1x.png" ]; then
    echo -e "${YELLOW}Creating app icon...${NC}"
    ICONSET="${APP_NAME}.iconset"
    mkdir -p "${ICONSET}"

    sips -z 16 16     "BrightPass-iOS-Default-1024x1024@1x.png" --out "${ICONSET}/icon_16x16.png"      > /dev/null 2>&1
    sips -z 32 32     "BrightPass-iOS-Default-1024x1024@1x.png" --out "${ICONSET}/icon_16x16@2x.png"   > /dev/null 2>&1
    sips -z 32 32     "BrightPass-iOS-Default-1024x1024@1x.png" --out "${ICONSET}/icon_32x32.png"      > /dev/null 2>&1
    sips -z 64 64     "BrightPass-iOS-Default-1024x1024@1x.png" --out "${ICONSET}/icon_32x32@2x.png"   > /dev/null 2>&1
    sips -z 128 128   "BrightPass-iOS-Default-1024x1024@1x.png" --out "${ICONSET}/icon_128x128.png"    > /dev/null 2>&1
    sips -z 256 256   "BrightPass-iOS-Default-1024x1024@1x.png" --out "${ICONSET}/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256   "BrightPass-iOS-Default-1024x1024@1x.png" --out "${ICONSET}/icon_256x256.png"    > /dev/null 2>&1
    sips -z 512 512   "BrightPass-iOS-Default-1024x1024@1x.png" --out "${ICONSET}/icon_256x256@2x.png" > /dev/null 2>&1
    sips -z 512 512   "BrightPass-iOS-Default-1024x1024@1x.png" --out "${ICONSET}/icon_512x512.png"    > /dev/null 2>&1
    sips -z 1024 1024 "BrightPass-iOS-Default-1024x1024@1x.png" --out "${ICONSET}/icon_512x512@2x.png" > /dev/null 2>&1

    iconutil -c icns "${ICONSET}" -o "${RESOURCES}/${APP_NAME}.icns"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Icon created successfully${NC}"
    else
        echo -e "${RED}✗ Icon creation failed${NC}"
    fi

    rm -rf "${ICONSET}"
else
    echo -e "${YELLOW}Warning: App icon source not found, skipping icon creation${NC}"
fi

# Create Info.plist
echo -e "${YELLOW}Creating Info.plist...${NC}"
cat > "${CONTENTS}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
</dict>
</plist>
EOF

# Set executable permissions
chmod +x "${MACOS}/${EXECUTABLE}"

echo -e "${GREEN}✓ App bundle created at: ${APP_BUNDLE}${NC}"
echo ""
echo "Next steps:"
echo "  1. Run ./scripts/2-sign-app.sh to code sign"
echo "  2. Run ./scripts/3-notarize-app.sh to notarize"
echo "  3. Run ./scripts/4-create-dmg.sh to create installer"
