#!/usr/bin/env python3
"""
Match items across sources by location to fill in missing itemIDs.
"""

import json
import math
from pathlib import Path
from collections import defaultdict

# Paths
CLEANED_ITEMS = Path("data/intermediate/worldforged_items_cleaned.json")
LOOTCOLLECTOR_DATA = Path("data/intermediate/lootcollector_discoveries_full.json")
OUTPUT_MATCHED = Path("data/intermediate/worldforged_items_location_matched.json")
OUTPUT_REPORT = Path("temp/location_matching_report.md")

# Distance threshold for matching (in normalized coordinates)
DISTANCE_THRESHOLD = 0.01  # ~1% of map = pretty close

# Zone ID to Name mapping (from WarcraftRebornCollector/Core.lua)
# Format: [continent][zoneID] = "Zone Name"
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

def get_zone_name_from_guid(guid, zone_id):
    """Extract continent from GUID and lookup zone name."""
    # GUID format: continent-zone-itemID-x-y
    parts = guid.split('-')
    if len(parts) >= 2:
        continent = int(parts[0])
        return ZONE_NAMES.get(continent, {}).get(zone_id)
    return None

def calculate_distance(x1, y1, x2, y2):
    """Calculate Euclidean distance between two points."""
    return math.sqrt((x2 - x1)**2 + (y2 - y1)**2)

def normalize_zone_name(zone):
    """Normalize zone names for comparison."""
    if not zone:
        return ""
    # Remove apostrophes, convert to lowercase
    return zone.replace("'", "").lower().strip()

