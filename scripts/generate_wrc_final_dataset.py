#!/usr/bin/env python3
"""
Convert cleaned worldforged items to WRC final dataset format.
Based on WORLDFORGED_DATA_STRUCTURE.md specification.
"""

import json
from pathlib import Path
from collections import defaultdict
import time

INPUT_DATA = Path("data/intermediate/worldforged_items_approved.json")
OUTPUT_FINAL = Path("data/final/wrc_final_dataset.json")

# Zone name to (continentID, zoneID) mapping from game
# Source: LootCollector Map.lua zoneData tables
ZONE_NAME_TO_IDS = {
    # Kalimdor (continent 1)
    'Ashenvale': (1, 2), 'Azshara': (1, 3), 'Azuremyst Isle': (1, 4), 'Bloodmyst Isle': (1, 6),
    'Darkshore': (1, 9), 'Darnassus': (1, 10), 'Desolace': (1, 11), 'Durotar': (1, 12),
    'Dustwallow Marsh': (1, 13), 'Felwood': (1, 16), 'Feralas': (1, 17), 'Maraudon': (1, 18),
    'Moonglade': (1, 19), 'Mulgore': (1, 21), 'Orgrimmar': (1, 22), 'Silithus': (1, 27),
    'Stonetalon Mountains': (1, 31), 'Tanaris': (1, 32), 'Teldrassil': (1, 33),
    'The Barrens': (1, 34), 'The Exodar': (1, 35), 'Thousand Needles': (1, 40),
    'Thunder Bluff': (1, 41), "Un'Goro Crater": (1, 44), 'Wailing Caverns': (1, 46),
    'Winterspring': (1, 47),
    
    # Eastern Kingdoms (continent 2)
    'Alterac Mountains': (2, 1), 'Arathi Highlands': (2, 3), 'Badlands': (2, 4),
    'Blasted Lands': (2, 6), 'Burning Steppes': (2, 7), 'Deadwind Pass': (2, 10),
    'Dun Morogh': (2, 12), 'Duskwood': (2, 13), 'Eastern Plaguelands': (2, 14),
    'Elwynn Forest': (2, 16), 'Eversong Woods': (2, 17), 'Ghostlands': (2, 19),
    'Hillsbrad Foothills': (2, 22), 'Ironforge': (2, 23), 'Isle of Quel\'Danas': (2, 24),
    'Loch Modan': (2, 27), 'Redridge Mountains': (2, 30), 'Searing Gorge': (2, 32),
    'Silvermoon City': (2, 35), 'Silverpine Forest': (2, 36), 'Stormwind City': (2, 37),
    'Stranglethorn Vale': (2, 38), 'Swamp of Sorrows': (2, 40), 'The Hinterlands': (2, 43),
    'Tirisfal Glades': (2, 44), 'Undercity': (2, 46), 'Western Plaguelands': (2, 47),
    'Westfall': (2, 48), 'Wetlands': (2, 49),
    
    # Outland (continent 3)
    "Blade's Edge Mountains": (3, 1), 'Hellfire Peninsula': (3, 2), 'Nagrand': (3, 3),
    'Netherstorm': (3, 4), 'Shadowmoon Valley': (3, 5), 'Shattrath City': (3, 6),
    'Terokkar Forest': (3, 7), 'Zangarmarsh': (3, 8),
    
    # Northrend (continent 4)
    'Borean Tundra': (4, 1), 'Crystalsong Forest': (4, 2), 'Dalaran': (4, 3),
    'Dragonblight': (4, 4), 'Grizzly Hills': (4, 5), 'Howling Fjord': (4, 6),
    'Icecrown': (4, 8), 'Sholazar Basin': (4, 9), 'The Storm Peaks': (4, 10),
    'Wintergrasp': (4, 11), "Zul'Drak": (4, 12),
}

def get_zone_ids(zone_name):
    """Get (continentID, zoneID) from zone name."""
    return ZONE_NAME_TO_IDS.get(zone_name, (0, 0))

def get_coord_hash(x, y):
    """Generate coordinate hash for location key."""
    # Round to 3 decimal places for consistency
    return f"{x:.3f}:{y:.3f}"

