# WowAddons

Minimal home for personal Ascension WoW (3.3.5) addons and supporting tooling.

## Active Addons

### QuestKeys
Keyboard-first quest and gossip flow.

- Space to accept/complete/continue interactions
- Number keys for options and rewards
- Handles multi-page NPC option chains

- Addon: [addons/QuestKeys](addons/QuestKeys)
- Docs: [addons/QuestKeys/README.md](addons/QuestKeys/README.md)
- Releases: <https://github.com/5tuartw/AscAddons/releases?q=questkeys&expanded=true>

### ExtraBarsAscension
Three extra configurable action bars using default UI pages.

- Supports per-bar layout, size, spacing, visibility, and paging
- Includes stance-page suppression mode for claimed pages
- Keeps default UI while expanding usable bar real estate

![ExtraBarsAscension in-game layout](screenshots/EBA_unlocked.png)

- Addon: [addons/ExtraBarsAscension](addons/ExtraBarsAscension)
- Docs: [addons/ExtraBarsAscension/README.md](addons/ExtraBarsAscension/README.md)

### Other Maintained Addons

- [addons/AscensionPromptSquelcher](addons/AscensionPromptSquelcher) Removes prompts when looting and destroying items, including 'delete' message
- [addons/AscensionTrinketManager](addons/AscensionTrinketManager) Lightweight clickable trinket buttons with options to auto-equip mount speed trinkets
- [addons/AscensionVanityHelper](addons/AscensionVanityHelper) Stores sets of commonly used vanity items for new characters and prestiging
- [addons/AutoCollect](addons/AutoCollect) Clickable button that appears when you have new appearances in your inventory
- [addons/MEStats](addons/MEStats) Tells you how many Mystic Enchants you have collected across all classes

## Tooling

- Release packaging helper: [create_release.sh](create_release.sh)
- Release/tag safety guide: [.github/RELEASE_STRATEGY.md](.github/RELEASE_STRATEGY.md)
- Deferred repo layout plan: [.github/ADDONS_REORG_PLAN.md](.github/ADDONS_REORG_PLAN.md)

Local development-only tooling directories are intentionally excluded from version control.

## Repository Notes

- Third-party and reference content may exist for compatibility and testing.
- Legacy updater entrypoint [addon_updater.py](addon_updater.py) is deprecated.
