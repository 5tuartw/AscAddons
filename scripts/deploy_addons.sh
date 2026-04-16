#!/bin/bash
#
# deploy_addons.sh
# Deploy WoW addons from workspace to Ascension game directory
#

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Windows paths to Ascension AddOns directories (converted to WSL format)
# Order matters: modern ascension-live layout first, legacy Launcher layout second.
LIVE_PATH_CANDIDATES=(
    "/mnt/d/Games/Ascension/resources/ascension-live/Interface/AddOns"
    "/mnt/d/Games/Ascension Launcher/resources/client/Interface/AddOns"
)

PTR_PATH_CANDIDATES=(
    "/mnt/d/Games/Ascension/resources/ascension-ptr/Interface/AddOns"
    "/mnt/d/Games/Ascension Launcher/resources/ascension_ptr/Interface/AddOns"
)

# Allow overrides from environment for custom setups.
ASCENSION_LIVE="${ASCENSION_LIVE_OVERRIDE:-}"
ASCENSION_PTR="${ASCENSION_PTR_OVERRIDE:-}"

resolve_path_from_candidates() {
    local var_name="$1"
    shift
    local candidates=("$@")

    local resolved="${!var_name}"
    if [ -n "$resolved" ]; then
        echo "$resolved"
        return
    fi

    for candidate in "${candidates[@]}"; do
        if [ -d "$candidate" ]; then
            echo "$candidate"
            return
        fi
    done

    # Fall back to first candidate so the validation step prints a useful expected path.
    echo "${candidates[0]}"
}

ASCENSION_LIVE="$(resolve_path_from_candidates ASCENSION_LIVE "${LIVE_PATH_CANDIDATES[@]}")"
ASCENSION_PTR="$(resolve_path_from_candidates ASCENSION_PTR "${PTR_PATH_CANDIDATES[@]}")"

# Workspace addons directory
WORKSPACE_ADDONS="$HOME/workspace/github.com/5tuartw/WowAddons/addons"

# Addons for LIVE servers only (Bronzebeard, Malfurion)
# These are deployed from addons/ subdirectory
LIVE_ONLY_ADDONS=()

# Addons for BOTH live and PTR servers
# These are deployed from addons/ subdirectory
LIVE_AND_PTR_ADDONS=()

# Development addons deployed from addons/ (LIVE + PTR)
# These are actively developed in this repository.
DEV_ADDONS=(
    "AscensionPromptSquelcher"
    "AscensionVanityHelper"
    "AscensionTrinketManager"
    "AutoCollect"
    "DialogueReborn"
    "QuestKeys"
    "ExtraBarsAscension"
)

# Development addons deployed from addons/ (LIVE ONLY)
# For addons that should not go to PTR
DEV_LIVE_ONLY_ADDONS=(
    "MEStats"
)

