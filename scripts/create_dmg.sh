#!/bin/bash

# Script to create a DMG file for distribution
# Usage: ./create_dmg.sh <path-to-app> <output-dmg-name>

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <path-to-WigiAI.app> <output-dmg-name>"
    exit 1
fi

APP_PATH="$1"
DMG_NAME="$2"
APP_NAME="WigiAI"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}📦 Creating DMG for ${APP_NAME}...${NC}"

# Validate app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ App not found at: $APP_PATH${NC}"
    exit 1
fi

# Get app version
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || echo "1.0")
echo -e "${BLUE}   Version: ${APP_VERSION}${NC}"

# Create temporary directory for DMG contents
TMP_DIR=$(mktemp -d)
DMG_DIR="${TMP_DIR}/${APP_NAME}"
mkdir -p "$DMG_DIR"

echo -e "${BLUE}🔨 Preparing DMG contents...${NC}"

# Copy app to temp directory
cp -R "$APP_PATH" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Create a simple README
cat > "$DMG_DIR/README.txt" << EOF
WigiAI - AI Desktop Companion
Version ${APP_VERSION}

INSTALLATION:
1. Drag WigiAI to the Applications folder
2. Launch WigiAI from Applications
3. Look for the character bubble icon in your menubar

FIRST LAUNCH:
If you see a security warning, go to:
System Settings > Privacy & Security > Open Anyway

Or run in Terminal:
  xattr -cr /Applications/WigiAI.app

REQUIREMENTS:
- macOS 14.0 (Sonoma) or later

SUPPORT:
https://github.com/chris-riddell/WigiAI

Enjoy your AI companions! 🎉
EOF

# Remove existing DMG if it exists
if [ -f "$DMG_NAME" ]; then
    echo -e "${BLUE}🗑️  Removing existing DMG...${NC}"
    rm "$DMG_NAME"
fi

# Create DMG
echo -e "${BLUE}💿 Creating DMG...${NC}"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_NAME"

# Cleanup
rm -rf "$TMP_DIR"

# Verify DMG was created
if [ -f "$DMG_NAME" ]; then
    DMG_SIZE=$(du -h "$DMG_NAME" | cut -f1)
    echo -e "${GREEN}✅ DMG created successfully!${NC}"
    echo -e "${BLUE}   File: ${DMG_NAME}${NC}"
    echo -e "${BLUE}   Size: ${DMG_SIZE}${NC}"
else
    echo -e "${RED}❌ Failed to create DMG${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Done!${NC}"
