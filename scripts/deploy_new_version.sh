#!/bin/bash
#
# deploy_new_version.sh
# Automated version deployment script for WoW addons
#
# Usage: ./scripts/deploy_new_version.sh <addon_name>
# Example: ./scripts/deploy_new_version.sh MEStats
#

set -e  # Exit on error

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Addon configuration
declare -A ADDON_PREFIXES=(
    ["MEStats"]="mestats"
    ["AscensionTrinketManager"]="atm"
    ["AscensionVanityHelper"]="avh"
)

declare -A ADDON_NAMES=(
    ["MEStats"]="MEStats"
    ["AscensionTrinketManager"]="Ascension Trinket Manager"
    ["AscensionVanityHelper"]="Ascension Vanity Helper"
)

# Paths
WORKSPACE_ROOT="$HOME/workspace/github.com/5tuartw/WowAddons"

# Validate input
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No addon specified${NC}"
    echo ""
    echo "Usage: $0 <addon_name>"
    echo ""
    echo "Available addons:"
    for addon in "${!ADDON_PREFIXES[@]}"; do
        echo "  - $addon"
    done
    exit 1
fi

ADDON_NAME="$1"

# Validate addon exists
if [ ! -v "ADDON_PREFIXES[$ADDON_NAME]" ]; then
    echo -e "${RED}Error: Unknown addon '$ADDON_NAME'${NC}"
    echo ""
    echo "Available addons:"
    for addon in "${!ADDON_PREFIXES[@]}"; do
        echo "  - $addon"
    done
    exit 1
fi

