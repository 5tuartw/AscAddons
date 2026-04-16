#!/bin/bash
# LootCollector Git Sync Script
# Keeps a local git clone of LootCollector and syncs updates

REPO_URL="https://github.com/mmobrain/LootCollector.git"
GIT_CLONE_PATH="$HOME/workspace/github.com/5tuartw/WowAddons/archive/addons/other-creators/LootCollector_git"
GAME_ADDON_PATH="/mnt/d/Games/Ascension Launcher/resources/client/Interface/AddOns/LootCollector"
BACKUP_PATH="$HOME/workspace/github.com/5tuartw/WowAddons/archive/addons/other-creators/LootCollector_backups"

echo "============================================"
echo "LootCollector Git Sync"
echo "============================================"
echo ""

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Check if git clone exists
if [ ! -d "$GIT_CLONE_PATH/.git" ]; then
    echo "📦 Cloning LootCollector repository..."
    git clone "$REPO_URL" "$GIT_CLONE_PATH"
    if [ $? -ne 0 ]; then
        echo "❌ Failed to clone repository"
        exit 1
    fi
    echo "✅ Repository cloned successfully"
else
    echo "📁 Repository already exists at: $GIT_CLONE_PATH"
fi

# Get current version from git
cd "$GIT_CLONE_PATH" || exit 1
CURRENT_COMMIT=$(git rev-parse HEAD)
CURRENT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "no-tag")

echo ""
echo "Current state:"
echo "  Commit: ${CURRENT_COMMIT:0:8}"
echo "  Tag:    $CURRENT_TAG"

# Fetch latest changes
echo ""
echo "🔄 Fetching latest changes..."
git fetch origin

# Get latest version
LATEST_COMMIT=$(git rev-parse origin/main)
LATEST_TAG=$(git describe --tags --abbrev=0 origin/main 2>/dev/null || echo "no-tag")

echo "Latest on GitHub:"
echo "  Commit: ${LATEST_COMMIT:0:8}"
echo "  Tag:    $LATEST_TAG"

# Check if update is available
if [ "$CURRENT_COMMIT" == "$LATEST_COMMIT" ]; then
    echo ""
    echo "✅ Already up to date!"
    
    # Show comparison with installed version
    if [ -f "$GAME_ADDON_PATH/LootCollector.toc" ]; then
        INSTALLED_VERSION=$(grep "^## Version:" "$GAME_ADDON_PATH/LootCollector.toc" | cut -d: -f2 | xargs)
        echo ""
        echo "Installed in game: $INSTALLED_VERSION"
        echo "Latest in git:     $LATEST_TAG"
    fi
    exit 0
fi

# Show what changed
echo ""
echo "📋 Changes since your version:"
git log --oneline --graph --decorate "$CURRENT_COMMIT..$LATEST_COMMIT" | head -20

# Ask user if they want to update
echo ""
read -p "Would you like to update to the latest version? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Update cancelled"
    exit 0
fi

# Backup current game addon if it exists
if [ -d "$GAME_ADDON_PATH" ]; then
    BACKUP_NAME="LootCollector_backup_$(date +%Y%m%d_%H%M%S)"
    echo ""
    echo "💾 Backing up current game addon..."
    cp -r "$GAME_ADDON_PATH" "$BACKUP_PATH/$BACKUP_NAME"
    echo "✅ Backup saved: $BACKUP_NAME"
fi

# Pull latest changes
echo ""
echo "⬇️  Pulling latest changes..."
git pull origin main

if [ $? -ne 0 ]; then
    echo "❌ Failed to pull updates"
    exit 1
fi

# Copy to game addon folder
echo ""
echo "📂 Installing to game folder..."

# Remove old version
rm -rf "$GAME_ADDON_PATH"

# Copy new version (exclude git metadata)
rsync -av --exclude='.git' --exclude='.gitignore' --exclude='README.md' --exclude='CONTRIBUTING.md' \
    "$GIT_CLONE_PATH/" "$GAME_ADDON_PATH/"

if [ $? -ne 0 ]; then
    echo "❌ Failed to copy addon to game folder"
    exit 1
fi

# Get new version
NEW_VERSION=$(grep "^## Version:" "$GAME_ADDON_PATH/LootCollector.toc" | cut -d: -f2 | xargs)
NEW_COMMIT=$(git -C "$GIT_CLONE_PATH" rev-parse HEAD)

echo ""
echo "============================================"
echo "✅ LootCollector updated successfully!"
echo "============================================"
echo ""
echo "New version: $NEW_VERSION"
echo "Commit:      ${NEW_COMMIT:0:8}"
echo ""
echo "Restart WoW to use the updated addon"
echo ""
echo "Backup location: $BACKUP_PATH"
