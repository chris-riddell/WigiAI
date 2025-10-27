#!/bin/bash

# Script to generate EdDSA keys for Sparkle update signing
# This provides cryptographic verification that updates come from you

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔐 Generating Sparkle EdDSA Key Pair...${NC}"
echo ""

# Check if openssl is available
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}❌ openssl not found. Please install it first.${NC}"
    exit 1
fi

# Generate output directory
KEYS_DIR="sparkle_keys"
mkdir -p "$KEYS_DIR"

# Generate EdDSA private key (Ed25519)
echo -e "${BLUE}📝 Generating private key...${NC}"
PRIVATE_KEY_FILE="$KEYS_DIR/sparkle_private_key.pem"
openssl genpkey -algorithm ED25519 -out "$PRIVATE_KEY_FILE"

# Extract public key
echo -e "${BLUE}📝 Extracting public key...${NC}"
PUBLIC_KEY_FILE="$KEYS_DIR/sparkle_public_key.pem"
openssl pkey -in "$PRIVATE_KEY_FILE" -pubout -out "$PUBLIC_KEY_FILE"

# Convert public key to Sparkle format (base64, single line)
PUBLIC_KEY_BASE64=$(openssl pkey -in "$PUBLIC_KEY_FILE" -pubin -outform DER | tail -c 32 | base64)

echo ""
echo -e "${GREEN}✅ Keys generated successfully!${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}IMPORTANT: Follow these steps carefully${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 1: Add public key to Info.plist
echo -e "${GREEN}Step 1: Add Public Key to Info.plist${NC}"
echo ""
echo "Add this key to your WigiAI/Info.plist file:"
echo ""
echo -e "${BLUE}<key>SUPublicEDKey</key>${NC}"
echo -e "${BLUE}<string>${PUBLIC_KEY_BASE64}</string>${NC}"
echo ""
echo "It should go inside the main <dict> section."
echo ""

# Step 2: Add private key to GitHub Secrets
echo -e "${GREEN}Step 2: Add Private Key to GitHub Secrets${NC}"
echo ""
echo "1. Go to your GitHub repository"
echo "2. Navigate to: Settings → Secrets and variables → Actions"
echo "3. Click 'New repository secret'"
echo "4. Name: SPARKLE_PRIVATE_KEY"
echo "5. Value: Copy the entire content below (including BEGIN/END lines)"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
cat "$PRIVATE_KEY_FILE"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 3: Security reminder
echo -e "${RED}Step 3: SECURITY WARNING${NC}"
echo ""
echo "⚠️  NEVER commit the private key to git!"
echo "⚠️  The private key is stored in: $PRIVATE_KEY_FILE"
echo "⚠️  Keep this file safe and backed up securely"
echo ""

# Step 4: Next steps
echo -e "${GREEN}Step 4: Next Steps${NC}"
echo ""
echo "After adding the keys:"
echo "1. Commit the updated Info.plist"
echo "2. Create a new release: ./scripts/bump_version.sh patch \"Your message\""
echo "3. Push tags: git push origin --tags"
echo "4. GitHub Actions will automatically sign the update"
echo ""

# Create a .gitignore entry if it doesn't exist
if ! grep -q "sparkle_keys/" .gitignore 2>/dev/null; then
    echo "sparkle_keys/" >> .gitignore
    echo -e "${GREEN}✅ Added sparkle_keys/ to .gitignore${NC}"
fi

echo -e "${GREEN}🎉 Setup complete!${NC}"
echo ""
echo "Files created:"
echo "  - $PRIVATE_KEY_FILE (KEEP SECRET!)"
echo "  - $PUBLIC_KEY_FILE (can share publicly)"
echo ""
