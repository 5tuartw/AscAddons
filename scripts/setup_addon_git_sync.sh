#!/bin/bash
#
# setup_addon_git_sync.sh
# Initialize git repositories in Ascension AddOns folder for automated sync tools
#
# This script handles:
# - Single-folder addons: Clone directly into AddOns folder
# - Multi-folder addons: Clone to .git-repos/, create symlinks in AddOns folder
# - Branch detection: Uses main/master as appropriate
#

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Target directory
# Order matters: modern ascension-live layout first, legacy Launcher layout second.
ADDONS_PATH_CANDIDATES=(
    "/mnt/d/Games/Ascension/resources/ascension-live/Interface/AddOns"
    "/mnt/d/Games/Ascension Launcher/resources/client/Interface/AddOns"
)

resolve_path_from_candidates() {
    local override="$1"
    shift
    local candidates=("$@")

    if [ -n "$override" ]; then
        echo "$override"
        return
    fi

    for candidate in "${candidates[@]}"; do
        if [ -d "$candidate" ]; then
            echo "$candidate"
            return
        fi
    done

    echo "${candidates[0]}"
}

ADDONS_DIR="$(resolve_path_from_candidates "${ADDONS_DIR_OVERRIDE:-}" "${ADDONS_PATH_CANDIDATES[@]}")"
GIT_REPOS_DIR="${ADDONS_DIR}/.git-repos"

echo -e "${BLUE}=== Ascension Addon Git Sync Setup ===${NC}\n"

if [ ! -d "${ADDONS_DIR}" ]; then
    echo -e "${RED}AddOns directory not found:${NC} ${ADDONS_DIR}"
    echo -e "Set ADDONS_DIR_OVERRIDE to your actual path and rerun."
    exit 1
fi

# Create hidden directory for multi-folder addon repos
mkdir -p "${GIT_REPOS_DIR}"

# Function to clone or update a repo
setup_single_addon() {
    local addon_name=$1
    local repo_url=$2
    local branch=${3:-master}
    
    echo -e "${YELLOW}Setting up: ${addon_name}${NC}"
    
    local target_dir="${ADDONS_DIR}/${addon_name}"
    
    if [ -d "${target_dir}/.git" ]; then
        echo -e "${GREEN}  ✓ Already git-tracked${NC}"
        cd "${target_dir}"
        git remote set-url origin "${repo_url}" 2>/dev/null || git remote add origin "${repo_url}"
        git fetch origin
        git checkout "${branch}" 2>/dev/null || git checkout -b "${branch}" "origin/${branch}"
        git pull origin "${branch}"
    elif [ -d "${target_dir}" ]; then
        echo -e "${YELLOW}  → Backing up existing folder${NC}"
        mv "${target_dir}" "${target_dir}.backup.$(date +%Y%m%d_%H%M%S)"
        git clone -b "${branch}" "${repo_url}" "${target_dir}"
    else
        git clone -b "${branch}" "${repo_url}" "${target_dir}"
    fi
    
    echo -e "${GREEN}  ✓ Complete${NC}\n"
}

# Function to setup multi-folder addon (one repo, multiple addon folders)
setup_multi_addon() {
    local repo_name=$1
    local repo_url=$2
    local branch=${3:-master}
    shift 3
    local addon_folders=("$@")
    
    echo -e "${YELLOW}Setting up multi-folder: ${repo_name}${NC}"
    
    local repo_dir="${GIT_REPOS_DIR}/${repo_name}"
    
    # Clone or update the main repo
    if [ -d "${repo_dir}/.git" ]; then
        echo -e "${GREEN}  ✓ Repo exists, updating${NC}"
        cd "${repo_dir}"
        git remote set-url origin "${repo_url}" 2>/dev/null || git remote add origin "${repo_url}"
        git fetch origin
        git checkout "${branch}" 2>/dev/null || git checkout -b "${branch}" "origin/${branch}"
        git pull origin "${branch}"
    else
        echo -e "${YELLOW}  → Cloning repository${NC}"
        git clone -b "${branch}" "${repo_url}" "${repo_dir}"
    fi
    
    # Create .git folders in each addon subfolder (for sync tool detection)
    echo -e "${BLUE}  → Setting up .git references in addon folders${NC}"
    for folder in "${addon_folders[@]}"; do
        local addon_path="${ADDONS_DIR}/${folder}"
        local repo_subfolder="${repo_dir}/${folder}"
        
        if [ -d "${repo_subfolder}" ]; then
            # Backup existing addon folder if not a symlink
            if [ -d "${addon_path}" ] && [ ! -L "${addon_path}" ]; then
                echo -e "${YELLOW}    Backing up: ${folder}${NC}"
                rm -rf "${addon_path}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
                mv "${addon_path}" "${addon_path}.backup.$(date +%Y%m%d_%H%M%S)"
            fi
            
            # Remove old symlink if exists
            [ -L "${addon_path}" ] && rm "${addon_path}"
            
            # Create symlink
            ln -sf "${repo_subfolder}" "${addon_path}"
            echo -e "${GREEN}    ✓ Linked: ${folder}${NC}"
        else
            echo -e "${RED}    ✗ Not found in repo: ${folder}${NC}"
        fi
    done
    
    echo -e "${GREEN}  ✓ Complete${NC}\n"
}

