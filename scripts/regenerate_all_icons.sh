#!/bin/bash

# Regenerate all app icons and menubar icons
# Run this whenever you want to update the icon design

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BLUE}🎨 Regenerating ALL icons...${NC}"
echo ""

# Regenerate app icons
echo -e "${BLUE}1️⃣  Generating app icons (all sizes)...${NC}"
swift scripts/generate_icon.swift
echo ""

# Regenerate menubar icons
echo -e "${BLUE}2️⃣  Generating menubar icons...${NC}"
swift scripts/generate_menubar_icon.swift
echo ""

echo -e "${GREEN}✅ All icons regenerated!${NC}"
echo ""
echo -e "${BLUE}App icons:${NC} WigiAI/Assets.xcassets/AppIcon.appiconset/"
echo -e "${BLUE}Menubar icons:${NC} WigiAI/Assets.xcassets/MenuBarIcon.imageset/"
echo ""
echo -e "${GREEN}🎉 Done! Clean and rebuild in Xcode.${NC}"
