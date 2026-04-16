# Fixing Multi-Folder Addons - Windows Junctions

## Problem
WSL symlinks don't work properly in Windows - they show as 0KB files and your sync tool can't detect them.

## Solution
Use Windows **directory junctions** instead of WSL symlinks. Junctions are Windows-native and work perfectly with all Windows tools.

## What Was Done

### ✅ Completed in WSL:
1. **Organized backups** - All `*.backup.*` folders moved to `_backups/` subdirectory (57 backups)
2. **Removed WSL symlinks** - Deleted all the broken 0KB symlink files

### ⏳ Next Step - Run PowerShell Script:

**From Windows PowerShell (as Administrator):**

```powershell
cd "\\wsl.localhost\Debian\home\stuart\workspace\github.com\5tuartw\WowAddons\scripts"
.\create_windows_junctions.ps1
```

Or copy the script to Windows and run it there.

## What the PowerShell Script Does

Creates Windows junctions for all multi-folder addons:

**Structure:**
```
D:\Games\Ascension Launcher\resources\client\Interface\AddOns\
├── .git-repos\              (hidden folder with actual git repos)
│   ├── AtlasLoot\.git
│   ├── Bagnon\.git
│   ├── MikScrollingBattleText\.git
│   ├── OmniCC\.git
│   ├── pfQuest\.git
│   ├── WeakAuras-Ascension\.git
│   └── DeadlyBossMods\.git
│
├── AtlasLoot [Junction] → .git-repos\AtlasLoot\AtlasLoot
├── AtlasLoot_Cache [Junction] → .git-repos\AtlasLoot\AtlasLoot_Cache
├── Bagnon [Junction] → .git-repos\Bagnon\Bagnon
├── MikScrollingBattleText [Junction] → .git-repos\MikScrollingBattleText\MikScrollingBattleText
├── MSBTOptions [Junction] → .git-repos\MikScrollingBattleText\MSBTOptions
└── ... (53 more junctions)
```

## Addons Affected

**Multi-Folder Addons Using Junctions:**
- AtlasLoot (10 folders)
- Bagnon (5 folders)
- MikScrollingBattleText (2 folders)
- OmniCC (2 folders)
- pfQuest (2 folders)
- WeakAuras (6 folders)
- DeadlyBossMods (25 folders)

**Single-Folder Addons (Direct Git):**
- AllStats, Bartender4, Details, MoveAnything, Postal, ProfessionMenu, YATP

## After Running PowerShell Script

Your Windows git sync tool will:
1. See proper folders (not 0KB files)
2. Detect git repositories in each junction
3. Be able to update all addons automatically

## Verifying It Worked

In Windows Explorer:
- Navigate to `D:\Games\Ascension Launcher\resources\client\Interface\AddOns`
- Junction folders show with a shortcut arrow overlay
- Should be normal folder size (not 0KB)
- Double-click should open the folder normally

In PowerShell:
```powershell
cd "D:\Games\Ascension Launcher\resources\client\Interface\AddOns"
Get-ChildItem | Where-Object { $_.Attributes -match "ReparsePoint" } | Select-Object Name
```

This lists all junctions created.

## Cleanup

The `_backups\` folder contains 57 backup folders. Once you've verified everything works, you can delete them:

```bash
# From WSL
rm -rf "/mnt/d/Games/Ascension Launcher/resources/client/Interface/AddOns/_backups"
```

Or in Windows:
```powershell
Remove-Item "D:\Games\Ascension Launcher\resources\client\Interface\AddOns\_backups" -Recurse -Force
```