# === SINGLE-FOLDER ADDONS ===
echo -e "${BLUE}=== Single-Folder Addons ===${NC}\n"

setup_single_addon "AllStats" "https://github.com/Ascension-Addons/AllStats" "main"
setup_single_addon "Bartender4" "https://github.com/Ascension-Addons/Bartender4" "main"
setup_single_addon "Details" "https://github.com/Ascension-Addons/Details-Damage-Meter" "master"
setup_single_addon "LootCollector" "https://github.com/mmobrain/LootCollector/" "main"
setup_single_addon "MoveAnything" "https://github.com/Ascension-Addons/MoveAnything" "main"
setup_single_addon "Omen" "https://github.com/Ascension-Addons/Omen" "main"
setup_single_addon "ProfessionMenu" "https://github.com/Ascension-Addons/ProfessionMenu" "main"
setup_single_addon "YATP" "https://github.com/zavahcodes/YATP" "main"

# === MULTI-FOLDER ADDONS ===
echo -e "${BLUE}=== Multi-Folder Addons ===${NC}\n"

# AtlasLoot (10 folders)
setup_multi_addon "AtlasLoot" "https://github.com/Ascension-Addons/AtlasLoot" "master" \
    "AtlasLoot" \
    "AtlasLoot_BurningCrusade" \
    "AtlasLoot_Cache" \
    "AtlasLoot_Crafting_OriginalWoW" \
    "AtlasLoot_Crafting_TBC" \
    "AtlasLoot_Crafting_Wrath" \
    "AtlasLoot_OriginalWoW" \
    "AtlasLoot_Vanity" \
    "AtlasLoot_WorldEvents" \
    "AtlasLoot_WrathoftheLichKing"

# Bagnon (5 folders)
setup_multi_addon "Bagnon" "https://github.com/Ascension-Addons/Bagnon" "main" \
    "Bagnon" \
    "Bagnon_Config" \
    "Bagnon_Forever" \
    "Bagnon_GuildBank" \
    "Bagnon_Tooltips"

# MikScrollingBattleText (2 folders)
setup_multi_addon "MikScrollingBattleText" "https://github.com/Ascension-Addons/MikScrollingBattleText" "main" \
    "MikScrollingBattleText" \
    "MSBTOptions"

# OmniCC (2 folders)
setup_multi_addon "OmniCC" "https://github.com/Ascension-Addons/OmniCC" "main" \
    "OmniCC" \
    "OmniCC_Config"

# pfQuest (2 folders)
setup_multi_addon "pfQuest" "https://github.com/Ascension-Addons/pfQuest" "main" \
    "pfQuest" \
    "pfQuest-ascension"

# WeakAuras (5 folders tracked in addon_manager)
setup_multi_addon "WeakAuras-Ascension" "https://github.com/Ascension-Addons/WeakAuras-Ascension" "master" \
    "WeakAuras" \
    "WeakAurasArchive" \
    "WeakAurasModelPaths" \
    "WeakAurasOptions" \
    "WeakAurasTemplates"

# DBM (checking what folders exist first)
echo -e "${YELLOW}Setting up DBM (DeadlyBossMods)...${NC}"
DBM_REPO="${GIT_REPOS_DIR}/DeadlyBossMods"
if [ ! -d "${DBM_REPO}" ]; then
    git clone -b main "https://github.com/Ascension-Addons/DeadlyBossMods" "${DBM_REPO}"
fi

# Find all DBM-related folders in the repo
cd "${DBM_REPO}"
DBM_FOLDERS=($(find . -maxdepth 1 -type d -name "DBM*" | sed 's|./||' | sort))
echo -e "${BLUE}  Found ${#DBM_FOLDERS[@]} DBM folders in repository${NC}"

# Link each DBM folder
for folder in "${DBM_FOLDERS[@]}"; do
    addon_path="${ADDONS_DIR}/${folder}"
    repo_subfolder="${DBM_REPO}/${folder}"
    
    if [ -d "${addon_path}" ] && [ ! -L "${addon_path}" ]; then
        rm -rf "${addon_path}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        mv "${addon_path}" "${addon_path}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    [ -L "${addon_path}" ] && rm "${addon_path}"
    ln -sf "${repo_subfolder}" "${addon_path}"
    echo -e "${GREEN}  ✓ Linked: ${folder}${NC}"
done

echo -e "\n${GREEN}=== Setup Complete! ===${NC}\n"
echo -e "${BLUE}Summary:${NC}"
echo -e "  • Single-folder addons: Cloned directly with .git folders"
echo -e "  • Multi-folder addons: Cloned to ${GIT_REPOS_DIR}/, symlinked to AddOns/"
echo -e "  • Your Windows sync tool should now detect all .git folders"
echo -e "\n${YELLOW}Notes:${NC}"
echo -e "  • AnnoyingPopupRemover: No git repo found - needs manual management"
echo -e "  • Auctionator: Not a git repo (warperia.com) - needs manual updates"
echo -e "\n${BLUE}Next Steps:${NC}"
echo -e "  1. Test your Windows git sync tool"
echo -e "  2. Verify it detects repos in: ${ADDONS_DIR}"
echo -e "  3. Check if it follows symlinks to: ${GIT_REPOS_DIR}"
echo -e ""
