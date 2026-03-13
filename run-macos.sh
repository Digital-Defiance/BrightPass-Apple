#!/bin/bash
# Build and run BrightPassmacOS as a proper .app bundle
set -e

echo "Building BrightPassmacOS..."
swift build --target BrightPassmacOS

BIN_PATH=$(swift build --show-bin-path)
APP_DIR=".build/BrightPass.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Clean previous bundle
rm -rf "$APP_DIR"

# Create .app bundle structure
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy binary
cp "$BIN_PATH/BrightPassmacOS" "$MACOS/BrightPassmacOS"

# Copy banner image as a resource
cp brightpass.png "$RESOURCES/brightpass.png"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>BrightPassmacOS</string>
    <key>CFBundleIdentifier</key>
    <string>org.brightchain.BrightPass</string>
    <key>CFBundleName</key>
    <string>BrightPass</string>
    <key>CFBundleDisplayName</key>
    <string>BrightPass</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
</dict>
</plist>
EOF

echo "Launching BrightPass.app..."
open "$APP_DIR"
