#!/bin/bash
# Package addons for GitHub releases
# Usage: ./create_release.sh <addon_name> <version>
# Example: ./create_release.sh MEStats 1.0.0

set -e

ADDON_NAME="$1"
VERSION="$2"

if [ -z "$ADDON_NAME" ] || [ -z "$VERSION" ]; then
    echo "Usage: $0 <addon_name> <version>"
    echo "Example: $0 MEStats 1.0.0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
ADDON_PATH="$REPO_ROOT/addons/$ADDON_NAME"
RELEASE_DIR="$REPO_ROOT/releases"
TEMP_DIR="$REPO_ROOT/temp/release"

# Validation
if [ ! -d "$ADDON_PATH" ]; then
    echo "❌ Error: Addon not found at $ADDON_PATH"
    exit 1
fi

if [ ! -f "$ADDON_PATH/$ADDON_NAME.toc" ]; then
    echo "❌ Error: TOC file not found: $ADDON_NAME.toc"
    exit 1
fi

# Create release directory
mkdir -p "$RELEASE_DIR"
mkdir -p "$TEMP_DIR"

# Clean temp
rm -rf "$TEMP_DIR/$ADDON_NAME"

# Copy addon
echo "📦 Packaging $ADDON_NAME v$VERSION..."
cp -r "$ADDON_PATH" "$TEMP_DIR/"

# Remove any dev files from package
find "$TEMP_DIR/$ADDON_NAME" -name "*.md" -delete
find "$TEMP_DIR/$ADDON_NAME" -name ".git*" -delete

# Create zip
ZIP_NAME="${ADDON_NAME}-v${VERSION}.zip"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"

cd "$TEMP_DIR"
zip -r "$ZIP_PATH" "$ADDON_NAME" -q

# Cleanup
cd "$REPO_ROOT"
rm -rf "$TEMP_DIR"

# Report
SIZE=$(du -h "$ZIP_PATH" | cut -f1)
echo "✅ Created release: $ZIP_NAME ($SIZE)"
echo "   Location: $ZIP_PATH"
echo ""
echo "Next steps:"
echo "1. Create a GitHub release tagged v$VERSION"
echo "2. Upload: $ZIP_PATH"
echo "3. Write release notes"
