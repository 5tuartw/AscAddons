#!/bin/bash
#
# detect_multi_folder_addons.sh
# Check which git repos contain multiple addon folders
#

TEMP_DIR="/tmp/addon_detection_$$"
mkdir -p "$TEMP_DIR"

echo "=== Detecting Multi-Folder Addons ==="
echo ""

check_repo() {
    local name=$1
    local url=$2
    local branch=$3
    
    echo "Checking: $name"
    cd "$TEMP_DIR"
    
    # Shallow clone to save time
    git clone --depth 1 -b "$branch" "$url" "$name" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        cd "$name"
        
        # Find folders with .toc files (these are addon folders)
        toc_folders=$(find . -maxdepth 2 -name "*.toc" -exec dirname {} \; | sed 's|^\./||' | sort -u)
        toc_count=$(echo "$toc_folders" | wc -l)
        
        if [ $toc_count -gt 1 ]; then
            echo "  ✓ MULTI-FOLDER: $toc_count folders found"
            echo "$toc_folders" | sed 's/^/    - /'
        else
            echo "  → Single folder"
        fi
    else
        echo "  ✗ Failed to clone"
    fi
    echo ""
}

# Check all single-folder addons we're planning to set up
check_repo "AllStats" "https://github.com/Ascension-Addons/AllStats" "main"
check_repo "Bartender4" "https://github.com/Ascension-Addons/Bartender4" "main"
check_repo "Details" "https://github.com/Ascension-Addons/Details-Damage-Meter" "master"
check_repo "MikScrollingBattleText" "https://github.com/Ascension-Addons/MikScrollingBattleText" "main"
check_repo "MoveAnything" "https://github.com/Ascension-Addons/MoveAnything" "main"
check_repo "OmniCC" "https://github.com/Ascension-Addons/OmniCC" "main"
check_repo "pfQuest" "https://github.com/Ascension-Addons/pfQuest" "main"
check_repo "Postal" "https://github.com/Ascension-Addons/Postal" "main"
check_repo "ProfessionMenu" "https://github.com/Ascension-Addons/ProfessionMenu" "main"
check_repo "WeakAuras" "https://github.com/Ascension-Addons/WeakAuras-Ascension" "master"
check_repo "YATP" "https://github.com/zavahcodes/YATP" "main"

# Verify the known multi-folder ones
echo "=== Verifying Known Multi-Folder Addons ==="
check_repo "AtlasLoot" "https://github.com/Ascension-Addons/AtlasLoot" "master"
check_repo "Bagnon" "https://github.com/Ascension-Addons/Bagnon" "main"
check_repo "DeadlyBossMods" "https://github.com/Ascension-Addons/DeadlyBossMods" "main"

# Cleanup
rm -rf "$TEMP_DIR"

echo "=== Detection Complete ==="
