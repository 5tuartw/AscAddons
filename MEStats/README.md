# MEStats - Mystic Enchant Statistics

Track your Mystic Enchant collection progress for Ascension WoW with detailed statistics and an easy-to-use interface.

## Features

- **Collection Tracker**: Visual grid showing all Mystic Enchants
- **Detailed Statistics**: View progress by:
  - Overall collection
  - Class specialization
  - Armor types (Cloth, Leather, Mail, Plate)
  - Weapon types (1H Sword, 2H Axe, Staff, etc.)
- **Minimap Tooltip**: At-a-glance stats showing All classes and your current class
- **Display Modes**: Toggle between percentages and absolute counts
- **Color-Coded Progress**: Easy-to-read color scheme for completion percentages
- **Minimap Button**: Quick access to the statistics window

## Installation

1. Download the latest release
2. Extract to `World of Warcraft/Interface/AddOns/`
3. Restart WoW or type `/reload`
4. Click the minimap icon or type `/mestats`

## Usage

### Basic Commands
- `/mestats` - Toggle the statistics window
- Click the minimap icon - Open statistics window
- Hover minimap icon - View quick stats tooltip

### Statistics Window
- **Top Tabs**: Switch between Overall, Class, Armor, and Weapon views
- **Display Mode Button**: Toggle between percentage (%) and count (X/Y) display
- **Refresh Button**: Update statistics from game data
- **Item Tooltips**: Hover over enchants to see full details

### Minimap Tooltip
Displays two key statistics:
- **All**: Total collection across all classes
- **[Your Class]**: Collection progress for your current class

Colors indicate completion:
- Gold: 100%
- Orange: 90-99%
- Purple: 75-89%
- Blue: 50-74%
- Green: 25-49%
- White: 10-24%
- Gray: 0-9%

## Development

MEStats is actively developed for Ascension WoW (3.3.5 WotLK client).

### File Structure
- `Core.lua` - Main addon logic, minimap button, event handling
- `UI.lua` - Statistics window, table rendering, data aggregation
- `MEStats.toc` - Addon manifest

### Building
The addon reads Mystic Enchant data directly from the game using Ascension's custom APIs:
- `C_MysticEnchant.QueryEnchants()`
- `C_MysticEnchant.GetNumEnchants()`
- `C_MysticEnchant.GetEnchantInfo(index)`

## Changelog

### 1.0.2
- Added at-a-glance stats to minimap button


### 1.0.1 (Current)
- Added at-a-glance statistics to minimap icon tooltip
- Display All classes and current class collection progress
- Color-coded percentages matching main window scheme

### 1.0.0
- Initial release
- Collection tracker with visual grid
- Statistics by class, armor type, weapon type
- Dual display modes (percentage/count)
- Minimap button integration

## Credits

Created by 5tuartw for the Ascension WoW community.

## License

See LICENSE file for details.
