#!/bin/bash

# Script 3: Notarize the app with Apple
# Requires: Apple Developer account with app-specific password

set -e

echo "======================================"
echo "Notarizing BrightPass.app"
echo "======================================"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_BUNDLE="build/BrightPass.app"
ZIP_FILE="build/BrightPass.zip"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo -e "${RED}Error: App bundle not found${NC}"
    echo "Run ./scripts/1-build-app.sh and ./scripts/2-sign-app.sh first"
    exit 1
fi

if [ -z "$APPLE_ID" ]; then
    echo -e "${RED}Error: APPLE_ID environment variable not set${NC}"
    echo "  export APPLE_ID=\"your@email.com\""
    exit 1
fi

if [ -z "$APPLE_TEAM_ID" ]; then
    echo -e "${RED}Error: APPLE_TEAM_ID environment variable not set${NC}"
    echo "  export APPLE_TEAM_ID=\"XXXXXXXXXX\""
    exit 1
fi

# Check for credentials
echo -e "${YELLOW}Checking for notarization credentials...${NC}"
if ! xcrun notarytool history --keychain-profile "AC_PASSWORD" 2>&1 | grep -q "Successfully received submission history"; then
    if ! xcrun notarytool history --keychain-profile "AC_PASSWORD" 2>&1 | grep -q "Error: Could not find"; then
        echo -e "${GREEN}✓ Credentials found${NC}"
    else
        echo -e "${RED}Error: Notarization credentials not found${NC}"
        echo ""
        echo "To store credentials:"
        echo "  xcrun notarytool store-credentials \"AC_PASSWORD\" \\"
        echo "    --apple-id \"$APPLE_ID\" \\"
        echo "    --team-id \"$APPLE_TEAM_ID\" \\"
        echo "    --password \"xxxx-xxxx-xxxx-xxxx\""
        exit 1
    fi
else
    echo -e "${GREEN}✓ Credentials found${NC}"
fi

# Create zip for notarization
echo -e "${YELLOW}Creating zip file for notarization...${NC}"
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_FILE}"

# Submit for notarization
echo -e "${YELLOW}Submitting to Apple for notarization...${NC}"
echo "This may take several minutes..."

xcrun notarytool submit "${ZIP_FILE}" \
    --keychain-profile "AC_PASSWORD" \
    --wait

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Notarization successful${NC}"

    echo -e "${YELLOW}Stapling notarization ticket...${NC}"
    xcrun stapler staple "${APP_BUNDLE}"

    echo -e "${YELLOW}Verifying notarization...${NC}"
    xcrun stapler validate "${APP_BUNDLE}"

    echo -e "${GREEN}✓ App notarized and stapled successfully${NC}"
    echo ""
    echo "Next step:"
    echo "  Run ./scripts/4-create-dmg.sh to create installer"
else
    echo -e "${RED}✗ Notarization failed${NC}"
    echo ""
    echo "To see detailed logs:"
    echo "  xcrun notarytool log <submission-id> --keychain-profile AC_PASSWORD"
    exit 1
fi
