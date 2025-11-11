#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="WigiAI"
SCHEME="WigiAI"
BUILD_DIR="${PROJECT_DIR}/build"
APP_PATH="${BUILD_DIR}/Release/${APP_NAME}.app"
DEST_PATH="/Applications/${APP_NAME}.app"

echo -e "${BLUE}🚀 WigiAI Deployment Script${NC}"
echo -e "${BLUE}=============================${NC}"
echo ""

# Step 1: Kill running app if it exists
if pgrep -x "$APP_NAME" > /dev/null; then
    echo -e "${YELLOW}⚠️  ${APP_NAME} is currently running${NC}"
    read -p "Kill running instance? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo -e "${BLUE}🛑 Stopping ${APP_NAME}...${NC}"
        killall "$APP_NAME" || true
        sleep 1
    else
        echo -e "${RED}❌ Cannot deploy while app is running${NC}"
        exit 1
    fi
fi

# Step 2: Clean build directory
echo -e "${BLUE}🧹 Cleaning build directory...${NC}"
rm -rf "$BUILD_DIR"

# Step 3: Build the app
echo -e "${BLUE}🔨 Building ${APP_NAME} (Release)...${NC}"
cd "$PROJECT_DIR"

xcodebuild \
    -scheme "$SCHEME" \
    -configuration Release \
    clean build \
    | xcpretty 2>/dev/null || xcodebuild \
    -scheme "$SCHEME" \
    -configuration Release \
    clean build

# Find the built app in Xcode's Derived Data
BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData/WigiAI-*/Build/Products/Release -name "${APP_NAME}.app" -type d 2>/dev/null | head -n 1)

if [ ! -d "$BUILT_APP" ]; then
    echo -e "${RED}❌ Build failed - app not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"
echo -e "${BLUE}   Built app: ${BUILT_APP}${NC}"

# Step 4: Remove old version from Applications
if [ -d "$DEST_PATH" ]; then
    echo -e "${BLUE}🗑️  Removing old version from Applications...${NC}"
    rm -rf "$DEST_PATH"
fi

# Step 5: Copy to Applications
echo -e "${BLUE}📦 Copying to Applications folder...${NC}"
cp -R "$BUILT_APP" "$DEST_PATH"

# Step 6: Verify installation
if [ -d "$DEST_PATH" ]; then
    echo -e "${GREEN}✅ Successfully deployed to ${DEST_PATH}${NC}"

    # Get app version
    APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${DEST_PATH}/Contents/Info.plist" 2>/dev/null || echo "unknown")
    APP_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${DEST_PATH}/Contents/Info.plist" 2>/dev/null || echo "unknown")

    echo -e "${BLUE}   Version: ${APP_VERSION} (${APP_BUILD})${NC}"
    echo ""

    # Step 7: Ask to launch
    read -p "Launch WigiAI now? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo -e "${BLUE}🚀 Launching ${APP_NAME}...${NC}"
        open "$DEST_PATH"
        echo -e "${GREEN}✅ Done!${NC}"
    else
        echo -e "${GREEN}✅ Deployment complete. Launch manually from Applications folder.${NC}"
    fi
else
    echo -e "${RED}❌ Deployment failed - app not found in Applications${NC}"
    exit 1
fi

# Step 8: Clean up build artifacts (optional)
read -p "Clean up build artifacts? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo -e "${BLUE}🧹 Cleaning up...${NC}"
    rm -rf "$BUILD_DIR"
    echo -e "${GREEN}✅ Build artifacts cleaned${NC}"
fi

echo ""
echo -e "${GREEN}🎉 All done!${NC}"