ADDON_PREFIX="${ADDON_PREFIXES[$ADDON_NAME]}"
ADDON_DISPLAY="${ADDON_NAMES[$ADDON_NAME]}"
ADDON_ROOT="$WORKSPACE_ROOT/$ADDON_NAME"
TOC_FILE="$ADDON_ROOT/${ADDON_NAME}.toc"

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Deploy New Version: ${ADDON_DISPLAY}${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Check if addon directory exists
if [ ! -d "$ADDON_ROOT" ]; then
    echo -e "${RED}Error: Addon directory not found: $ADDON_ROOT${NC}"
    exit 1
fi

if [ ! -f "$TOC_FILE" ]; then
    echo -e "${RED}Error: TOC file not found: $TOC_FILE${NC}"
    exit 1
fi

# Extract current version from TOC
CURRENT_VERSION=$(grep "^## Version:" "$TOC_FILE" | sed 's/^## Version: //')

if [ -z "$CURRENT_VERSION" ]; then
    echo -e "${RED}Error: Could not extract version from TOC file${NC}"
    exit 1
fi

echo -e "${YELLOW}Current version:${NC} $CURRENT_VERSION"
echo ""

# Prompt for new version
read -p "Enter new version (or press Enter to keep $CURRENT_VERSION): " NEW_VERSION
NEW_VERSION="${NEW_VERSION:-$CURRENT_VERSION}"

echo ""

# Check if version changed
if [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
    echo -e "${YELLOW}Updating version to $NEW_VERSION...${NC}"
    
    # Update TOC file
    sed -i "s/^## Version: .*$/## Version: $NEW_VERSION/" "$TOC_FILE"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Version updated in TOC file${NC}"
    else
        echo -e "${RED}✗ Failed to update TOC file${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Version unchanged: $CURRENT_VERSION${NC}"
fi

echo ""

# Prompt for changelog entry
echo -e "${YELLOW}Enter changelog entry (comma-separated list of changes):${NC}"
read -p "> " CHANGELOG_INPUT

if [ -n "$CHANGELOG_INPUT" ]; then
    # Check if README exists
    README_FILE="$ADDON_ROOT/README.md"
    
    if [ ! -f "$README_FILE" ]; then
        echo -e "${YELLOW}Warning: README.md not found, skipping changelog update${NC}"
    else
        # Find changelog section
        if grep -q "^## Changelog" "$README_FILE"; then
            echo -e "${YELLOW}Updating changelog in README.md...${NC}"
            
            # Create changelog entry
            CHANGELOG_ENTRY="### $NEW_VERSION\n"
            
            # Split comma-separated input into bullet points
            IFS=',' read -ra CHANGES <<< "$CHANGELOG_INPUT"
            for change in "${CHANGES[@]}"; do
                # Trim whitespace
                change=$(echo "$change" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                CHANGELOG_ENTRY="${CHANGELOG_ENTRY}- $change\n"
            done
            CHANGELOG_ENTRY="${CHANGELOG_ENTRY}\n"
            
            # Insert after "## Changelog" line using awk
            awk -v entry="$CHANGELOG_ENTRY" '
                /^## Changelog/ {
                    print
                    print ""
                    printf "%s", entry
                    next
                }
                { print }
            ' "$README_FILE" > "$README_FILE.tmp"
            
            mv "$README_FILE.tmp" "$README_FILE"
            
            echo -e "${GREEN}✓ Changelog updated${NC}"
        else
            echo -e "${YELLOW}Warning: No '## Changelog' section found in README.md${NC}"
            echo -e "${YELLOW}You'll need to manually add the changelog entry.${NC}"
        fi
    fi
fi

echo ""

# Git operations
echo -e "${YELLOW}Git operations:${NC}"

# Add changes to root addon directory
git -C "$WORKSPACE_ROOT" add "$ADDON_ROOT"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to add files to git${NC}"
    exit 1
fi

# Create commit message
COMMIT_MSG="$ADDON_DISPLAY: Release v$NEW_VERSION"

if [ -n "$CHANGELOG_INPUT" ]; then
    # Add changelog to commit message
    COMMIT_MSG="${COMMIT_MSG}\n\n"
    IFS=',' read -ra CHANGES <<< "$CHANGELOG_INPUT"
    for change in "${CHANGES[@]}"; do
        change=$(echo "$change" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        COMMIT_MSG="${COMMIT_MSG}- $change\n"
    done
fi

# Commit
echo -e "${YELLOW}Committing changes...${NC}"
git -C "$WORKSPACE_ROOT" commit -m "$(echo -e "$COMMIT_MSG")"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Changes committed${NC}"
else
    echo -e "${RED}✗ Failed to commit changes${NC}"
    exit 1
fi

# Create tag
TAG_NAME="${ADDON_PREFIX}-v${NEW_VERSION}"
echo -e "${YELLOW}Creating tag: $TAG_NAME${NC}"

git -C "$WORKSPACE_ROOT" tag -a "$TAG_NAME" -m "$ADDON_DISPLAY v$NEW_VERSION"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Tag created: $TAG_NAME${NC}"
else
    echo -e "${RED}✗ Failed to create tag${NC}"
    exit 1
fi

echo ""

# Push to remote
echo -e "${YELLOW}Ready to push to remote repository${NC}"
read -p "Push commit and tag to origin? (y/n): " PUSH_CONFIRM

if [[ "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Pushing to origin...${NC}"
    
    git -C "$WORKSPACE_ROOT" push origin main
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to push commit${NC}"
        exit 1
    fi
    
    git -C "$WORKSPACE_ROOT" push origin "$TAG_NAME"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to push tag${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Changes pushed to remote${NC}"
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${YELLOW}Tag $TAG_NAME pushed to GitHub${NC}"
    echo -e "${YELLOW}GitHub Actions will create release automatically${NC}"
    echo ""
    echo "View release at:"
    echo "https://github.com/5tuartw/WowAddons/releases/tag/$TAG_NAME"
else
    echo -e "${YELLOW}Skipped push to remote${NC}"
    echo ""
    echo "To push manually later:"
    echo "  git push origin main"
    echo "  git push origin $TAG_NAME"
fi

echo ""
echo "Next steps:"
echo "  1. Wait for GitHub Actions to build the release"
echo "  2. Verify the release on GitHub"
echo "  3. Deploy to game using: ./scripts/deploy_addons.sh"
