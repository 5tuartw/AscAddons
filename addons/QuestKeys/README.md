# QuestKeys - Keyboard Shortcuts for Questing

Fast quest and gossip interactions using keyboard shortcuts for Ascension WoW (3.3.5 WotLK).

<img src="https://raw.githubusercontent.com/5tuartw/AscAddons/main/screenshots/QK_dialogue.png" width="692">

## Features

- **Spacebar**: Accept, continue, and complete quests automatically
- **Number Keys (1-9)**: Select gossip options, quest rewards, and available quests
- **ESC**: Decline quests
- **Visual Key Hints**: Shows `[1]`, `[2]`, `[SPACE]` labels on clickable options
- **Smart Auto-Complete**: Automatically completes quests with 0-1 reward choices

## Installation

1. Download the [latest release](https://github.com/5tuartw/AscAddons/releases/tag/questkeys-v1.0.2) (click the zip file in the **Assets** section)
2. Extract to `World of Warcraft/Interface/AddOns/`
3. Restart WoW or type `/reload`
4. Works automatically when interacting with NPCs

## Usage

### Spacebar Actions
- Accept new quests
- Complete quests (when requirements met)
- Continue through single-option gossip
- Auto-complete quests with 0-1 reward choices

### Number Keys (1-9)
- Select gossip dialogue options
- Choose quest rewards (when 2+ available)
- Pick from multiple available quests at same NPC

### ESC Key
- Decline quest when quest detail window is showing

### Commands
- `/qk` or `/questkeys` - Show help
- `/qk toggle` - Enable/disable addon
- `/qk hints` - Toggle key hint labels
- `/qk debug` - Toggle debug messages
- `/qk status` - Display current settings

## Tips

- Key hints appear as `[1]`, `[2]`, etc. on buttons and options
- Spacebar intelligently handles quest progression automatically
- Number keys work in gossip, quest rewards, and quest greetings
- **Combat Note**: Keys automatically unbind when entering combat and rebind when leaving combat (if quest window still open)
- All features work with standard WoW APIs - no custom server dependencies

## License

MIT License - See [LICENSE](LICENSE)

## Short Changelog

- 2026-04-18: Added hint display modes (inline vs overlay) with configurable behavior.
- 2026-04-18: Added overlay X/Y offset controls for better alignment on custom UIs.
- 2026-04-18: Improved gossip/reward hint refresh to reduce stale labels during rapid dialogue transitions.


All state is saved per-character in `SavedVariables/QuestKeysDB.lua`.

## Design Philosophy

This addon is intentionally **simple and focused**:
- ~250 lines of pure Lua
- No external dependencies
- Uses only 3.3.5 native APIs
- Minimal overhead
- No fancy UI - just keyboard shortcuts

Built specifically for Ascension WoW (3.3.5), designed for fast leveling and laptop-friendly gameplay.

## Credits

Created for personal use on Ascension WoW. Inspired by retail WoW's quest keyboard interactions.

## License

Free to use and modify for personal use.
