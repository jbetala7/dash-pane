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

# Check if create-dmg is installed
if command -v create-dmg &> /dev/null; then
    # Build create-dmg command with available options
    # Layout: App on left, Applications folder on right (like Claude)
    CREATE_DMG_OPTS=(
        --volname "$PROJECT_NAME"
        --window-pos 200 120
        --window-size 660 400
        --icon-size 128
        --icon "$PROJECT_NAME.app" 180 200
        --hide-extension "$PROJECT_NAME.app"
        --app-drop-link 480 200
    )

    # Add volume icon if available
    if [ -f "Resources/VolumeIcon.icns" ]; then
        CREATE_DMG_OPTS+=(--volicon "Resources/VolumeIcon.icns")
    fi

    # Add background if available
    if [ -f "Resources/dmg-background.png" ]; then
        CREATE_DMG_OPTS+=(--background "Resources/dmg-background.png")
    fi

    # Create the DMG
    create-dmg "${CREATE_DMG_OPTS[@]}" "$BUILD_DIR/$DMG_NAME" "$EXPORT_PATH/$PROJECT_NAME.app"
else
    # Fallback to basic hdiutil
    echo -e "${YELLOW}create-dmg not found, using basic DMG creation...${NC}"
    DMG_TEMP="$BUILD_DIR/dmg-temp"
    mkdir -p "$DMG_TEMP"
    cp -R "$EXPORT_PATH/$PROJECT_NAME.app" "$DMG_TEMP/"
    ln -s /Applications "$DMG_TEMP/Applications"
    hdiutil create \
        -volname "$PROJECT_NAME" \
        -srcfolder "$DMG_TEMP" \
        -ov \
        -format UDZO \
        "$BUILD_DIR/$DMG_NAME"
    rm -rf "$DMG_TEMP"
fi

echo -e "${GREEN}DMG created: $BUILD_DIR/$DMG_NAME${NC}"

# Print summary
echo -e "\n${GREEN}=== Build Complete ===${NC}"
echo -e "App: $EXPORT_PATH/$PROJECT_NAME.app"
echo -e "DMG: $BUILD_DIR/$DMG_NAME"
echo -e "\n${YELLOW}Note: You still need to notarize the app for distribution.${NC}"
echo -e "Run: ./Scripts/notarize.sh"
