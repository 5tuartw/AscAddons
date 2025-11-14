# AscensionVanityHelper - Release Preparation Complete ✅

## Summary

AscensionVanityHelper v1.1.0 is ready for GitHub release!

## What Was Created

### 1. Documentation
- ✅ **README.md** (11.5 KB) - Complete user guide with:
  - Feature list with all 15 built-in sets
  - Installation instructions
  - Usage guide with all commands
  - Options panel documentation
  - Changelog for v1.1.0
  
- ✅ **RELEASE_GUIDE.md** (3.1 KB) - Developer guide for future releases:
  - Manual and automatic release workflows
  - Version bump checklist
  - Tag naming conventions
  
- ✅ **LICENSE** (1.1 KB) - MIT License

### 2. Release Automation
- ✅ **create_release.sh** - Updated to support addons in root folder
- ✅ **.github/workflows/release-avh.yml** - GitHub Actions workflow
  - Triggers on `avh-v*` tags
  - Auto-builds and uploads release ZIP
  - Creates GitHub release with notes

### 3. Release Package
- ✅ **releases/AscensionVanityHelper-v1.1.0.zip** (24 KB)
  - Contains all 5 addon files (.toc, .lua)
  - Includes README.md and LICENSE
  - Ready to upload to GitHub

## Files Included in Release

```
AscensionVanityHelper/
├── AscensionVanityHelper.toc    (292 B)  - Interface 30300
├── Core.lua                      (31.6 KB) - Main logic
├── Data.lua                      (13.4 KB) - 115 items
├── UI.lua                        (19.8 KB) - Main window
├── Cleanup.lua                   (8.7 KB)  - Cleanup helper
├── README.md                     (11.5 KB) - Documentation
└── LICENSE                       (1.1 KB)  - MIT License
```

## How to Release

### Option 1: Manual Upload (Simple)
1. Go to https://github.com/5tuartw/WowAddons/releases
2. Click "Draft a new release"
3. Tag: `avh-v1.1.0`
4. Title: `AscensionVanityHelper v1.1.0`
5. Upload: `releases/AscensionVanityHelper-v1.1.0.zip`
6. Copy changelog from README.md
7. Click "Publish release"

### Option 2: GitHub Actions (Automatic)
```bash
# From WSL terminal
cd ~/workspace/github.com/5tuartw/WowAddons

# Commit and tag
git add -A
git commit -m "Release AscensionVanityHelper v1.1.0"
git tag avh-v1.1.0
git push origin main
git push origin avh-v1.1.0

# GitHub Actions will automatically create the release
```

## Changelog (for Release Notes)

### v1.1.0 (2025-11-09)
- Added 14 heirloom sets (115 total items)
- Added per-set visibility toggles in options panel
- Renamed "Batch Summon" to "Deliver Set"
- Reordered dropdown: New Character first, then heirlooms by category
- Added Ethereal Tool Dispenser Crate as openable container
- Improved cleanup helper with special item handling
- Fixed grid alignment in cleanup window
- Removed redundant warchest helper
- Cleaned up chat message spam

## Future Releases

For version 1.2.0 and beyond:

1. Update version in `Core.lua`: `AVH.version = "1.2.0"`
2. Update version in `.toc`: `## Version: 1.2.0`
3. Update changelog in `README.md`
4. Run: `./create_release.sh AscensionVanityHelper 1.2.0`
5. Upload or push tag `avh-v1.2.0`

See `RELEASE_GUIDE.md` for full details.

## Testing

The release package has been tested:
- ✅ All files included (8 files)
- ✅ README.md preserved
- ✅ LICENSE included
- ✅ File sizes reasonable (24 KB total)
- ✅ No dev files (.git, .bak, etc.)

## Next Steps

1. **Test locally**: Extract ZIP to WoW AddOns folder and `/reload`
2. **Upload to GitHub**: Use manual or automatic method above
3. **Share**: Post release link in Ascension Discord/community
4. **Monitor**: Check for user feedback and issues

---

**Repository**: https://github.com/5tuartw/WowAddons  
**Addon Path**: `AscensionVanityHelper/`  
**Release ZIP**: `releases/AscensionVanityHelper-v1.1.0.zip`