# Stable addons (uncomment to deploy)
# ADDONS+=(
#     "WRC_DevTools"
#     "WarcraftRebornCollector"
#     "HandyNotes_AscensionRPG"
# )

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}WoW Addon Deployment Script${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Check if directories exist
if [ ! -d "$ASCENSION_LIVE" ]; then
    echo -e "${RED}Error: Ascension Live AddOns directory not found!${NC}"
    echo "Expected: $ASCENSION_LIVE"
    exit 1
fi

if [ ! -d "$ASCENSION_PTR" ]; then
    echo -e "${YELLOW}Warning: Ascension PTR AddOns directory not found!${NC}"
    echo "Expected: $ASCENSION_PTR"
    echo "PTR addons will be skipped."
    echo ""
    HAS_PTR=false
else
    HAS_PTR=true
fi

echo -e "${YELLOW}Live Target:${NC} $ASCENSION_LIVE"
if [ "$HAS_PTR" = true ]; then
    echo -e "${YELLOW}PTR Target:${NC} $ASCENSION_PTR"
fi
echo -e "${YELLOW}Source (addons):${NC} $WORKSPACE_ADDONS"
echo ""

# Prepare deployment tracking
declare -A DEPLOY_STATUS

# Function to deploy addon
deploy_addon() {
    local addon=$1
    local source=$2
    local target=$3
    local label=$4
    
    if [ ! -d "$source" ]; then
        DEPLOY_STATUS["$addon|$label"]="MISSING"
        return 1
    fi
    
    if [ -d "$target" ]; then
        rm -rf "$target" 2>/dev/null
    fi
    
    cp -r "$source" "$target" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        DEPLOY_STATUS["$addon|$label"]="OK"
        return 0
    else
        DEPLOY_STATUS["$addon|$label"]="FAIL"
        return 1
    fi
}

echo -e "${YELLOW}Deploying addons...${NC}"
echo ""

# Deploy LIVE-only addons (from addons/ subdirectory)
for addon in "${LIVE_ONLY_ADDONS[@]}"; do
    deploy_addon "$addon" "$WORKSPACE_ADDONS/$addon" "$ASCENSION_LIVE/$addon" "LIVE"
done

# Deploy LIVE + PTR addons (from addons/ subdirectory)
for addon in "${LIVE_AND_PTR_ADDONS[@]}"; do
    deploy_addon "$addon" "$WORKSPACE_ADDONS/$addon" "$ASCENSION_LIVE/$addon" "LIVE"
    if [ "$HAS_PTR" = true ]; then
        deploy_addon "$addon" "$WORKSPACE_ADDONS/$addon" "$ASCENSION_PTR/$addon" "PTR"
    fi
done

# Deploy development addons (from addons/, to LIVE + PTR)
for addon in "${DEV_ADDONS[@]}"; do
    deploy_addon "$addon" "$WORKSPACE_ADDONS/$addon" "$ASCENSION_LIVE/$addon" "LIVE"
    if [ "$HAS_PTR" = true ]; then
        deploy_addon "$addon" "$WORKSPACE_ADDONS/$addon" "$ASCENSION_PTR/$addon" "PTR"
    fi
done

# Deploy development addons (from addons/, LIVE ONLY)
for addon in "${DEV_LIVE_ONLY_ADDONS[@]}"; do
    deploy_addon "$addon" "$WORKSPACE_ADDONS/$addon" "$ASCENSION_LIVE/$addon" "LIVE"
done

# Print results table
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Deployment Results${NC}"
echo -e "${GREEN}================================================${NC}"
printf "%-35s %-8s %-8s\n" "Addon" "LIVE" "PTR"
echo "------------------------------------------------"

# Function to print status symbol
print_status() {
    local status=$1
    if [ "$status" = "OK" ]; then
        echo -n "✓"
    elif [ "$status" = "FAIL" ]; then
        echo -n "✗"
    elif [ "$status" = "MISSING" ]; then
        echo -n "✗"
    else
        echo -n "-"
    fi
}

# Print all deployed addons
ALL_ADDONS=("${LIVE_ONLY_ADDONS[@]}" "${LIVE_AND_PTR_ADDONS[@]}" "${DEV_ADDONS[@]}" "${DEV_LIVE_ONLY_ADDONS[@]}")
for addon in "${ALL_ADDONS[@]}"; do
    live_status=$(print_status "${DEPLOY_STATUS[$addon|LIVE]}")
    ptr_status=$(print_status "${DEPLOY_STATUS[$addon|PTR]:-N/A}")
    
    # Format addon name with padding
    addon_padded=$(printf "%-35s" "$addon")
    
    # Color the status symbols
    if [ "$live_status" = "✓" ]; then
        live_colored="${GREEN}✓${NC}"
    elif [ "$live_status" = "✗" ]; then
        live_colored="${RED}✗${NC}"
    else
        live_colored="${YELLOW}-${NC}"
    fi
    
    if [ "$ptr_status" = "✓" ]; then
        ptr_colored="${GREEN}✓${NC}"
    elif [ "$ptr_status" = "✗" ]; then
        ptr_colored="${RED}✗${NC}"
    else
        ptr_colored="${YELLOW}-${NC}"
    fi
    
    # Print with proper spacing (8 spaces for each column)
    echo -e "${addon_padded} ${live_colored}        ${ptr_colored}"
done

echo ""
