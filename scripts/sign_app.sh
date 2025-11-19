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

# Expand entitlements variables (REQUIRED for app to launch)
if [ -n "$TEAM_ID" ]; then
    ENTITLEMENTS_TEMP=$(mktemp)
    sed -e "s/\$(AppIdentifierPrefix)/${TEAM_ID}./g" \
        -e "s/\$(TeamIdentifierPrefix)/${TEAM_ID}/g" \
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
# 1. XPC Services
echo "Signing XPC Services..."
codesign --force --sign "$IDENTITY" \
  --timestamp --options runtime \
  "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"

codesign --force --sign "$IDENTITY" \
  --timestamp --options runtime \
  "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"

# 2. Updater.app
echo "Signing Updater.app..."
codesign --force --sign "$IDENTITY" \
  --timestamp --options runtime \
  "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"

# 3. Autoupdate binary
echo "Signing Autoupdate..."
codesign --force --sign "$IDENTITY" \
  --timestamp --options runtime \
  "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"

# 4. Sparkle framework
echo "Signing Sparkle.framework..."
codesign --force --sign "$IDENTITY" \
  --timestamp --options runtime \
  "$APP_PATH/Contents/Frameworks/Sparkle.framework"

# 5. Main app (with entitlements)
echo "Signing main app..."
codesign --force --sign "$IDENTITY" \
  --timestamp --options runtime \
  --entitlements "$ENTITLEMENTS_TEMP" \
  "$APP_PATH"

# Verify
echo "Verifying signatures..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "✅ All components signed successfully"
