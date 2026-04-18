# AutoCollect - Transmog Collection Assistant

Auto-collect transmog appearances with smart filtering and visual indicators for Ascension WoW (3.3.5 WotLK).

**Based on [AutoCollectAppearance v6.0](https://github.com/Ashi-Ryu/AutoCollectAppearance) by Ashi-Ryu**

<img src="https://raw.githubusercontent.com/5tuartw/AscAddons/main/screenshots/AC_options.png" width="812">
<img src="https://raw.githubusercontent.com/5tuartw/AscAddons/main/screenshots/AC_tooltip.jpg" width="207">

## Features

- **One-Click Collection**: Collect all uncollected appearances from your bags
- **Visual Overlays**: Green checkmark icons on quest rewards and loot rolls with new appearances
- **Smart Filtering**: Rarity-based collection (Poor, Common, Uncommon, Rare, Epic+)
- **Bloodforged Friendly**: Bloodforged appearances collect on normal left-click (no Shift required)
- **Bind Protection**: Option to only collect BoE items that are already bound
- **Icon or Text Mode**: Choose between compact icon or traditional text button
- **Live Counter**: Button shows count of uncollected appearances in bags
- **Enhanced Tooltip**: Lists uncollected items with "Will be collected" / "Will not be collected" sections

## Installation

1. Download the [latest release](https://github.com/5tuartw/AscAddons/releases?q=autocollect&expanded=true) (click the zip file in the **Assets** section)
2. Extract to `World of Warcraft/Interface/AddOns/`
3. Restart WoW or type `/reload`
4. Drag the button to your preferred location

## Usage

### Button Actions
- **Left-click**: Collect appearances (respects rarity and bind settings)
- **Shift-click**: Collect all appearances including unbound items (Bloodforged already collects on normal click)
- **Right-click**: Open settings panel
- **Drag**: Move button anywhere on screen

### Settings
Access via right-click or ESC → Interface → AddOns → AutoCollect

- **Button Scale**: Adjust size (0.5x to 2.0x)
- **Use Icon**: Toggle between icon and text button
- **Rarity Filters**: Choose which item qualities to collect
- **Bind Protection**: Only collect already-bound BoE items
- **Auto-Hide**: Hide button when no uncollected items
- **Quest/Loot Overlays**: Show green checkmarks on new appearances

## Short Changelog

- 2026-04-18: Improved group loot roll overlay reliability for collectible-item "+" indicators.
- 2026-04-18: Bloodforged appearances now collect on normal left-click (no Shift required).
- 2026-04-18: Unified overlay toggle refresh behavior across loot window, quest rewards, and loot rolls.

## Credits

Original addon by [Ashi-Ryu](https://github.com/Ashi-Ryu/AutoCollectAppearance)  
Enhanced by 5tuartw

## License

MIT License - See [LICENSE](LICENSE)