def load_items():
    """Load cleaned worldforged items."""
    with open(CLEANED_ITEMS, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data['items']

def load_lootcollector():
    """Load LootCollector discoveries."""
    if not LOOTCOLLECTOR_DATA.exists():
        print(f"⚠ LootCollector data not found: {LOOTCOLLECTOR_DATA}")
        return []
    
    with open(LOOTCOLLECTOR_DATA, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    discoveries = data.get('discoveries', [])
    
    # Filter to worldforged only (skip mystic scrolls)
    items = []
    for disc in discoveries:
        name = disc.get('name', '')
        if 'Mystic Scroll' in name:
            continue
        items.append(disc)
    
    return items

def build_location_index(items):
    """Build spatial index for fast location lookup."""
    # Group by zone, then create spatial buckets
    zone_index = defaultdict(list)
    
    for item in items:
        # Convert zoneID to zone name if present
        zone = item.get('zone')
        if not zone and item.get('zoneID'):
            # Check if we have GUID (LootCollector format)
            guid = item.get('guid', '')
            if guid:
                zone = get_zone_name_from_guid(guid, item['zoneID'])
        
        zone = normalize_zone_name(zone)
        x = item.get('x')
        y = item.get('y')
        
        if zone and x is not None and y is not None:
            zone_index[zone].append({
                'item': item,
                'x': x,
                'y': y
            })
    
    return zone_index

def find_nearby_items(target_item, zone_index, threshold=DISTANCE_THRESHOLD):
    """Find items near target location."""
    zone = normalize_zone_name(target_item.get('zone', ''))
    x = target_item.get('x')
    y = target_item.get('y')
    
    if not zone or x is None or y is None:
        return []
    
    nearby = []
    for candidate in zone_index.get(zone, []):
        dist = calculate_distance(x, y, candidate['x'], candidate['y'])
        if dist <= threshold:
            nearby.append({
                'item': candidate['item'],
                'distance': dist
            })
    
    # Sort by distance
    nearby.sort(key=lambda x: x['distance'])
    return nearby

def match_items(worldforged_items, lootcollector_items):
    """Match worldforged items with lootcollector items by location."""
    
    # Build location index for lootcollector items
    lc_index = build_location_index(lootcollector_items)
    
    stats = {
        'total_items': len(worldforged_items),
        'items_without_ids': 0,
        'items_with_matches': 0,
        'items_with_multiple_matches': 0,
        'itemids_added': 0,
        'names_matched': 0,
        'items_updated': 0
    }
    
    matches_report = []
    updated_items = []
    
    for item in worldforged_items:
        # Check if item needs matching (no itemID)
        has_ids = bool(item.get('itemIds') or item.get('itemID'))
        
        if not has_ids:
            stats['items_without_ids'] += 1
            
            # Find nearby items in lootcollector
            nearby = find_nearby_items(item, lc_index, DISTANCE_THRESHOLD)
            
            if nearby:
                stats['items_with_matches'] += 1
                
                if len(nearby) > 1:
                    stats['items_with_multiple_matches'] += 1
                
                # Best match is closest
                best_match = nearby[0]
                lc_item = best_match['item']
                distance = best_match['distance']
                
                # Check if names match or are similar
                wf_name = item.get('name', '').lower()
                lc_name = lc_item.get('name', '').lower()
                name_match = wf_name == lc_name
                
                if name_match:
                    stats['names_matched'] += 1
                
                # Get itemID from lootcollector item
                lc_itemid = lc_item.get('itemID') or lc_item.get('itemId')
                
                if lc_itemid:
                    # Add itemID to worldforged item
                    if not item.get('itemIds'):
                        item['itemIds'] = []
                    
                    if lc_itemid not in item['itemIds']:
                        item['itemIds'].append(lc_itemid)
                        stats['itemids_added'] += 1
                        stats['items_updated'] += 1
                        
                        # Update name if exact match
                        if name_match:
                            item['name'] = lc_item.get('name', item.get('name'))
                        
                        # Add match metadata
                        item['matched_from_location'] = True
                        item['match_distance'] = round(distance, 6)
                        item['match_source'] = 'lootcollector'
                        
                        matches_report.append({
                            'wf_name': item.get('name'),
                            'lc_name': lc_item.get('name'),
                            'itemID': lc_itemid,
                            'zone': item.get('zone'),
                            'distance': distance,
                            'name_match': name_match,
                            'coords': f"({item.get('x'):.3f}, {item.get('y'):.3f})"
                        })
        
        updated_items.append(item)
    
    return updated_items, matches_report, stats

def generate_report(matches, stats):
    """Generate matching report."""
    report = []
    report.append("# Location-Based Item Matching Report\n\n")
    
    report.append("## Statistics\n")
    report.append(f"- Total items: {stats['total_items']:,}\n")
    report.append(f"- Items without itemIDs: {stats['items_without_ids']:,}\n")
    report.append(f"- Items with location matches: {stats['items_with_matches']:,}\n")
    report.append(f"- Items with multiple matches: {stats['items_with_multiple_matches']:,}\n")
    report.append(f"- **ItemIDs added: {stats['itemids_added']:,}**\n")
    report.append(f"- **Items updated: {stats['items_updated']:,}**\n")
    report.append(f"- Exact name matches: {stats['names_matched']:,}\n\n")
    
    if stats['items_without_ids'] > 0:
        match_rate = (stats['items_with_matches'] / stats['items_without_ids'] * 100)
        report.append(f"**Match rate: {match_rate:.1f}%** (of items without IDs)\n\n")
    
    report.append("## Distance Threshold\n")
    report.append(f"- Threshold: {DISTANCE_THRESHOLD} (normalized coordinates)\n")
    report.append(f"- Approximate distance: ~{DISTANCE_THRESHOLD * 100:.0f}% of map width\n\n")
    
    report.append("## Sample Matches (first 50)\n\n")
    report.append("| WF Name | LC Name | ItemID | Zone | Distance | Name Match | Coords |\n")
    report.append("|---------|---------|--------|------|----------|------------|--------|\n")
    
    for match in matches[:50]:
        name_icon = "✓" if match['name_match'] else "✗"
        report.append(f"| {match['wf_name']} | {match['lc_name']} | {match['itemID']} | ")
        report.append(f"{match['zone']} | {match['distance']:.4f} | {name_icon} | {match['coords']} |\n")
    
    if len(matches) > 50:
        report.append(f"\n*...and {len(matches) - 50} more matches*\n")
    
    return ''.join(report)

def main():
    print("Loading worldforged items...")
    worldforged = load_items()
    print(f"✓ Loaded {len(worldforged):,} worldforged items")
    
    print("\nLoading LootCollector data...")
    lootcollector = load_lootcollector()
    
    if not lootcollector:
        print("✗ No LootCollector data available. Please run parse_lootcollector.py first.")
        return
    
    print(f"✓ Loaded {len(lootcollector):,} LootCollector items")
    
    print(f"\nMatching items by location (threshold: {DISTANCE_THRESHOLD})...")
    updated_items, matches, stats = match_items(worldforged, lootcollector)
    
    print("\n" + "="*60)
    print("LOCATION MATCHING RESULTS")
    print("="*60)
    print(f"Total items:          {stats['total_items']:,}")
    print(f"Items without IDs:    {stats['items_without_ids']:,}")
    print(f"Items with matches:   {stats['items_with_matches']:,}")
    print(f"Multiple matches:     {stats['items_with_multiple_matches']:,}")
    print(f"ItemIDs added:        {stats['itemids_added']:,}")
    print(f"Items updated:        {stats['items_updated']:,}")
    print(f"Exact name matches:   {stats['names_matched']:,}")
    
    if stats['items_without_ids'] > 0:
        match_rate = (stats['items_with_matches'] / stats['items_without_ids'] * 100)
        print(f"\nMatch rate:           {match_rate:.1f}%")
    
    print("="*60)
    
    # Calculate new itemID coverage
    items_with_ids = sum(1 for item in updated_items if (item.get('itemIds') or item.get('itemID')))
    coverage = (items_with_ids / len(updated_items) * 100) if updated_items else 0
    print(f"\nNew itemID coverage: {items_with_ids}/{len(updated_items)} ({coverage:.1f}%)")
    
    # Save updated dataset
    output_data = {
        'metadata': {
            'total_items': len(updated_items),
            'items_with_itemid': items_with_ids,
            'itemid_coverage_percent': round(coverage, 2),
            'location_matching_stats': stats,
            'distance_threshold': DISTANCE_THRESHOLD
        },
        'items': updated_items
    }
    
    OUTPUT_MATCHED.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_MATCHED, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    print(f"\n✓ Saved matched dataset: {OUTPUT_MATCHED}")
    
    # Generate report
    report = generate_report(matches, stats)
    OUTPUT_REPORT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_REPORT, 'w', encoding='utf-8') as f:
        f.write(report)
    print(f"✓ Saved report: {OUTPUT_REPORT}")

if __name__ == '__main__':
    main()
