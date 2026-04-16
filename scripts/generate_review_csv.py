#!/usr/bin/env python3
"""
Generate comprehensive CSV for manual review in spreadsheet software.
Expands variant itemIDs to separate rows for easy filtering and analysis.
"""

import json
import csv
from pathlib import Path

# Paths
INPUT_DATA = Path("data/intermediate/worldforged_items_location_matched.json")
OUTPUT_CSV = Path("temp/worldforged_review.csv")

# Zone name to continent mapping (from WarcraftRebornCollector/Core.lua)
ZONE_TO_CONTINENT = {}

# Build reverse mapping from zone names to continents
CONTINENTS = {
    1: "Kalimdor",
    2: "Eastern Kingdoms", 
    3: "Outland",
    4: "Northrend"
}

ZONE_NAMES = {
    1: {  # Kalimdor
        2: "Ashenvale", 3: "Azshara", 4: "Azuremyst Isle", 6: "Bloodmyst Isle",
        9: "Darkshore", 10: "Darnassus", 11: "Desolace", 12: "Durotar",
        13: "Dustwallow Marsh", 16: "Felwood", 17: "Feralas", 18: "Maraudon",
        19: "Moonglade", 21: "Mulgore", 22: "Orgrimmar", 27: "Silithus",
        31: "Stonetalon Mountains", 32: "Tanaris", 33: "Teldrassil", 34: "The Barrens",
        35: "The Exodar", 40: "Thousand Needles", 41: "Thunder Bluff", 44: "Un'Goro Crater",
        46: "Wailing Caverns", 47: "Winterspring",
    },
    2: {  # Eastern Kingdoms
        1: "Alterac Mountains", 3: "Arathi Highlands", 4: "Badlands", 6: "Blasted Lands",
        7: "Burning Steppes", 10: "Deadwind Pass", 12: "Dun Morogh", 13: "Duskwood",
        14: "Eastern Plaguelands", 16: "Elwynn Forest", 17: "Eversong Woods", 19: "Ghostlands",
        22: "Hillsbrad Foothills", 23: "Ironforge", 24: "Isle of Quel'Danas",
        27: "Loch Modan", 30: "Redridge Mountains", 32: "Searing Gorge",
        35: "Silvermoon City", 36: "Silverpine Forest", 37: "Stormwind City",
        38: "Stranglethorn Vale", 40: "Swamp of Sorrows", 43: "The Hinterlands",
        44: "Tirisfal Glades", 46: "Undercity", 47: "Western Plaguelands",
        48: "Westfall", 49: "Wetlands",
    },
    3: {  # Outland
        1: "Blade's Edge Mountains", 2: "Hellfire Peninsula", 3: "Nagrand",
        4: "Netherstorm", 5: "Shadowmoon Valley", 6: "Shattrath City",
        7: "Terokkar Forest", 8: "Zangarmarsh",
    },
    4: {  # Northrend
        1: "Borean Tundra", 2: "Crystalsong Forest", 3: "Dalaran",
        4: "Dragonblight", 5: "Grizzly Hills", 6: "Howling Fjord",
        8: "Icecrown", 9: "Sholazar Basin", 10: "The Storm Peaks",
        11: "Wintergrasp", 12: "Zul'Drak",
    },
}

# Build reverse mapping
for continent_id, zones in ZONE_NAMES.items():
    for zone_id, zone_name in zones.items():
        ZONE_TO_CONTINENT[zone_name] = CONTINENTS[continent_id]

def normalize_zone_name(zone):
    """Normalize zone name for comparison."""
    if not zone:
        return ""
    return zone.replace("'", "").strip()

def get_continent_from_zone(zone_name):
    """Get continent name from zone name."""
    normalized = normalize_zone_name(zone_name)
    for zone, continent in ZONE_TO_CONTINENT.items():
        if normalize_zone_name(zone) == normalized:
            return continent
    return "Unknown"

