# Ascension Trinket Manager

![Trinket Manager](../screenshots/atm_expand.png)

A lightweight WoW addon for Ascension (3.3.5 WotLK) that provides clickable trinket buttons with automatic mount speed trinket swapping.

## Features

- **Quick-Access Trinket Buttons** - Two clickable buttons for your equipped trinkets
- **One-Click Activation** - Left-click to use trinket on-demand
- **Visual Cooldown Display** - Shows cooldown sweep animations
- **Trinket Swap Menu** - Right-click to see all bag trinkets and swap instantly
- **Auto-Carrot Feature** - Automatically equips "Stick on a Carrot" (mount speed trinket) when you mount
- **Manual Carrot Swap** - Alt+Left-click any button to manually swap in the carrot
- **Smart Restore** - Automatically restores your previous trinket when you dismount
- **Zone Restrictions** - Optional: Disable auto-carrot in instances and battlegrounds
- **Configurable Slot** - Choose which trinket slot (top or bottom) for auto-carrot
- **Flexible Layout** - Horizontal or vertical orientation
- **Expand Direction** - Choose dropdown menu direction (up/down/left/right) per orientation
- **Movable & Scalable** - Shift+drag to reposition, scale from 50-200%
- **Show/Hide Toggle** - `/atm show` or `/atm hide` to control visibility

## Installation

1. Download the [latest release](https://github.com/5tuartw/AscAddons/releases?q=atm&expanded=true) (click the zip file in the **Assets** section)
2. Extract to `World of Warcraft/Interface/AddOns/`
3. Restart WoW or `/reload`
4. Type `/atm` to configure

## Usage

### Quick Start
- **Left-click** trinket button - Use the trinket
- **Right-click** trinket button - Open swap menu
- **Alt+Left-click** trinket button - Swap in Stick on a Carrot manually
- **Shift+drag** - Move the trinket buttons

### Commands
- `/atm` - Open options panel
- `/atm show` - Show trinket buttons
- `/atm hide` - Hide trinket buttons  
- `/atm reset` - Reset all settings to defaults

### Options Panel
Access via `/atm` or ESC → Interface → Addons → Ascension Trinket Manager:
- **Show trinket buttons** - Toggle visibility
- **Auto-equip Stick on a Carrot** - Enable/disable automatic carrot swapping
- **Carrot trinket slot** - Choose Trinket 1 (top) or Trinket 2 (bottom)
- **Enable in Instances** - Allow auto-carrot in dungeons/raids
- **Enable in Battlegrounds** - Allow auto-carrot in PvP zones
- **Scale** - Adjust button size (50-200%)
- **Orientation** - Horizontal or Vertical layout
- **Expand direction** - Control which direction the swap menu opens

## Version

1.0.0 - Initial release

## License

MIT License - See LICENSE file for details
- Cooldown tracking
- Auto-equip Stick on a Carrot when mounted
- Horizontal/vertical layouts
- Draggable and lockable positioning
- Scalable buttons (50%-200%)
