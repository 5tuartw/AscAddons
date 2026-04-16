#!/bin/bash
#
# verify_git_sync.sh
# Verify that git repositories are properly set up for Windows sync tool
#

ADDONS_DIR="/mnt/d/Games/Ascension Launcher/resources/client/Interface/AddOns"
GIT_REPOS_DIR="${ADDONS_DIR}/.git-repos"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Git Sync Verification ===${NC}\n"

# Check if git-repos directory exists
if [ -d "${GIT_REPOS_DIR}" ]; then
    echo -e "${GREEN}✓ .git-repos directory exists${NC}"
else
    echo -e "${RED}✗ .git-repos directory not found${NC}"
    echo -e "  Run: ./scripts/setup_addon_git_sync.sh"
    exit 1
fi

# Count single-folder addons with .git
echo -e "\n${BLUE}Single-Folder Addons:${NC}"
single_count=0
for addon in AllStats Bartender4 Details MikScrollingBattleText MoveAnything OmniCC pfQuest Postal ProfessionMenu WeakAuras YATP; do
    if [ -d "${ADDONS_DIR}/${addon}/.git" ]; then
        echo -e "${GREEN}  ✓ ${addon}${NC}"
        ((single_count++))
    else
        echo -e "${RED}  ✗ ${addon}${NC}"
    fi
done
echo -e "  Total: ${single_count}/11"

# Check multi-folder addons
echo -e "\n${BLUE}Multi-Folder Addons:${NC}"

# AtlasLoot
echo -e "\n  ${YELLOW}AtlasLoot:${NC}"
if [ -d "${GIT_REPOS_DIR}/AtlasLoot/.git" ]; then
    echo -e "    ${GREEN}✓ Repository cloned${NC}"
    atlas_count=0
    for folder in AtlasLoot AtlasLoot_BurningCrusade AtlasLoot_Cache AtlasLoot_Crafting_OriginalWoW AtlasLoot_Crafting_TBC AtlasLoot_Crafting_Wrath AtlasLoot_OriginalWoW AtlasLoot_Vanity AtlasLoot_WorldEvents AtlasLoot_WrathoftheLichKing; do
        if [ -L "${ADDONS_DIR}/${folder}" ]; then
            ((atlas_count++))
        fi
    done
    echo -e "    ${GREEN}✓ ${atlas_count}/10 folders symlinked${NC}"
else
    echo -e "    ${RED}✗ Repository not found${NC}"
fi

# Bagnon
echo -e "\n  ${YELLOW}Bagnon:${NC}"
if [ -d "${GIT_REPOS_DIR}/Bagnon/.git" ]; then
    echo -e "    ${GREEN}✓ Repository cloned${NC}"
    bagnon_count=0
    for folder in Bagnon Bagnon_Config Bagnon_Forever Bagnon_GuildBank Bagnon_Tooltips; do
        if [ -L "${ADDONS_DIR}/${folder}" ]; then
            ((bagnon_count++))
        fi
    done
    echo -e "    ${GREEN}✓ ${bagnon_count}/5 folders symlinked${NC}"
else
    echo -e "    ${RED}✗ Repository not found${NC}"
fi

# DBM
echo -e "\n  ${YELLOW}DeadlyBossMods:${NC}"
if [ -d "${GIT_REPOS_DIR}/DeadlyBossMods/.git" ]; then
    echo -e "    ${GREEN}✓ Repository cloned${NC}"
    dbm_count=$(find "${ADDONS_DIR}" -maxdepth 1 -type l -name "DBM*" | wc -l)
    echo -e "    ${GREEN}✓ ${dbm_count} DBM folders symlinked${NC}"
else
    echo -e "    ${RED}✗ Repository not found${NC}"
fi

# Manual addons
echo -e "\n${BLUE}Manual Addons (Not Git-Tracked):${NC}"
if [ -d "${ADDONS_DIR}/AnnoyingPopupRemover" ]; then
    echo -e "${YELLOW}  ⚠ AnnoyingPopupRemover (no git repo available)${NC}"
fi
if [ -d "${ADDONS_DIR}/Auctionator" ]; then
    echo -e "${YELLOW}  ⚠ Auctionator (not a git source)${NC}"
fi

# Summary
echo -e "\n${BLUE}=== Summary ===${NC}"
total_git=$(find "${ADDONS_DIR}" -maxdepth 1 -type d -name ".git" | wc -l)
total_repos=$(find "${GIT_REPOS_DIR}" -maxdepth 1 -type d -name ".git" 2>/dev/null | wc -l)
total_symlinks=$(find "${ADDONS_DIR}" -maxdepth 1 -type l | wc -l)

echo -e "  Git repos (direct): ${total_git}"
echo -e "  Git repos (.git-repos): ${total_repos}"
echo -e "  Symlinked folders: ${total_symlinks}"
echo -e "\n${GREEN}Your Windows sync tool should detect these repositories!${NC}"

# Test one repo status
echo -e "\n${BLUE}=== Sample Git Status ===${NC}"
if [ -d "${ADDONS_DIR}/AllStats/.git" ]; then
    cd "${ADDONS_DIR}/AllStats"
    echo -e "${YELLOW}AllStats:${NC}"
    git remote -v | head -2
    git branch --show-current
fi

echo ""
