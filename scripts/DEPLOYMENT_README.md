# Addon Deployment

Deploy WoW addons from the workspace to Ascension game directory.

## Quick Start

### Using VS Code Task (Recommended)
1. Press `Ctrl+Shift+B` (or `Cmd+Shift+B` on Mac)
2. Select "Deploy Addons to Ascension"

### Using Command Line
```bash
cd ~/workspace/github.com/5tuartw/WowAddons
./scripts/deploy_addons.sh
```

## Configuration

### Adding Addons to Deploy
Edit `scripts/deploy_addons.sh` and add addon names to the `ADDONS` array:

```bash
ADDONS=(
    "WRC_DevTools"
    "HandyNotes_AscensionRPG"
    "YourNewAddon"  # Add here
)
```

### Changing Target Directory
If your Ascension installation is in a different location, edit the path in `scripts/deploy_addons.sh`:

```bash
# Default:
ASCENSION_ADDONS="/mnt/d/Games/Ascension Launcher/resources/client/Interface/AddOns"

# Custom example:
ASCENSION_ADDONS="/mnt/c/Games/Ascension/Interface/AddOns"
```

## What It Does

1. **Removes old version** from Ascension AddOns directory
2. **Copies new version** from workspace
3. **Verifies deployment** and shows status

The script:
- ✓ Safely removes old versions before copying
- ✓ Preserves addon structure (all files and subdirectories)
- ✓ Shows detailed status for each addon
- ✓ Validates paths before deployment

## After Deployment

1. **Launch Ascension WoW**
2. **Reload UI**: Type `/reload` at character select or in-game
3. **Verify addon loaded**:
   - For WRC_DevTools: `/wrcdev help`
   - For HandyNotes: Check map for pins

## Troubleshooting

### "Source not found" Error
The addon directory doesn't exist in the workspace.

**Fix**: Ensure addon folder exists:
```bash
ls ~/workspace/github.com/5tuartw/WowAddons/WRC_DevTools
```

### "Target directory not found" Error
The Ascension AddOns path is incorrect.

**Fix**: Update path in `scripts/deploy_addons.sh` to match your installation.

### Addon Not Showing In-Game
1. Check AddOns list at character select (click "AddOns" button)
2. Ensure addon is enabled (checkbox checked)
3. Try `/reload` in-game
4. Check for Lua errors: `/console scriptErrors 1`

### Permission Issues
If you get permission errors on Windows:

**Fix**: Run VS Code or terminal as Administrator, or adjust folder permissions.

## VS Code Tasks

Available tasks (press `Ctrl+Shift+P` → "Tasks: Run Task"):

| Task | Description |
|------|-------------|
| **Deploy Addons to Ascension** | Deploy all configured addons (default build task) |
| Run Data Cleanup | Process and clean worldforged item data |
| Generate Scan Commands | Create WRC_DevTools scan commands |
| [ARCHIVED] Deploy Ascension RPG addon | Old deployment task (kept for reference) |

## Notes

- **SavedVariables are NOT deployed** - they're stored in `WTF\Account\<ACCOUNT>\SavedVariables\`
- **Addons update on UI reload** - no need to restart WoW
- **Multiple addons deploy together** - all configured addons copy in one command
- **Old versions removed first** - ensures clean deployment, no leftover files

## Development Workflow

Typical workflow when developing addons:

1. **Edit addon files** in workspace (`WRC_DevTools/Core.lua`, etc.)
2. **Deploy**: Press `Ctrl+Shift+B`
3. **Test in-game**: `/reload` and test changes
4. **Iterate**: Repeat steps 1-3

Fast iteration cycle: Edit → Deploy (5s) → Reload (5s) → Test

## File Locations

### Source (Workspace)
```
~/workspace/github.com/5tuartw/WowAddons/
├── WRC_DevTools/
│   ├── Core.lua
│   ├── Scanner.lua
│   └── WRC_DevTools.toc
└── HandyNotes_AscensionRPG/
    └── ...
```

### Target (Ascension)
```
D:\Games\Ascension Launcher\resources\client\Interface\AddOns\
├── WRC_DevTools\
│   ├── Core.lua
│   ├── Scanner.lua
│   └── WRC_DevTools.toc
└── HandyNotes_AscensionRPG\
    └── ...
```

### SavedVariables (Not Deployed)
```
D:\Games\Ascension Launcher\resources\client\WTF\Account\<ACCOUNT>\SavedVariables\
├── WRC_DevTools.lua
└── HandyNotes_AscensionRPG.lua
```

---

**Happy developing!** 🚀
