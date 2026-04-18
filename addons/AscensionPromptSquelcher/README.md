# Ascension Prompt Squelcher

Small standalone addon for Ascension's 3.3.5 client that auto-confirms a few high-friction prompts:

- Bind-on-pickup loot confirmation
- Bind-on-pickup loot roll confirmation
- Disenchant loot roll confirmation
- Normal destroy-item confirmation
- Rare-or-better item deletion confirmation
- Appearance collection confirmation

## Commands

- `/aps` or `/aps options` opens Interface Options
- `/aps status` prints current toggle state
- `/aps loot on|off|toggle`
- `/aps roll on|off|toggle`
- `/aps disenchant on|off|toggle`
- `/aps destroy on|off|toggle`
- `/aps rare on|off|toggle`
- `/aps appearance on|off|toggle`

## Notes

- Rare-item deletion intentionally bypasses the extra safety prompt. Leave that toggle off if you want manual confirmation for blue, purple, or better items.
- This overlaps with YATP's quick-confirm module for bind-on-pickup loot. If you keep both addons enabled, disable one of those two BoP features.

## Short Changelog

### 1.0.1
- 1.0.1


- 2026-04-18: Added optional auto-confirm for abandon quest prompts (`/aps abandon on|off|toggle`).
- 2026-04-18: Added matching options checkbox and status output for abandon prompt handling.
- 2026-04-18: Kept existing prompt toggles unchanged for loot, rolls, disenchant, destroy, and appearance.
