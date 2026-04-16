#!/bin/bash
#
# fix_multi_folder_symlinks.sh
# Replace WSL symlinks with Windows directory junctions for multi-folder addons
# This makes them compatible with Windows tools
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

ADDONS_DIR="/mnt/d/Games/Ascension Launcher/resources/client/Interface/AddOns"
GIT_REPOS_DIR="${ADDONS_DIR}/.git-repos"
BACKUP_DIR="${ADDONS_DIR}/_backups"

echo -e "${BLUE}=== Fixing Multi-Folder Addon Symlinks ===${NC}\n"

# Step 1: Move all backup folders to _backups
echo -e "${YELLOW}Step 1: Organizing backup folders${NC}"
mkdir -p "${BACKUP_DIR}"
cd "${ADDONS_DIR}"
for backup in *.backup.*; do
    if [ -d "$backup" ]; then
        echo "  Moving: $backup"
        mv "$backup" "${BACKUP_DIR}/"
    fi
done
echo -e "${GREEN}✓ Backups organized${NC}\n"

# Step 2: Remove WSL symlinks and create Windows junctions instead
echo -e "${YELLOW}Step 2: Converting symlinks to Windows junctions${NC}"

create_junction() {
    local addon_name=$1
    local repo_name=$2
    local subfolder=$3
    
    local link_path="${ADDONS_DIR}/${addon_name}"
    local target_path="${GIT_REPOS_DIR}/${repo_name}/${subfolder}"
    
    # Convert to Windows paths for mklink
    local win_link_path=$(wslpath -w "$link_path")
    local win_target_path=$(wslpath -w "$target_path")
    
    # Remove existing symlink
    if [ -L "$link_path" ]; then
        rm "$link_path"
        echo "  Removed symlink: $addon_name"
    fi
    
    # Create Windows junction using cmd.exe
    if [ -d "$target_path" ]; then
        cmd.exe /c "mklink /J \"$win_link_path\" \"$win_target_path\"" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓ Junction created: $addon_name${NC}"
        else
            echo -e "  ${RED}✗ Failed: $addon_name${NC}"
        fi
    else
        echo -e "  ${RED}✗ Source not found: $subfolder${NC}"
    fi
}

# AtlasLoot
echo -e "\n${BLUE}AtlasLoot:${NC}"
for folder in AtlasLoot AtlasLoot_BurningCrusade AtlasLoot_Cache AtlasLoot_Crafting_OriginalWoW AtlasLoot_Crafting_TBC AtlasLoot_Crafting_Wrath AtlasLoot_OriginalWoW AtlasLoot_Vanity AtlasLoot_WorldEvents AtlasLoot_WrathoftheLichKing; do
    create_junction "$folder" "AtlasLoot" "$folder"
done

# Bagnon
echo -e "\n${BLUE}Bagnon:${NC}"
for folder in Bagnon Bagnon_Config Bagnon_Forever Bagnon_GuildBank Bagnon_Tooltips; do
    create_junction "$folder" "Bagnon" "$folder"
done

# MikScrollingBattleText
echo -e "\n${BLUE}MikScrollingBattleText:${NC}"
create_junction "MikScrollingBattleText" "MikScrollingBattleText" "MikScrollingBattleText"
create_junction "MSBTOptions" "MikScrollingBattleText" "MSBTOptions"

# OmniCC
echo -e "\n${BLUE}OmniCC:${NC}"
create_junction "OmniCC" "OmniCC" "OmniCC"
create_junction "OmniCC_Config" "OmniCC" "OmniCC_Config"

# pfQuest
echo -e "\n${BLUE}pfQuest:${NC}"
create_junction "pfQuest" "pfQuest" "pfQuest"
create_junction "pfQuest-ascension" "pfQuest" "pfQuest-ascension"

# WeakAuras
echo -e "\n${BLUE}WeakAuras:${NC}"
for folder in WeakAuras WeakAurasArchive WeakAurasModelPaths WeakAurasOptions WeakAurasStopMotion WeakAurasTemplates; do
    create_junction "$folder" "WeakAuras-Ascension" "$folder"
done

# DBM - auto-detect all DBM folders
echo -e "\n${BLUE}DeadlyBossMods:${NC}"
if [ -d "${GIT_REPOS_DIR}/DeadlyBossMods" ]; then
    cd "${GIT_REPOS_DIR}/DeadlyBossMods"
    for dbm_folder in DBM*; do
        if [ -d "$dbm_folder" ]; then
            create_junction "$dbm_folder" "DeadlyBossMods" "$dbm_folder"
        fi
    done
fi

echo -e "\n${GREEN}=== Complete! ===${NC}"
echo -e "\n${YELLOW}Note:${NC} Windows junctions work like folders in Windows but point to the git repos."
echo -e "Your sync tool should now be able to detect and update these addons.\n"
