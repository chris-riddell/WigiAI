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

# CRITICAL: Sign from inside-out (deepest components first)
# Violating this order causes POSIX 153!

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

# 3. Sign Sparkle components in CORRECT order (deepest first)
echo "Signing Sparkle framework components..."

# 3a. Sign Updater binary (inside Updater.app) FIRST
if [ -f "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app/Contents/MacOS/Updater" ]; then
  echo "  - Updater binary (inside Updater.app)"
  codesign --force --sign "$IDENTITY" \
    --timestamp --options runtime \
    "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app/Contents/MacOS/Updater"
fi

# 3b. Sign Updater.app bundle (after its binary)
if [ -d "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app" ]; then
  echo "  - Updater.app bundle"
  codesign --force --sign "$IDENTITY" \
    --timestamp --options runtime \
    "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
fi

# 3c. Sign Autoupdate binary
if [ -f "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" ]; then
  echo "  - Autoupdate binary"
  codesign --force --sign "$IDENTITY" \
    --timestamp --options runtime \
    "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
fi

# 3d. Sign Sparkle.framework (contains all the above - MUST be last)
if [ -d "$APP_PATH/Contents/Frameworks/Sparkle.framework" ]; then
  echo "  - Sparkle.framework (outer container)"
  codesign --force --sign "$IDENTITY" \
    --timestamp --options runtime \
    "$APP_PATH/Contents/Frameworks/Sparkle.framework"
fi

# 4. Sign any other frameworks (AFTER their contents are signed)
echo "Signing other frameworks..."
find "$APP_PATH/Contents/Frameworks" -name "*.framework" -maxdepth 1 2>/dev/null | while read framework; do
  # Skip Sparkle (already signed above)
  if [[ "$framework" != *"Sparkle.framework"* ]]; then
    echo "  - $(basename "$framework")"
    codesign --force --sign "$IDENTITY" \
      --timestamp --options runtime \
      "$framework" || echo "    Warning: Failed to sign $framework"
  fi
done

# 5. Sign helper tools in MacOS directory (excluding main binary)
echo "Signing helper tools..."
APP_NAME=$(basename "$APP_PATH" .app)
find "$APP_PATH/Contents/MacOS" -type f -perm +111 ! -name "$APP_NAME" 2>/dev/null | while read helper; do
  echo "  - $(basename "$helper")"
  codesign --force --sign "$IDENTITY" \
    --timestamp --options runtime \
    "$helper" || echo "    Warning: Failed to sign $helper"
done

# 6. Sign main app bundle (LAST, with entitlements)
echo "Signing main application bundle..."
codesign --force --sign "$IDENTITY" \
  --timestamp --options runtime \
  --entitlements "$ENTITLEMENTS_TEMP" \
  "$APP_PATH" -v

# Verify (--deep is OK for verification, not for signing)
echo "Verifying signatures..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "✅ All components signed successfully"
