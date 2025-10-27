#!/bin/bash

# Script to generate Sparkle appcast.xml from GitHub releases
# This script creates an appcast feed for Sparkle auto-updates with EdDSA signatures

set -e

# Configuration
GITHUB_USER="${1:-chris-riddell}"
GITHUB_REPO="${2:-WigiAI}"
OUTPUT_FILE="${3:-appcast.xml}"
PRIVATE_KEY_FILE="${4:-}"  # Optional: path to private key file
SPECIFIC_VERSION="${5:-}"  # Optional: specific version tag (e.g., v1.0.2)

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}📝 Generating Sparkle appcast...${NC}"

# Function to sign a file with EdDSA
sign_file_eddsa() {
    local file_path="$1"
    local private_key="$2"

    if [[ ! -f "$file_path" ]]; then
        echo -e "${RED}❌ File not found: $file_path${NC}"
        return 1
    fi

    if [[ -z "$private_key" ]]; then
        echo -e "${YELLOW}⚠️  No private key provided, skipping signature${NC}"
        return 1
    fi

    # Create temporary private key file if passed as string
    local key_file
    if [[ -f "$private_key" ]]; then
        key_file="$private_key"
    else
        key_file=$(mktemp)
        echo "$private_key" > "$key_file"
        trap "rm -f $key_file" EXIT
    fi

    # Sign the file with EdDSA
    # The signature is the Ed25519 signature of the file, base64 encoded
    local signature
    signature=$(openssl dgst -sha512 -sign "$key_file" -binary "$file_path" | base64)

    echo "$signature"
}

# Create appcast XML header
cat > "$OUTPUT_FILE" << 'XMLHEADER'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>WigiAI Updates</title>
    <link>https://github.com/chris-riddell/WigiAI</link>
    <description>AI Companion Desktop Widget for macOS</description>
    <language>en</language>
XMLHEADER

# Fetch release from GitHub API
echo -e "${BLUE}📡 Fetching release info from GitHub...${NC}"

# Get release info (specific version or latest)
if [[ -n "$SPECIFIC_VERSION" ]]; then
    echo -e "${BLUE}   Fetching specific version: ${SPECIFIC_VERSION}${NC}"
    RELEASE_JSON=$(curl -s "https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/releases/tags/${SPECIFIC_VERSION}" || echo "{}")
else
    echo -e "${BLUE}   Fetching latest release${NC}"
    RELEASE_JSON=$(curl -s "https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/releases/latest" || echo "{}")
fi

if [[ "$RELEASE_JSON" == "{}" ]] || echo "$RELEASE_JSON" | grep -q "\"message\": \"Not Found\""; then
    echo -e "${RED}❌ No releases found or API error${NC}"
    echo -e "${BLUE}ℹ️  Creating empty appcast (will be populated after first release)${NC}"
    cat >> "$OUTPUT_FILE" << 'XMLFOOTER'
    <!-- No releases yet - will be populated after first release -->
  </channel>
</rss>
XMLFOOTER
    exit 0
fi

# Extract release info
VERSION=$(echo "$RELEASE_JSON" | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/' | sed 's/^v//')
RELEASE_DATE=$(echo "$RELEASE_JSON" | grep '"published_at"' | sed 's/.*"published_at": "\(.*\)".*/\1/')
RELEASE_NOTES=$(echo "$RELEASE_JSON" | grep '"body"' | sed 's/.*"body": "\(.*\)".*/\1/' | sed 's/\\n/<br\/>/g' | sed 's/\\"/"/g')

# Try to find DMG URL with multiple patterns (more flexible matching)
DMG_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url":[[:space:]]*"[^"]*\.dmg"' | sed 's/.*"browser_download_url":[[:space:]]*"\([^"]*\)"/\1/' | head -1)

# Debug output
echo -e "${BLUE}🔍 Debug info:${NC}"
echo -e "${BLUE}   Version: $VERSION${NC}"
echo -e "${BLUE}   Release date: $RELEASE_DATE${NC}"
echo -e "${BLUE}   DMG URL: ${DMG_URL:-[NOT FOUND]}${NC}"

