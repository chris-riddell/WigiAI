#!/bin/bash
set -e

APP_PATH="$1"
IDENTITY="$2"
TEAM_ID="$3"

if [ -z "$APP_PATH" ] || [ -z "$IDENTITY" ]; then
    echo "Usage: $0 <app-path> <identity> [team-id]"
    exit 1
fi

echo "Signing all components in: $APP_PATH"

# Clean extended attributes (critical for consistent signing)
echo "Cleaning extended attributes..."
xattr -cr "$APP_PATH"

# Expand entitlements variables
if [ -n "$TEAM_ID" ]; then
    ENTITLEMENTS_TEMP=$(mktemp)
    sed -e "s/\$(AppIdentifierPrefix)/${TEAM_ID}./g" \
        -e "s/\$(TeamIdentifierPrefix)82L4HKJ83Z/${TEAM_ID}/g" \
        "$(dirname "$0")/../WigiAI/WigiAI.entitlements" > "$ENTITLEMENTS_TEMP"
    trap "rm -f $ENTITLEMENTS_TEMP" EXIT
    echo "Expanded entitlements to: $ENTITLEMENTS_TEMP"
    cat "$ENTITLEMENTS_TEMP"
else
    ENTITLEMENTS_TEMP="$(dirname "$0")/../WigiAI/WigiAI.entitlements"
    echo "Using entitlements file: $ENTITLEMENTS_TEMP"
    cat "$ENTITLEMENTS_TEMP"
fi

# Sign from inside-out (deepest components first)
# This is CRITICAL - nested code must be signed before outer containers

# 1. Sign all dylibs first (deepest level)
echo "Signing dynamic libraries..."
find "$APP_PATH/Contents" -name "*.dylib" 2>/dev/null | while read dylib; do
  echo "  - $(basename "$dylib")"
  codesign --force --sign "$IDENTITY" \
    --timestamp --options runtime \
    "$dylib" || echo "    Warning: Failed to sign $dylib"
done

# 2. Sign XPC Services
echo "Signing XPC Services..."
find "$APP_PATH/Contents" -name "*.xpc" 2>/dev/null | while read xpc; do
  echo "  - $(basename "$xpc")"
  codesign --force --sign "$IDENTITY" \
    --timestamp --options runtime \
    "$xpc" || echo "    Warning: Failed to sign $xpc"
done

# 3. Sign helper apps and binaries (Updater.app, Autoupdate, etc.)
echo "Signing helper applications and binaries..."
# Updater.app (Sparkle)
if [ -f "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app/Contents/MacOS/Updater" ]; then
  echo "  - Updater.app"
  codesign --force --sign "$IDENTITY" \
    --timestamp --options runtime \
    "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
fi

# Autoupdate binary (Sparkle)
if [ -f "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" ]; then
  echo "  - Autoupdate"
  codesign --force --sign "$IDENTITY" \
    --timestamp --options runtime \
    "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
fi

# Sign any other helper tools in MacOS directory (excluding main binary)
APP_NAME=$(basename "$APP_PATH" .app)
find "$APP_PATH/Contents/MacOS" -type f -perm +111 ! -name "$APP_NAME" 2>/dev/null | while read helper; do
  echo "  - $(basename "$helper")"
  codesign --force --sign "$IDENTITY" \
    --timestamp --options runtime \
    "$helper" || echo "    Warning: Failed to sign $helper"
done

# 4. Sign all frameworks (Sparkle and any others)
echo "Signing frameworks..."
find "$APP_PATH/Contents/Frameworks" -name "*.framework" -depth 1 2>/dev/null | while read framework; do
  echo "  - $(basename "$framework")"
  codesign --force --sign "$IDENTITY" \
    --timestamp --options runtime \
    "$framework" || echo "    Warning: Failed to sign $framework"
done

# 5. Sign main app bundle (LAST, with entitlements)
echo "Signing main application bundle..."
codesign --force --sign "$IDENTITY" \
  --timestamp --options runtime \
  --entitlements "$ENTITLEMENTS_TEMP" \
  "$APP_PATH" -v

# Verify (--deep is OK for verification, not for signing)
echo "Verifying signatures..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "✅ All components signed successfully"
