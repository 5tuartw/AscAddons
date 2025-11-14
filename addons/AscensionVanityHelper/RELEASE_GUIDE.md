# AscensionVanityHelper Release Guide

## Quick Release (Recommended)

### Option 1: Manual Release
```bash
# From repo root
./create_release.sh AscensionVanityHelper 1.1.0

# This creates: releases/AscensionVanityHelper-v1.1.0.zip
# Then upload to GitHub manually
```

### Option 2: GitHub Actions (Automatic)
```bash
# Create and push a tag
git add AscensionVanityHelper/
git commit -m "Release AscensionVanityHelper v1.1.0"
git tag avh-v1.1.0
git push origin main
git push origin avh-v1.1.0

# GitHub Actions will automatically:
# 1. Build the release ZIP
# 2. Create a GitHub release
# 3. Upload the ZIP file
```

## File Checklist

Before releasing, ensure these files are up to date:

- [x] `AscensionVanityHelper/README.md` - Full documentation
- [x] `AscensionVanityHelper/LICENSE` - MIT License
- [x] `AscensionVanityHelper/AscensionVanityHelper.toc` - Check version number
- [x] `AscensionVanityHelper/Core.lua` - Check AVH.version = "1.1.0"
- [x] `.github/workflows/release-avh.yml` - GitHub Actions workflow

## Release Process

### 1. Update Version Numbers

Edit `AscensionVanityHelper/Core.lua`:
```lua
AVH.version = "1.1.0"  -- Update this
```

Edit `AscensionVanityHelper/AscensionVanityHelper.toc`:
```
## Version: 1.1.0  -- Update this
```

### 2. Update Changelog

Edit `AscensionVanityHelper/README.md` and update the Changelog section.

### 3. Test In-Game

```bash
./scripts/deploy_addons.sh
# Then test in-game with /reload
```

### 4. Create Release

**Manual Method:**
```bash
./create_release.sh AscensionVanityHelper 1.1.0
```

Upload `releases/AscensionVanityHelper-v1.1.0.zip` to GitHub:
1. Go to https://github.com/5tuartw/WowAddons/releases
2. Click "Draft a new release"
3. Tag: `avh-v1.1.0`
4. Title: `AscensionVanityHelper v1.1.0`
5. Upload the ZIP file
6. Copy changelog from README.md
7. Publish

**Automatic Method:**
```bash
git add -A
git commit -m "Release AscensionVanityHelper v1.1.0"
git tag avh-v1.1.0
git push origin main
git push origin avh-v1.1.0
```

Check https://github.com/5tuartw/WowAddons/actions to see the build progress.

## Release Contents

The ZIP file includes:
```
AscensionVanityHelper/
├── AscensionVanityHelper.toc
├── Core.lua
├── Data.lua
├── UI.lua
├── Cleanup.lua
├── README.md
└── LICENSE
```

## Post-Release

1. Verify ZIP downloads correctly from GitHub
2. Test installation on fresh WoW client
3. Share release link in Ascension Discord/forums
4. Update any external documentation

## Tag Naming Convention

- **AscensionVanityHelper**: `avh-v1.1.0`, `avh-v1.2.0`, etc.
- **MEStats**: `mestats-v1.0.0`, etc.
- **WarcraftRebornCollector**: `wrc-v1.0.0`, etc.

This keeps tags organized by addon in the monorepo.

## Version Bump Checklist

Before releasing:
- [ ] Update `Core.lua` version
- [ ] Update `.toc` version
- [ ] Update README.md changelog
- [ ] Test all features in-game
- [ ] Run deployment script
- [ ] Verify no lua errors
- [ ] Create git tag
- [ ] Push tag to trigger release
