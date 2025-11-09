# WoW Addon Development for Ascension (3.3.5 WotLK)

## Project Overview
Develops addons for Ascension WoW (custom 3.3.5 WotLK server) with two active addons and archived reference implementations. This is a data-driven project where Python scripts generate Lua datasets from curated JSON sources.

**Active Addons:**
- `WarcraftRebornCollector/` - Player-facing map pin collector for worldforged items (standalone, no HandyNotes dependency)
- `WRC_DevTools/` - In-game item scanning toolkit for data enrichment

**Reference Materials:**
- `archive/addons/related-rpg-addons/` - Working 3.3.5 addons showing Ascension API patterns (HandyNotes-based implementations)
- Archive includes examples of tooltip scanning, invisible GameTooltip usage, and SavedVariables patterns

---

## 3.3.5 WotLK API Constraints

**Critical Differences from Retail:**
- **Interface version:** `## Interface: 30300` in `.toc` files
- **No C_Map API** - Use `GetCurrentMapContinent()`, `GetCurrentMapZone()` for map IDs
- **Frame pooling required** - Blizzard doesn't provide object pools; implement manually (see `WRC.pinPool` pattern)
- **No GameTooltip:SetItemByID()** - Use `SetHyperlink(itemLink)` with `GetItemInfo(itemID)` results
- **No C_Container** - Use `GetContainerNumSlots()`, `GetContainerItemLink()` directly
- **Lua 5.1** - No bitwise operators (`&`, `|`), use `bit.band()`, `bit.bor()` library or manual math
- **Async item loading** - `GetItemInfo(itemID)` may return nil initially; implement retry loops with OnUpdate timers (see `Scanner:RequestItem`)

**Working Patterns in Codebase:**
```lua
-- Event registration (Core.lua, WRC_DevTools)
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...) end)

-- Invisible tooltip scanning (Scanner.lua)
local tooltip = CreateFrame("GameTooltip", "UniqueName", UIParent, "GameTooltipTemplate")
tooltip:SetOwner(UIParent, "ANCHOR_NONE")
tooltip:SetHyperlink(itemLink)
-- Parse with _G["UniqueNameTextLeft1"]:GetText()

-- Throttled processing with OnUpdate (Scanner.lua)
local nextTime = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    nextTime = nextTime - elapsed
    if nextTime <= 0 then
        -- process
        nextTime = DELAY
    end
end)

-- Zone ID mapping (Core.lua WRC.zoneNames)
local c, z = GetCurrentMapContinent(), GetCurrentMapZone()
local zoneName = WRC.zoneNames[c][z]
```

---

## Architecture & Data Flow

**Map Pin System:**
- `Core.lua` owns frame lifecycle via object pools (`WRC.pinPool`, `WRC.minimapPinPool`)
- `Map.lua` provides yard-based coordinate math (`WorldMapSize` tables, `ComputeDistance()`)
- Pins created on-demand, hidden/shown based on `WRC_DB.collected` and `WRC_DB.hidden` state
- Zone coverage requires dual updates: `WRC.zoneNames[continent][zone]` (Core) AND `WorldMapSize[continent][zone]` (Map)

**Data Pipeline (JSON → Lua → In-Game):**
1. **Source:** `data/final/wrc_final_dataset.json` (2000+ locations, metadata in JSON header)
2. **Generator:** `convert_json_to_lua.py input.json WarcraftRebornCollector/Data.lua` creates `WRC_DATA` and `WRC_STATS` tables
3. **Deployment:** `./scripts/deploy_addons.sh` copies to `D:/Games/Ascension.../Interface/AddOns/` via WSL
4. **Verification:** `/reload` in-game, check pins or `/wrcdev help`

**Never hand-edit `Data.lua`** - it's a 350KB generated file. Always modify JSON → regenerate → redeploy.

---

## Critical Developer Workflows

**Fast Iteration Loop:**
```bash
# From repo root in WSL
./scripts/deploy_addons.sh
# Or: Press Ctrl+Shift+B in VS Code (runs "Deploy Addons to Ascension" task)
# Then in-game: /reload
```

**Data Update Cycle:**
```bash
# 1. Edit JSON source
vim data/final/wrc_final_dataset.json

# 2. Regenerate Lua
python3 convert_json_to_lua.py data/final/wrc_final_dataset.json WarcraftRebornCollector/Data.lua

# 3. Deploy
./scripts/deploy_addons.sh

# 4. Verify in-game
# /reload, check map pins or toggle WRC_DB.settings.debugMode = true
```

