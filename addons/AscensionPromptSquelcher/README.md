# Ascension Prompt Squelcher

Small standalone addon for Ascension's 3.3.5 client that auto-confirms a few high-friction prompts:

- Bind-on-pickup loot confirmation
- Bind-on-pickup loot roll confirmation
- Disenchant loot roll confirmation
- Optional Ctrl+Alt+LeftClick bag-item deletion
- Normal destroy-item confirmation
- Rare-or-better item deletion confirmation
- Appearance collection confirmation

## Installation

1. Download the [latest release](https://github.com/5tuartw/AscAddons/releases?q=aps-v&expanded=true) (click the zip file in the **Assets** section)
2. Extract to `World of Warcraft/Interface/AddOns/`
3. Restart WoW or `/reload`
4. Type `/aps` to configure

## Commands

- `/aps` or `/aps options` opens Interface Options
- `/aps status` prints current toggle state
- `/aps loot on|off|toggle`
- `/aps roll on|off|toggle`
- `/aps disenchant on|off|toggle`
- `/aps clickdelete on|off|toggle`
- `/aps destroy on|off|toggle`
- `/aps rare on|off|toggle`
- `/aps appearance on|off|toggle`
- `/aps abandon on|off|toggle`

## Notes

- Rare-item deletion intentionally bypasses the extra safety prompt. Leave that toggle off if you want manual confirmation for blue, purple, or better items.
- Ctrl+Alt+LeftClick only starts the delete flow from bag slots. Whether the client still shows a confirmation depends on your destroy / rare-delete prompt toggles.
- This overlaps with YATP's quick-confirm module for bind-on-pickup loot. If you keep both addons enabled, disable one of those two BoP features.

## Short Changelog

### 1.0.1
- Initial tagged release of Ascension Prompt Squelcher


- 2026-04-18: Added optional auto-confirm for abandon quest prompts (`/aps abandon on|off|toggle`).
- 2026-04-18: Added matching options checkbox and status output for abandon prompt handling.
- 2026-04-18: Kept existing prompt toggles unchanged for loot, rolls, disenchant, destroy, and appearance.
- 2026-04-25: Added optional Ctrl+Alt+LeftClick bag-item deletion (`/aps clickdelete on|off|toggle`).
