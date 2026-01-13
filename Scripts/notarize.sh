#!/bin/bash

# DashPane Notarization Script
# This script notarizes the app for distribution outside the Mac App Store

set -e

# Configuration
PROJECT_NAME="DashPane"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/Release/$PROJECT_NAME.app"
DMG_PATH="$BUILD_DIR/$PROJECT_NAME.dmg"
ZIP_PATH="$BUILD_DIR/$PROJECT_NAME.zip"

# Notarization profile name (set up using: xcrun notarytool store-credentials)
PROFILE_NAME="notarization-profile"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== DashPane Notarization ===${NC}"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found at $APP_PATH${NC}"
    echo -e "Run build-release.sh first."
    exit 1
fi

# Create zip for notarization
echo -e "${YELLOW}Creating zip for notarization...${NC}"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# Submit for notarization
echo -e "${YELLOW}Submitting for notarization...${NC}"
echo -e "This may take several minutes..."

xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$PROFILE_NAME" \
    --wait

# Check result
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Notarization successful!${NC}"
else
    echo -e "${RED}Notarization failed${NC}"
    echo -e "Check the log for details:"
    echo -e "xcrun notarytool log <submission-id> --keychain-profile $PROFILE_NAME"
    exit 1
fi

# Staple the app
echo -e "${YELLOW}Stapling ticket to app...${NC}"
xcrun stapler staple "$APP_PATH"

# If DMG exists, notarize and staple it too
if [ -f "$DMG_PATH" ]; then
    echo -e "${YELLOW}Notarizing DMG...${NC}"

    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$PROFILE_NAME" \
        --wait

    echo -e "${YELLOW}Stapling ticket to DMG...${NC}"
    xcrun stapler staple "$DMG_PATH"
fi

# Clean up zip
rm -f "$ZIP_PATH"

echo -e "\n${GREEN}=== Notarization Complete ===${NC}"
echo -e "Your app is now notarized and ready for distribution."
echo -e "\nFiles ready for distribution:"
echo -e "  - $APP_PATH"
[ -f "$DMG_PATH" ] && echo -e "  - $DMG_PATH"

# Verify notarization
echo -e "\n${YELLOW}Verifying notarization...${NC}"
spctl -a -vvv -t install "$APP_PATH"

echo -e "\n${GREEN}Done!${NC}"
