# Extra Bars Ascension

A standalone addon that adds 3 additional action bars for the default WoW UI. No UI replacement addon required.

## Features

- **3 extra action bars for every class** using action pages 2, 10, and 8
- **Stance bar suppression** - hides BonusActionBarFrame so form/stance changes don't swap the main bar, freeing those pages for extra bars (same approach as Bartender4)
- **Configurable action page** per bar (`/eba page`) - override defaults if needed
- **Clean minimal styling** - 1px bordered buttons with cropped icons
- **Configurable layout** - set number of buttons (1-12) and buttons per row for grid layouts
- **Custom sizing** - button size (16-64px) and spacing (0-20px) per bar
- **Visibility modes** - always visible or show on mouseover with configurable fade alpha
- **Moveable** - unlock bars to drag and reposition them
- **Toggle hotkeys/macros** - show or hide keybind text and macro names per bar
- **Per-character settings** saved automatically

## How Stance Suppression Works

In the default UI, entering a stance or form swaps the main action bar to a bonus page (pages 7-10). This addon **selectively** suppresses that swap for the pages it claims (8 and 10), while allowing other stances to swap normally.

A secure state driver controls `BonusActionBarFrame` visibility:
- **bonusbar:1 (page 7)** — Cat Form / Stealth / Battle Stance → **allowed** (main bar swaps)
- **bonusbar:2 (page 8)** — Tree of Life / Shadow Dance / Defensive Stance → **suppressed**
- **bonusbar:3 (page 9)** — Bear Form / Berserker Stance → **allowed** (main bar swaps)
- **bonusbar:4 (page 10)** — Moonkin Form → **suppressed**

This means:

| Class | Main bar still swaps for | Suppressed (page free for EBA) |
|-------|-------------------------|-------------------------------|
| Warrior | Battle Stance, Berserker Stance | Defensive Stance (page 8) |
| Druid | Cat Form, Bear Form | Tree of Life (page 8), Moonkin (page 10) |
| Rogue | Stealth | Shadow Dance (page 8) |
| Others | (no stances) | (nothing to suppress) |

| Page | Default UI Stance | EBA Default |
|------|------------------|-------------|
| 2 | Main bar page 2 (rarely used) | **EBA Bar 1** |
| 8 | Tree of Life / Shadow Dance / Defensive (suppressed) | **EBA Bar 3** |
| 10 | Moonkin Form (suppressed) | **EBA Bar 2** |

Toggle suppression with `/eba suppress` if you need default stance bar swapping back.

## Commands

| Command | Description |
|---------|-------------|
| `/eba help` | Show all commands |
| `/eba status` | Show current bar settings |
| `/eba toggle <1-3>` | Enable/disable a bar |
| `/eba page <1-3> <1-10>` | Set action page (see `/eba pages`) |
| `/eba suppress` | Toggle stance bar suppression on/off |
| `/eba buttons <1-3> <1-12>` | Set number of buttons |
| `/eba perrow <1-3> <1-12>` | Set buttons per row |
| `/eba size <1-3> <pixels>` | Set button size (16-64px) |
| `/eba spacing <1-3> <pixels>` | Set button spacing (0-20px) |
| `/eba vis <1-3> <always\|mouseover>` | Set visibility mode |
| `/eba alpha <1-3> <0-1>` | Set fade-out alpha for mouseover mode |
| `/eba grid <1-3>` | Toggle show empty slots |
| `/eba hotkey <1-3>` | Toggle keybind text |
| `/eba macro <1-3>` | Toggle macro name text |
| `/eba unlock` | Unlock bars for repositioning |
| `/eba lock` | Lock bar positions |
| `/eba pages` | Show action page reference |
| `/eba reset` | Reset all settings to defaults |

## Examples

```
/eba perrow 1 6        -- Bar 1: 2 rows of 6 buttons
/eba size 2 28         -- Bar 2: 28px buttons
/eba vis 3 mouseover   -- Bar 3: show on mouseover
/eba alpha 3 0.2       -- Bar 3: 20% opacity when mouse away
/eba grid 1            -- Toggle empty slot visibility for bar 1
/eba hotkey 2          -- Toggle keybind text for bar 2
/eba toggle 3          -- Disable/enable bar 3
```

Most changes require `/reload` to apply. Visibility and alpha changes apply immediately.

## Requirements

- WoW 3.3.5a client (Interface 30300)
- No other addons required

## Installation

Copy the `ExtraBarsAscension` folder to your `Interface/AddOns/` directory.

## Short Changelog

- 2026-04-18: Profile reset/change now reapplies bar positions immediately (including x/y offsets).
- 2026-04-18: Live profile updates now reapply layout, visibility, and scale without requiring reload for those parts.
- 2026-04-18: Clarified reset messaging to distinguish live-applied settings from reload-required settings.
