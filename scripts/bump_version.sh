#!/bin/bash

# Script to bump version and create a new release tag
# Usage: ./bump_version.sh [major|minor|patch] [message]

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not a git repository${NC}"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}⚠️  You have uncommitted changes${NC}"
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get current version from Xcode project
CURRENT_VERSION=$(grep -m 1 "MARKETING_VERSION = " WigiAI.xcodeproj/project.pbxproj | sed 's/.*= \(.*\);/\1/')
echo -e "${BLUE}Current version: ${CURRENT_VERSION}${NC}"

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Determine bump type
BUMP_TYPE="${1:-patch}"
case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo -e "${RED}❌ Invalid bump type: $BUMP_TYPE${NC}"
        echo "Usage: $0 [major|minor|patch] [message]"
        exit 1
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo -e "${GREEN}New version: ${NEW_VERSION}${NC}"

# Get commit message
if [ -n "$2" ]; then
    MESSAGE="$2"
else
    read -p "Release message (or press Enter for default): " MESSAGE
    if [ -z "$MESSAGE" ]; then
        MESSAGE="Release v${NEW_VERSION}"
    fi
fi

echo ""
echo -e "${BLUE}Preparing release:${NC}"
echo -e "${BLUE}  Version: ${NEW_VERSION}${NC}"
echo -e "${BLUE}  Message: ${MESSAGE}${NC}"
echo ""
read -p "Continue? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
    echo -e "${YELLOW}Cancelled${NC}"
    exit 0
fi

# Update version in Xcode project
echo -e "${BLUE}📝 Updating version in Xcode project...${NC}"
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = ${NEW_VERSION};/" WigiAI.xcodeproj/project.pbxproj

# Commit version change
echo -e "${BLUE}💾 Committing version change...${NC}"
git add WigiAI.xcodeproj/project.pbxproj
git commit -m "Bump version to ${NEW_VERSION}"

# Create and push tag
echo -e "${BLUE}🏷️  Creating git tag...${NC}"
git tag -a "v${NEW_VERSION}" -m "$MESSAGE"

# Push immediately
echo -e "${BLUE}🚀 Pushing to GitHub...${NC}"
git push origin main
git push origin "v${NEW_VERSION}"

echo ""
echo -e "${GREEN}✅ Version ${NEW_VERSION} released!${NC}"
echo ""
echo -e "${BLUE}GitHub Actions is now:${NC}"
echo -e "   • Building the DMG"
echo -e "   • Creating GitHub release"
echo -e "   • Generating appcast.xml automatically"
echo ""
echo -e "${BLUE}Monitor progress:${NC}"
echo -e "   https://github.com/${GITHUB_USER:-chris-riddell}/${GITHUB_REPO:-WigiAI}/actions"
echo ""
echo -e "${GREEN}🎉 Done!${NC}"