def load_data():
    """Load approved cleaned items."""
    with open(INPUT_DATA, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data['items'], data.get('metadata', {})

def convert_to_wrc_format(items):
    """
    Convert items to WRC final dataset format.
    Structure: mapPins[continentID][zoneID][coordHash] = { variants: [itemIDs], metadata }
    """
    
    # Organize by location (continent + zone + coords)
    map_pins = defaultdict(lambda: defaultdict(lambda: defaultdict(lambda: {
        'variants': [],
        'x': 0,
        'y': 0,
        'zone': '',
        'source': 'placeholder',
        'firstSeen': int(time.time()),
    })))
    
    item_details = {}
    
    for item in items:
        zone = item.get('zone', '')
        continent_id, zone_id = get_zone_ids(zone)
        
        if continent_id == 0 or zone_id == 0:
            # Unknown zone, skip
            continue
        
        x = item.get('x')
        y = item.get('y')
        
        if x is None or y is None:
            continue
        
        coord_hash = get_coord_hash(x, y)
        
        # Get itemIDs (handle both single and multiple)
        item_ids = []
        if item.get('itemIds'):
            item_ids = item.get('itemIds')
        elif item.get('itemID'):
            item_ids = [item.get('itemID')]
        
        # If no itemID, create placeholder entry
        if not item_ids:
            item_ids = [None]
        
        # Update location data
        location = map_pins[continent_id][zone_id][coord_hash]
        location['x'] = x
        location['y'] = y
        location['zone'] = zone
        location['continentID'] = continent_id
        location['zoneID'] = zone_id
        
        # Determine source priority
        source = item.get('source', 'placeholder')
        if item.get('matched_from_location'):
            source = 'location_match'
        elif item.get('verified_by_scan'):
            source = 'scan_verified'
        
        # Update source if higher priority
        priority = {'placeholder': 0, 'location_match': 1, 'scan_verified': 2}
        current_priority = priority.get(location.get('source', 'placeholder'), 0)
        new_priority = priority.get(source, 0)
        if new_priority > current_priority:
            location['source'] = source
        
        # Add variants
        for item_id in item_ids:
            if item_id and item_id not in location['variants']:
                location['variants'].append(item_id)
                
                # Add to item details
                if item_id not in item_details:
                    item_details[item_id] = {
                        'itemID': item_id,
                        'name': item.get('name', ''),
                        'itemType': 'WORLDFORGED',
                        'location': {
                            'continentID': continent_id,
                            'zoneID': zone_id,
                            'zone': zone,
                            'coordHash': coord_hash,
                            'x': x,
                            'y': y,
                        },
                        'quality': item.get('quality'),
                        'source': source,
                        'verified': bool(item.get('verified_by_scan')),
                        'matched': bool(item.get('matched_from_location')),
                    }
        
        # If no itemID, store placeholder reference
        if not item_ids or item_ids[0] is None:
            placeholder_key = f"placeholder_{coord_hash}"
            if placeholder_key not in location['variants']:
                location['variants'].append(placeholder_key)
                
                item_details[placeholder_key] = {
                    'name': item.get('name', ''),
                    'itemType': 'WORLDFORGED',
                    'location': {
                        'continentID': continent_id,
                        'zoneID': zone_id,
                        'zone': zone,
                        'coordHash': coord_hash,
                        'x': x,
                        'y': y,
                    },
                    'needsScanning': True,
                    'source': source,
                }
    
    # Convert defaultdict to regular dict for JSON serialization
    map_pins_dict = {}
    for continent_id, zones in map_pins.items():
        map_pins_dict[continent_id] = {}
        for zone_id, locations in zones.items():
            map_pins_dict[continent_id][zone_id] = {}
            for coord_hash, location_data in locations.items():
                map_pins_dict[continent_id][zone_id][coord_hash] = dict(location_data)
    
    return map_pins_dict, item_details

def generate_statistics(map_pins, item_details):
    """Generate statistics about the dataset."""
    stats = {
        'total_locations': 0,
        'total_items': len(item_details),
        'items_with_ids': 0,
        'items_needing_scan': 0,
        'locations_by_zone': {},
        'items_by_source': defaultdict(int),
        'multi_variant_locations': 0,
    }
    
    for continent_id, zones in map_pins.items():
        for zone_id, locations in zones.items():
            zone_count = len(locations)
            stats['total_locations'] += zone_count
            stats['locations_by_zone'][f"{continent_id}:{zone_id}"] = zone_count
            
            for coord_hash, location in locations.items():
                if len(location['variants']) > 1:
                    stats['multi_variant_locations'] += 1
    
    for item_id, details in item_details.items():
        if details.get('needsScanning'):
            stats['items_needing_scan'] += 1
        else:
            stats['items_with_ids'] += 1
        
        source = details.get('source', 'placeholder')
        stats['items_by_source'][source] += 1
    
    return stats

def main():
    print("Loading approved cleaned data...")
    items, metadata = load_data()
    print(f"✓ Loaded {len(items):,} items")
    
    print("\nConverting to WRC final dataset format...")
    map_pins, item_details = convert_to_wrc_format(items)
    
    print("\nGenerating statistics...")
    stats = generate_statistics(map_pins, item_details)
    
    print(f"\nDataset Statistics:")
    print(f"  Total locations:           {stats['total_locations']:,}")
    print(f"  Total items:               {stats['total_items']:,}")
    print(f"  Items with itemIDs:        {stats['items_with_ids']:,}")
    print(f"  Items needing scan:        {stats['items_needing_scan']:,}")
    print(f"  Multi-variant locations:   {stats['multi_variant_locations']:,}")
    
    print(f"\nItems by source:")
    for source, count in sorted(stats['items_by_source'].items()):
        print(f"  {source:20s}: {count:,}")
    
    print(f"\nTop 10 zones by location count:")
    sorted_zones = sorted(stats['locations_by_zone'].items(), key=lambda x: x[1], reverse=True)
    # Create reverse lookup: (continent, zone) -> name
    cont_zone_to_name = {v: k for k, v in ZONE_NAME_TO_IDS.items()}
    for zone_key, count in sorted_zones[:10]:
        # zone_key is like "2:16" (continent:zone)
        continent_id, zone_id = map(int, zone_key.split(':'))
        zone_name = cont_zone_to_name.get((continent_id, zone_id), f'Zone {zone_key}')
        print(f"  {zone_name:30s}: {count:,} locations")
    
    # Build final dataset
    final_dataset = {
        'version': '1.0.0',
        'generatedAt': int(time.time()),
        'metadata': {
            'total_locations': stats['total_locations'],
            'total_items': stats['total_items'],
            'items_with_ids': stats['items_with_ids'],
            'items_needing_scan': stats['items_needing_scan'],
            'multi_variant_locations': stats['multi_variant_locations'],
            'sources': dict(stats['items_by_source']),
            'pipeline_metadata': metadata,
        },
        'mapPins': map_pins,
        'itemDetails': item_details,
    }
    
    # Save final dataset
    OUTPUT_FINAL.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_FINAL, 'w', encoding='utf-8') as f:
        json.dump(final_dataset, f, indent=2, ensure_ascii=False)
    
    print(f"\n✓ Saved final dataset: {OUTPUT_FINAL}")
    print(f"\n✅ WRC final dataset ready for conversion to Lua!")

if __name__ == '__main__':
    main()
