# WoW Addon Manager

A powerful, menu-driven tool for managing GitHub-hosted WoW addons for Ascension with automatic SavedVariables backup.

## Features

✅ **Onboarding Auto-Detection**: Detects addon folders and SavedVariables when adding a new repo  
✅ **Menu-Driven Interface**: Easy-to-use CLI with checkbox selection  
✅ **Multi-Client Support**: Manage both Live and PTR clients  
✅ **Automatic Backups**: Always backs up SavedVariables before updating  
✅ **Update Checking**: Compare local vs remote versions  
✅ **Inventory Scan (Report-Only)**: Compare tracked config vs installed AddOns folders without changing config  
✅ **Manual Backups**: Create SavedVariables backups on demand  
✅ **Backup History**: View and manage backup history  

## Quick Start

### 1. Setup (First Time Only)
```bash
cd addon_manager
./setup.sh
```

This creates a virtual environment and installs dependencies.

### 2. Configure Game Paths
Edit `config.json` and verify your game client paths are correct:
```json
"game_clients": {
  "ascension_live": {
    "addons_path": "/mnt/d/Games/Ascension/resources/ascension-live/Interface/AddOns",
    "wtf_path": "/mnt/d/Games/Ascension/resources/ascension-live/WTF",
    "enabled": true
  }
}
```

### 3. Run the Manager

**Easy way** (handles venv automatically):
```bash
./run.sh
```

**Manual way**:
```bash
source venv/bin/activate
python3 addon_manager.py
```

## Usage Guide

### Main Menu

When you run the manager, you'll see:

```
======================================================================
  WoW Addon Manager for Ascension
======================================================================

📦 Currently tracking 2 addon(s)

  Tracked addons:
    ✓ WeakAuras-Ascension
    ✓ Details-335

? What would you like to do?
  ❯ Check for updates
    Scan AddOns inventory (report only)
    Add addon to tracking
    Remove addon from tracking
    List tracked addons
    Create SavedVariables backup
    View backup history
    Settings
    Exit
```

### Scan AddOns Inventory (Report-Only)

Select **"Scan AddOns inventory (report only)"** to compare each client's actual AddOns folder with tracked config entries.

The scan reports:
- Tracked addons fully installed
- Tracked addons missing folders
- Tracked addons partially installed
- Installed but untracked folders
- Duplicate folder assignments in config

You can optionally save a timestamped report under `temp/inventory_reports/`.

### Adding an Addon

1. Select **"Add addon to tracking"**
2. Enter the GitHub repository URL (e.g., `https://github.com/Ascension-Addons/WeakAuras-Ascension`)
3. The tool will:
   - Auto-detect the addon name
   - Find the default branch
   - Clone the repository
   - **Auto-detect addon folders** (by finding .toc files)
   - **Auto-detect SavedVariables** (from .toc file declarations)
   - Let you select which clients to install to

**Example:**
```
Enter GitHub repository URL: https://github.com/Ascension-Addons/WeakAuras-Ascension

Detected addon name: WeakAuras-Ascension
Press Enter to use this name, or type a custom name: 

🔍 Detecting repository details... ✓
   Branch: master
   Cloning repository... ✓

📁 Detected addon folders: WeakAuras, WeakAurasOptions, WeakAurasTemplates
💾 Detected SavedVariables: WeakAurasSaved.lua

? Select game clients to install this addon to
 ❯ ⬢ ascension_live
   ⬢ ascension_ptr

Addon Configuration:
======================================================================
Name: WeakAuras-Ascension
Repository: https://github.com/Ascension-Addons/WeakAuras-Ascension
Branch: master
Folders: WeakAuras, WeakAurasOptions, WeakAurasTemplates
SavedVariables: WeakAurasSaved.lua
Clients: ascension_live, ascension_ptr

Add this addon? (y/N): y

✅ Added WeakAuras-Ascension to tracking!
```

### Checking for Updates

1. Select **"Check for updates"**
2. The tool checks all tracked addons
3. Shows which ones have updates available
4. Select which addons to update (or all)
5. Confirms before proceeding
6. **Automatically backs up SavedVariables**
7. Updates the addons

**Example:**
```
Checking for updates...
======================================================================

Checking WeakAuras-Ascension... ⬆️  Update available (a1b2c3d → e4f5g6h)
Checking Details-335... ✓ Up to date (x9y8z7w)

2 addon(s) can be updated:

? Select addons to update
 ❯ ⬢ Update all addons
   ⬢ WeakAuras-Ascension (a1b2c3d → e4f5g6h)
   ⬢ MyOtherAddon (new install → x9y8z7w)

📥 Ready to update 2 addon(s):
  • WeakAuras-Ascension (a1b2c3d → e4f5g6h)
  • MyOtherAddon (new install)

Proceed with update? (y/N): y

Updating addons...
======================================================================

📦 Updating WeakAuras-Ascension...
  • Fetching latest version... ✓

  📂 Ascension Live:
    • Backing up SavedVariables... ✓
    • Installing addon files... ✓

  ✨ WeakAuras-Ascension updated successfully!

✨ Update complete: 2/2 successful
```

### Creating Manual Backups

Select **"Create SavedVariables backup"** to backup all addon SavedVariables without updating:

```
Create SavedVariables Backup
======================================================================

Create backup for 3 addon(s) across 2 client(s)? (y/N): y

📦 Backing up Ascension Live...
  • WeakAuras-Ascension... ✓
  • Details-335... ✓
  • MyAddon... (no data)

📦 Backing up Ascension PTR...
  • WeakAuras-Ascension... ✓

✅ Backup complete!
   ascension_live: 2 addon(s) backed up
   ascension_ptr: 1 addon(s) backed up
```