# Get file size
if [[ -n "$DMG_URL" ]]; then
    echo -e "${GREEN}✅ Found DMG: $DMG_URL${NC}"
    FILE_SIZE=$(curl -sI "$DMG_URL" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
else
    echo -e "${RED}❌ No DMG file found in release${NC}"
    echo -e "${YELLOW}Release assets:${NC}"
    echo "$RELEASE_JSON" | grep '"browser_download_url"' | head -5
    exit 1
fi

# Convert date to RFC 822 format
if command -v gdate &> /dev/null; then
    PUB_DATE=$(gdate -d "$RELEASE_DATE" -R)
else
    PUB_DATE=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$RELEASE_DATE" "+%a, %d %b %Y %H:%M:%S %z")
fi

echo -e "${GREEN}✅ Found release: v${VERSION}${NC}"
echo -e "${BLUE}   Date: ${PUB_DATE}${NC}"
echo -e "${BLUE}   DMG: ${DMG_URL}${NC}"
echo -e "${BLUE}   Size: ${FILE_SIZE} bytes${NC}"

# Generate EdDSA signature if private key is available
ED_SIGNATURE=""
if [[ -n "$PRIVATE_KEY_FILE" ]] || [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    echo -e "${BLUE}🔐 Generating EdDSA signature...${NC}"

    # Download DMG temporarily for signing
    TEMP_DMG=$(mktemp -u).dmg
    trap "rm -f $TEMP_DMG" EXIT

    if curl -sL "$DMG_URL" -o "$TEMP_DMG"; then
        # Use environment variable if set (for CI), otherwise use file
        PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:-$PRIVATE_KEY_FILE}"
        ED_SIGNATURE=$(sign_file_eddsa "$TEMP_DMG" "$PRIVATE_KEY")

        if [[ -n "$ED_SIGNATURE" ]]; then
            echo -e "${GREEN}✅ Signature generated${NC}"
        else
            echo -e "${YELLOW}⚠️  Signature generation failed${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Could not download DMG for signing${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No private key provided - appcast will not be signed${NC}"
    echo -e "${YELLOW}   Set SPARKLE_PRIVATE_KEY env var or pass key file as 4th argument${NC}"
fi

# Build enclosure element with optional signature
ENCLOSURE_ELEMENT="<enclosure url=\"${DMG_URL}\"
                 sparkle:version=\"${VERSION}\"
                 sparkle:shortVersionString=\"${VERSION}\"
                 length=\"${FILE_SIZE}\""

if [[ -n "$ED_SIGNATURE" ]]; then
    ENCLOSURE_ELEMENT="${ENCLOSURE_ELEMENT}
                 sparkle:edSignature=\"${ED_SIGNATURE}\""
fi

ENCLOSURE_ELEMENT="${ENCLOSURE_ELEMENT}
                 type=\"application/octet-stream\" />"

# Add release item to appcast
cat >> "$OUTPUT_FILE" << XMLITEM
    <item>
      <title>Version ${VERSION}</title>
      <link>https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/tag/v${VERSION}</link>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <pubDate>${PUB_DATE}</pubDate>
      ${ENCLOSURE_ELEMENT}
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <h2>What's New in ${VERSION}</h2>
        <p>${RELEASE_NOTES}</p>
        <p><a href="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/tag/v${VERSION}">View full release notes on GitHub</a></p>
      ]]></description>
    </item>
XMLITEM

# Close XML
cat >> "$OUTPUT_FILE" << 'XMLFOOTER'
  </channel>
</rss>
XMLFOOTER

echo -e "${GREEN}✅ Appcast generated: ${OUTPUT_FILE}${NC}"
echo -e "${BLUE}📋 Contents:${NC}"
cat "$OUTPUT_FILE"
echo ""
echo -e "${GREEN}🎉 Done!${NC}"
