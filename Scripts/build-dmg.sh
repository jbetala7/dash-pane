#!/bin/bash
# Build DMG script for DashPane
# Uses pre-configured .DS_Store template for reliable background display

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="DashPane"
VOL_NAME="DashPane"
DMG_TEMP="$PROJECT_DIR/dist/DashPane-temp.dmg"
DMG_FINAL="$PROJECT_DIR/dist/DashPane-1.0.dmg"

# Get version from app if it exists
APP_PATH="$PROJECT_DIR/build/DerivedData/Build/Products/Release/DashPane.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: DashPane.app not found at $APP_PATH"
    echo "Please build the app first with: xcodebuild -scheme DashPane -configuration Release"
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "1.0")
DMG_FINAL="$PROJECT_DIR/dist/DashPane-$VERSION.dmg"

echo "Building DMG for DashPane v$VERSION..."

# Clean up any existing temp files
rm -f "$DMG_TEMP" "$DMG_FINAL" 2>/dev/null || true
hdiutil detach /Volumes/DashPane -force 2>/dev/null || true

# Create dist directory if needed
mkdir -p "$PROJECT_DIR/dist"

# Step 1: Use appdmg to create base DMG with icon positioning
echo "Creating base DMG with appdmg..."
cat > "$PROJECT_DIR/dist/dmg-config-temp.json" << EOF
{
  "title": "DashPane",
  "background": "$PROJECT_DIR/Resources/dmg-background.tiff",
  "window": {
    "size": {
      "width": 660,
      "height": 400
    }
  },
  "icon-size": 128,
  "contents": [
    { "x": 165, "y": 200, "type": "file", "path": "$APP_PATH" },
    { "x": 495, "y": 200, "type": "link", "path": "/Applications" }
  ],
  "format": "UDRW"
}
EOF

appdmg "$PROJECT_DIR/dist/dmg-config-temp.json" "$DMG_TEMP"
rm "$PROJECT_DIR/dist/dmg-config-temp.json"

# Step 2: Mount and apply the working .DS_Store template
echo "Applying .DS_Store template for background..."
hdiutil attach -readwrite "$DMG_TEMP"
sleep 2

# Copy the pre-configured .DS_Store that has the working background
cp "$PROJECT_DIR/Resources/dmg-DS_Store" /Volumes/DashPane/.DS_Store

# Set volume icon
if [ -f "$PROJECT_DIR/Resources/VolumeIcon.icns" ]; then
    echo "Setting volume icon..."
    cp "$PROJECT_DIR/Resources/VolumeIcon.icns" /Volumes/DashPane/.VolumeIcon.icns
    SetFile -a C /Volumes/DashPane
fi

# Remove .fseventsd if it exists
rm -rf /Volumes/DashPane/.fseventsd 2>/dev/null || true

# Strip extended attributes (but not the volume)
xattr -cr /Volumes/DashPane/.background 2>/dev/null || true
xattr -cr /Volumes/DashPane/DashPane.app 2>/dev/null || true

# Sync and detach
sync
sleep 1
hdiutil detach /Volumes/DashPane

# Step 3: Convert to final compressed DMG
echo "Converting to compressed DMG..."
hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_FINAL"

# Clean up
rm -f "$DMG_TEMP"

echo ""
echo "✅ DMG created successfully: $DMG_FINAL"
echo "   Size: $(du -h "$DMG_FINAL" | cut -f1)"