def load_data():
    """Load location-matched worldforged items."""
    with open(INPUT_DATA, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data['items']

def expand_to_rows(items):
    """
    Expand items to CSV rows.
    Items with multiple itemIDs get one row per itemID.
    """
    rows = []
    
    for item in items:
        # Get basic info
        zone = item.get('zone', '')
        continent = get_continent_from_zone(zone)
        x = item.get('x', '')
        y = item.get('y', '')
        placeholder_name = item.get('name', '')
        source = item.get('source') or item.get('sourceType', '')
        
        # Additional metadata
        note = item.get('note', '')
        duplicate = item.get('duplicate', False)
        not_rpg = item.get('notRPG', False)
        verified_by_scan = item.get('verified_by_scan', False)
        matched_from_location = item.get('matched_from_location', False)
        match_distance = item.get('match_distance', '')
        
        # Get itemIDs (handle both itemIds array and single itemID)
        item_ids = item.get('itemIds', [])
        if not item_ids:
            single_id = item.get('itemID')
            if single_id:
                item_ids = [single_id]
        
        # If no itemIDs, create one row with empty itemID
        if not item_ids:
            rows.append({
                'continent': continent,
                'zone': zone,
                'x': f"{x:.4f}" if x else '',
                'y': f"{y:.4f}" if y else '',
                'itemID': '',
                'placeholder_name': placeholder_name,
                'source': source,
                'has_itemid': 'NO',
                'variant_count': 0,
                'duplicate_flag': 'YES' if duplicate else '',
                'not_rpg_flag': 'YES' if not_rpg else '',
                'verified_scan': 'YES' if verified_by_scan else '',
                'matched_location': 'YES' if matched_from_location else '',
                'match_distance': f"{match_distance:.6f}" if match_distance else '',
                'note': note or '',
            })
        else:
            # Create one row per itemID
            variant_count = len(item_ids)
            for idx, item_id in enumerate(item_ids):
                is_first = (idx == 0)
                rows.append({
                    'continent': continent,
                    'zone': zone,
                    'x': f"{x:.4f}" if x else '',
                    'y': f"{y:.4f}" if y else '',
                    'itemID': item_id,
                    'placeholder_name': placeholder_name if is_first else '',  # Only show on first variant
                    'source': source if is_first else '',
                    'has_itemid': 'YES',
                    'variant_count': variant_count if is_first else '',  # Only show on first variant
                    'duplicate_flag': 'YES' if (duplicate and is_first) else '',
                    'not_rpg_flag': 'YES' if (not_rpg and is_first) else '',
                    'verified_scan': 'YES' if (verified_by_scan and is_first) else '',
                    'matched_location': 'YES' if (matched_from_location and is_first) else '',
                    'match_distance': f"{match_distance:.6f}" if (match_distance and is_first) else '',
                    'note': note if is_first else '',
                })
    
    return rows

def main():
    print("Loading location-matched data...")
    items = load_data()
    print(f"✓ Loaded {len(items):,} items")
    
    print("\nExpanding items to rows (variants get separate rows)...")
    rows = expand_to_rows(items)
    print(f"✓ Generated {len(rows):,} rows")
    
    # Calculate stats
    rows_with_ids = sum(1 for row in rows if row['has_itemid'] == 'YES')
    rows_without_ids = sum(1 for row in rows if row['has_itemid'] == 'NO')
    unique_items = len(items)
    variants = rows_with_ids - sum(1 for row in rows if row['has_itemid'] == 'YES' and row['variant_count'])
    
    print(f"\nStats:")
    print(f"  Unique items: {unique_items:,}")
    print(f"  Rows with itemIDs: {rows_with_ids:,}")
    print(f"  Rows without itemIDs: {rows_without_ids:,}")
    print(f"  Variant rows: {variants:,}")
    
    # Write CSV
    print(f"\nWriting CSV to {OUTPUT_CSV}...")
    OUTPUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    
    fieldnames = [
        'continent',
        'zone',
        'x',
        'y',
        'itemID',
        'placeholder_name',
        'source',
        'has_itemid',
        'variant_count',
        'duplicate_flag',
        'not_rpg_flag',
        'verified_scan',
        'matched_location',
        'match_distance',
        'note',
    ]
    
    with open(OUTPUT_CSV, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    
    print(f"✓ Wrote {len(rows):,} rows to {OUTPUT_CSV}")
    
    # Summary by continent
    print("\nBreakdown by continent:")
    continent_counts = {}
    for row in rows:
        cont = row['continent']
        continent_counts[cont] = continent_counts.get(cont, 0) + 1
    
    for continent in sorted(continent_counts.keys()):
        count = continent_counts[continent]
        pct = (count / len(rows) * 100)
        print(f"  {continent:20s}: {count:4d} rows ({pct:5.1f}%)")
    
    print(f"\n✓ Done! Open {OUTPUT_CSV} in your spreadsheet software.")
    print("  - Each variant itemID gets its own row for easy filtering")
    print("  - Sort by continent, zone, or itemID to find patterns")
    print("  - Filter by 'has_itemid=NO' to see items needing scanning")
    print("  - Filter by 'matched_location=YES' to review location matches")

if __name__ == '__main__':
    main()
