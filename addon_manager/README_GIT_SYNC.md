# Git Sync Setup for Ascension Addons

## Overview
This setup enables Windows-based git monitoring tools to automatically update your WoW addons by ensuring each addon folder has proper git tracking.

## Architecture

### Single-Folder Addons
These addons are cloned directly into the AddOns folder:
```
AddOns/
├── AllStats/.git          ← Git repo directly in addon folder
├── Bartender4/.git
├── Details/.git
└── ...
```

### Multi-Folder Addons
These addons have one git repository but create multiple addon folders. They use a centralized repo with symlinks:
```
AddOns/
├── .git-repos/                    ← Hidden folder with actual repos
│   ├── AtlasLoot/.git
│   ├── Bagnon/.git
│   └── DeadlyBossMods/.git
├── AtlasLoot → .git-repos/AtlasLoot/AtlasLoot
├── AtlasLoot_Cache → .git-repos/AtlasLoot/AtlasLoot_Cache
├── Bagnon → .git-repos/Bagnon/Bagnon
└── DBM-Core → .git-repos/DeadlyBossMods/DBM-Core
```

## Setup Instructions

### Initial Setup
```bash
cd ~/workspace/github.com/5tuartw/WowAddons
chmod +x scripts/setup_addon_git_sync.sh
./scripts/setup_addon_git_sync.sh
```

This script will:
1. Clone all git repositories with correct branches
2. Backup any existing addon folders
3. Create symlinks for multi-folder addons
4. Set up proper git tracking for your Windows sync tool

### What Gets Synced

**✓ Git-Tracked Addons (15 addons):**
- AllStats, Bartender4, Details, MikScrollingBattleText
- LootCollector, MoveAnything, Omen, OmniCC, pfQuest, ProfessionMenu
- WeakAuras, YATP
- AtlasLoot (10 folders), Bagnon (5 folders), DBM (many folders)

**⚠ Manual Management Required (2 addons):**
- **AnnoyingPopupRemover**: No repository found
- **Auctionator**: Downloaded from warperia.com (not a git repo)

## Windows Sync Tool Compatibility

Your Windows git monitoring tool should:
- Scan `D:\Games\Ascension\resources\ascension-live\Interface\AddOns\`
- Detect `.git` folders in each addon directory
- Follow symlinks to `.git-repos/` for multi-folder addons

### If Tool Doesn't Follow Symlinks
If your sync tool can't follow symlinks, you have two options:

**Option 1**: Configure tool to also monitor:
- `D:\Games\Ascension\resources\ascension-live\Interface\AddOns\.git-repos\`

**Option 2**: Use git worktrees instead (requires script modification)

## Branch Information

Most repos use `main`; a few still use `master`:
- **main branch**: AllStats, Bartender4, Bagnon, DeadlyBossMods, LootCollector, MoveAnything, Omen, ProfessionMenu, YATP, MikScrollingBattleText, OmniCC, pfQuest
- **master branch**: AtlasLoot, Details, WeakAuras

The setup script automatically uses the correct branch for each addon.

## Maintenance Commands

### Check Git Status of All Addons
```bash
cd "/mnt/d/Games/Ascension/resources/ascension-live/Interface/AddOns"
for dir in */; do
    if [ -d "$dir/.git" ] || [ -L "$dir" ]; then
        echo "=== $dir ==="
        if [ -L "$dir" ]; then
            target=$(readlink "$dir")
            cd "$target"
            git status -s
            cd - > /dev/null
        else
            cd "$dir"
            git status -s
            cd - > /dev/null
        fi
    fi
done
```

### Manually Update All Addons
```bash
cd ~/workspace/github.com/5tuartw/WowAddons
./scripts/setup_addon_git_sync.sh  # Re-run to pull latest
```

### Check Which Addons Need Updates
```bash
cd "/mnt/d/Games/Ascension/resources/ascension-live/Interface/AddOns"
for dir in .git-repos/*/; do
    cd "$dir"
    echo "=== $(basename $PWD) ==="
    git fetch
    git status -uno
    cd - > /dev/null
done
```

## Troubleshooting

### Addon Not Loading After Sync
1. Check if it's a symlink: `ls -la AddOns/AddonName`
2. Verify target exists: `ls -la AddOns/.git-repos/RepoName/`
3. Check .toc file exists in final location

### Windows Tool Not Detecting Repos
1. Verify .git folders exist:
   ```bash
    find "/mnt/d/Games/Ascension/resources/ascension-live/Interface/AddOns" -name ".git" -type d
   ```

2. Check symlinks are valid:
   ```bash
    find "/mnt/d/Games/Ascension/resources/ascension-live/Interface/AddOns" -type l -ls
   ```

### Backup Folders Cluttering Directory
Old backups are named with timestamps: `AddonName.backup.20251230_143022`

Safe to delete once you've verified the new setup works:
```bash
cd "/mnt/d/Games/Ascension/resources/ascension-live/Interface/AddOns"
rm -rf *.backup.*
```

## Configuration File

See `git_sync_config.json` for the master configuration of all repos, branches, and folder mappings.

## Future Enhancements

Potential additions:
- Python script to check for updates without pulling
- Auto-generate update report (what changed in each addon)
- Handle Auctionator with web scraping/API checking
- Add version tracking in SavedVariables