**In-Game Data Collection (DevTools):**
```lua
-- Scan items to enrich database
/wrcdev scan 521219
/wrcdev scanlist 500000 550000
/wrcdev progress

-- Results stored in WRC_DevToolsDB SavedVariables
-- Export path: WTF/Account/<account>/SavedVariables/WRC_DevTools.lua
-- Parse with scripts/parse_scan_results.py
```

---

## WarcraftRebornCollector Structure

**Core.lua (entry point):**
- Initializes `WRC` global namespace
- Loads `WRC_DATA` (locations), `WRC_STATS` (metadata) from Data.lua
- Manages `WRC_DB` SavedVariables: `collected[itemID]`, `hidden[itemID]`, `settings`
- Hooks WorldMapFrame, registers map events
- **Stateless design** - all persistence in `WRC_DB`, safe across `/reload`

**Map.lua (rendering):**
- `WorldMapSize[continent][zone]` - yard dimensions for 100+ zones (inherited from Astrolabe)
- `GetMinimapRadius()` - zoom-aware minimap pin positioning
- `ComputeDistance(x1,y1,x2,y2)` - yard-based distance calculations
- Minimap pins use rotating player arrow coordinate transforms

**Data.lua (generated, don't edit):**
- `WRC_DATA.mapPins[continent][zone][coordKey]` - location tree structure
- `WRC_STATS` - item counts, coverage percentages, source breakdown
- Pin variants support multiple items at same location (coordKey = "0.581:0.520")

**Pin Lifecycle:**
```lua
-- Create/reuse from pool
local pin = WRC:GetPinFrame() 

-- Configure
pin.itemID = itemID
pin:SetPoint(...)

-- Show with tooltip hook
pin:SetScript("OnEnter", function() WRC:ShowTooltip(pin) end)
pin:SetScript("OnMouseUp", function() WRC:OnPinClick(pin, button) end)

-- Hide/return to pool when collected
WRC:HidePin(itemID)
WRC:RefreshPins() -- rebuild visible pins
```

---

## WRC_DevTools (Scanner Addon)

**Core.lua:**
- Slash command handler: `/wrcdev scan|scanlist|progress|export`
- Queue management for batch scanning
- Auto-save every 50 items to `WRC_DevToolsDB`

**Scanner.lua:**
- **Throttling:** `SCAN_DELAY = 0.2` (5 items/sec) to avoid server rate limits
- **Item cache warming:** Creates OnUpdate frame waiting for `GetItemInfo()` to return non-nil (max 5 seconds)
- **Tooltip parsing:** Invisible GameTooltip extracts armor type, weapon type, red-text custom stats
- **Result structure:** `{ name, quality, slot, armorType, weaponType, scanDate, unknownStats }`

**Export Pattern:**
```lua
-- Scanner writes to SavedVariables
WRC_DevToolsDB.scannedItems[itemID] = { ... }

-- After logout, parse SavedVariables
scripts/parse_scan_results.py --input WTF/.../WRC_DevTools.lua --output scan_results.json

-- Merge into final dataset
merge_final_dataset.py --scans scan_results.json
```

---

## Coding Conventions

**Frame Memory Management:**
- **Never** `CreateFrame()` in hot paths (map pan, zoom, refresh)
- Use object pools: `table.insert(self.pinPool, frame)` when hiding, `table.remove(self.pinPool)` when showing
- Example: `WRC:GetPinFrame()` reuses hidden frames before creating new ones

**SavedVariables Serialization:**
- Only basic Lua types: `string`, `number`, `boolean`, `table` (no functions, userdata)
- Use timestamps: `time()` returns Unix epoch (compare for staleness)
- Character scoping: Global (`WRC_DB.collected`) vs per-char (`WRC_DB.settings`)

**String Escaping (Python → Lua):**
- `escape_lua_string()` in all data generators handles backslashes, quotes, newlines
- Output must be ASCII-safe (or UTF-8 with BOM if needed); avoid arbitrary bytes

**Zone ID Coordination:**
- Adding a zone requires **two** edits:
  - `Core.lua`: `WRC.zoneNames[continent][zone] = "Zone Name"`
  - `Map.lua`: `WorldMapSize[continent][zone] = { height, width, xOffset, yOffset }`
- Get dimensions from Astrolabe references or measure in-game with coordinates addon

**Modifier Key Patterns:**
```lua
-- OnClick handlers
function WRC:OnPinClick(pin, button)
    if IsShiftKeyDown() then
        -- Debug info
    elseif IsControlKeyDown() then
        -- Mark as collected
    else
        -- Default action
    end
end
```

---

## Common Tasks

**Add a new map pin:**
1. Edit `data/final/wrc_final_dataset.json` - add location under `mapPins[continent][zone][coordKey]`
2. Regenerate: `python3 convert_json_to_lua.py data/final/wrc_final_dataset.json WarcraftRebornCollector/Data.lua`
3. Deploy: `./scripts/deploy_addons.sh`
4. Test in-game, use debug mode to verify coordinates

**Scan unknown items:**
1. Launch Ascension, ensure WRC_DevTools loaded
2. `/wrcdev scanlist 520000 521000` (adjust range)
3. Wait for completion (check `/wrcdev progress`)
4. Logout → extract SavedVariables → parse with Python scripts

**Debug missing pins:**
- Toggle: `WRC_DB.settings.debugMode = true` (or via Options panel)
- Check zone names: `/dump GetCurrentMapContinent(), GetCurrentMapZone()`
- Verify `WRC.zoneNames[c][z]` matches `WRC_DATA.mapPins[c][z]` keys
- Shift+click pin to see itemID, coordinates in tooltip

**Reference existing patterns:**
- Check `archive/addons/related-rpg-addons/HandyNotes_AscensionRPGItems/Core.lua` for:
  - HandyNotes plugin architecture (if adapting)
  - Stat parsing with bit masks (`STAT_BITS`, `EFFECT_BITS`)
  - Class proficiency tables (`CLASS_PROF`, `WEAPON_PROF`)
- These are 3.3.5-compatible implementations with Ascension-specific APIs

---

## Project-Specific Patterns

**Coordinate Normalization:**
- WorldMap coordinates are 0.0–1.0 (normalized)
- Minimap uses yard-based offsets with player rotation
- Pin key format: `"x:y"` with 3 decimal precision (`"0.581:0.520"`)

**Variant Tracking:**
- Multiple items at same location: `variants[]` array in pin data
- Tooltip shows all variants, collection tracks per itemID
- Use `WRC:GetPinVariants(coordKey)` to iterate

**Collection State:**
- `WRC_DB.collected[itemID] = { timestamp, character }` - permanent
- `WRC_DB.hidden[itemID] = { reason, timestamp, character }` - temporary hide (can reset)
- Distinction allows "I found this" vs "I don't want to see this pin"

**Python Tooling Assumptions:**
- All scripts run from repo root: `python3 ./path/to/script.py`
- Relative paths in code (no `os.chdir()` hacks)
- UTF-8 input/output, JSON for structured data
- temp/ directory for throwaways (CSVs, diffs, reports)

---

## File Organization

```
Repository Structure:
├── WarcraftRebornCollector/     # Active addon: player collector
│   ├── *.toc                    # Interface 30300
│   ├── Core.lua                 # Init, events, state
│   ├── Map.lua                  # Rendering, math
│   └── Data.lua                 # Generated (350KB+)
├── WRC_DevTools/                # Active addon: scanner
│   ├── Core.lua                 # Commands
│   └── Scanner.lua              # Tooltip parsing
├── data/
│   ├── final/                   # wrc_final_dataset.json (source of truth)
│   ├── intermediate/            # Processing stages
│   └── raw/                     # Unprocessed inputs
├── scripts/                     # Deployment + data processing
├── tools/                       # Utilities (duplicates repo root)
├── archive/                     # Old HandyNotes versions, reference addons
└── temp/                        # Throwaway outputs (reports, CSVs)
```

**Key Files:**
- `.github/copilot-instructions.md` - This file
- `README.md` - User-facing (outdated HandyNotes focus)
- `WARCRAFTREBORNCOLLECTOR_PLAN.md` - Architecture decisions (2900 lines)
- `convert_json_to_lua.py` - Main data generator
- `scripts/deploy_addons.sh` - Deployment script (WSL → Windows path)