### Removing Addons

Select **"Remove addon from tracking"** to stop tracking an addon (doesn't uninstall from game):

```
? Select addon to remove
  ❯ WeakAuras-Ascension
    Details-335
    MyOtherAddon

Remove 'WeakAuras-Ascension' from tracking?
(This will not uninstall the addon from game) (y/N): y

✅ Removed WeakAuras-Ascension from tracking
```

## Directory Structure

```
addon_manager/
├── addon_manager.py              # Main script
├── config.json                   # Configuration
├── README.md                     # This file
├── lib/                          # Library modules
│   ├── __init__.py
│   ├── config_manager.py         # Config management
│   ├── git_operations.py         # Git interactions
│   ├── backup_manager.py         # Backup/restore
│   └── addon_installer.py        # Installation
├── backups/                      # Backup storage
│   └── savedvariables/
│       └── YYYYMMDD_HHMMSS/      # Timestamped backups
│           ├── ascension_live/
│           └── ascension_ptr/
└── temp/                         # Temporary repos
    └── addon_repos/
        ├── WeakAuras-Ascension/
        └── Details-335/
```

## Configuration File

`config.json` structure:

```json
{
  "version": "1.0.0",
  "game_clients": {
    "ascension_live": {
      "name": "Ascension Live",
      "addons_path": "/mnt/d/Games/.../Interface/AddOns",
      "wtf_path": "/mnt/d/Games/.../WTF",
      "enabled": true
    }
  },
  "settings": {
    "backup_directory": "./backups/savedvariables",
    "temp_directory": "./temp/addon_repos",
    "keep_backups_days": 30,
    "auto_detect_folders": false,
    "auto_detect_savedvars": false
  },
  "addons": [
    {
      "name": "WeakAuras-Ascension",
      "repo": "https://github.com/Ascension-Addons/WeakAuras-Ascension",
      "branch": "master",
      "addon_folders": ["WeakAuras", "WeakAurasOptions"],
      "saved_variables": ["WeakAurasSaved.lua"],
      "enabled": true,
      "clients": ["ascension_live", "ascension_ptr"]
    }
  ]
}
```

## Backup System

### Backup Structure
```
backups/savedvariables/20241112_143022/
├── ascension_live/
│   └── WeakAuras-Ascension/
│       ├── Account/
│       │   └── ACCOUNTNAME/
│       │       └── WeakAurasSaved.lua
│       └── Characters/
│           └── RealmName/
│               └── CharacterName/
│                   └── WeakAurasSaved.lua
└── ascension_ptr/
    └── WeakAuras-Ascension/
        └── ...
```

### Automatic Backup
- Happens before every addon update
- Includes all accounts and characters
- Timestamped folders for easy identification

### Manual Backup
- Use "Create SavedVariables backup" option
- Backs up all tracked addons
- No addon updates performed

## Advanced Features

### Auto-Detection
During "Add addon to tracking", the manager automatically detects:
- **Addon Folders**: Scans for `.toc` files
- **SavedVariables**: Parses `## SavedVariables:` from `.toc` files
- **Branch**: Detects default branch (master/main)

### Multi-Folder Addons
Automatically handles addons with multiple folders (e.g., WeakAuras with WeakAuras, WeakAurasOptions, WeakAurasTemplates).

### Character-Specific SavedVariables
Backs up both:
- Account-level variables (`WTF/Account/*/SavedVariables/`)
- Character-level variables (`WTF/Account/*/Realm/Character/SavedVariables/`)

## Integration with Development Workflow

This tool complements your existing addon development:

- **Custom/local addons**: Use your existing `scripts/deploy_addons.sh`
- **GitHub-tracked addons**: Use this Addon Manager
- Both workflows maintain separate backups

Legacy `addon_updater.py` is deprecated; use this manager as the canonical updater/checker.

## Common Repositories

### WeakAuras (Ascension)
```
https://github.com/Ascension-Addons/WeakAuras-Ascension
```

### Details! Damage Meter (3.3.5)
```
https://github.com/drake-soc/Details-335
```

### Ascension Addons Organization
```
https://github.com/Ascension-Addons
```

## Troubleshooting

### "Could not fetch remote info"
- Check internet connection
- Verify repository URL is accessible
- Ensure repository is public

### "AddOns path not found"
- Verify paths in `config.json`
- Use WSL format: `/mnt/d/Games/...`
- Check that the game client is installed

### SavedVariables Not Backed Up
- Ensure addon has been loaded in-game at least once
- Check that `saved_variables` list matches actual file names
- Verify WTF path is correct

### Auto-Detection Failed
- Manually enter folder names when prompted
- Check that .toc files exist in the repository
- Report issue if it's a valid addon structure

## Tips

1. **Test on PTR first**: Enable PTR client, update there before live
2. **Regular backups**: Use "Create SavedVariables backup" before major game patches
3. **Keep backups**: Default is 30 days; clean up old backups periodically
4. **Verify paths**: Check `config.json` paths match your installation

## Future Enhancements

Potential additions:
- [ ] Restore from backup via menu
- [ ] CurseForge/Wago integration
- [ ] Scheduled update checks
- [ ] Dependency management
- [ ] Rollback capability
- [ ] TOC version checking

## License

MIT License - See main repository LICENSE file
