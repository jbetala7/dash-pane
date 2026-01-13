#!/bin/bash

# DashPane Release Build Script
# This script builds, signs, and packages DashPane for distribution

set -e

# Configuration
PROJECT_NAME="DashPane"
SCHEME="DashPane"
CONFIGURATION="Release"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$PROJECT_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/Release"
DMG_NAME="$PROJECT_NAME.dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== DashPane Release Build ===${NC}"

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild not found. Please install Xcode.${NC}"
    exit 1
fi

# Clean build directory
echo -e "${YELLOW}Cleaning build directory...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build archive
echo -e "${YELLOW}Building archive...${NC}"
xcodebuild \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    archive

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}Error: Archive failed${NC}"
    exit 1
fi

echo -e "${GREEN}Archive created successfully${NC}"

# Export archive
echo -e "${YELLOW}Exporting archive...${NC}"

# Create export options plist
cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF

xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"

if [ ! -d "$EXPORT_PATH/$PROJECT_NAME.app" ]; then
    echo -e "${RED}Error: Export failed${NC}"
    exit 1
fi

echo -e "${GREEN}Export successful${NC}"

# Create DMG
echo -e "${YELLOW}Creating DMG...${NC}"

# Create a temporary folder for DMG contents
DMG_TEMP="$BUILD_DIR/dmg-temp"
mkdir -p "$DMG_TEMP"

# Copy app to temp folder
cp -R "$EXPORT_PATH/$PROJECT_NAME.app" "$DMG_TEMP/"

# Create symlink to Applications folder
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
hdiutil create \
    -volname "$PROJECT_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$BUILD_DIR/$DMG_NAME"

# Clean up temp folder
rm -rf "$DMG_TEMP"

echo -e "${GREEN}DMG created: $BUILD_DIR/$DMG_NAME${NC}"

# Print summary
echo -e "\n${GREEN}=== Build Complete ===${NC}"
echo -e "App: $EXPORT_PATH/$PROJECT_NAME.app"
echo -e "DMG: $BUILD_DIR/$DMG_NAME"
echo -e "\n${YELLOW}Note: You still need to notarize the app for distribution.${NC}"
echo -e "Run: ./Scripts/notarize.sh"
