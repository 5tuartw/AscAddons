#!/usr/bin/env python3
"""
Analyze duplicates across Worldforged items from multiple sources.

Detects:
1. Exact duplicates - same itemID
2. Name duplicates - same or very similar name
3. Location duplicates - same zone + close coordinates (within 0.02 or ~2%)
4. Potential matches - similar names that might be same item

Generates reports for:
- Auto-removable obvious duplicates
- Near-duplicates for manual review
- Potential itemID matches for placeholders without IDs

Usage:
    python scripts/analyze_duplicates.py \\
        data/intermediate/worldforged_items.json \\
        data/intermediate/lootcollector_readable.txt \\
        temp/duplicates_analysis.json \\
        temp/duplicates_report.csv
"""

import sys
import json
import re
import csv
from pathlib import Path
from collections import defaultdict
from difflib import SequenceMatcher


def normalize_name(name):
    """Normalize item name for comparison."""
    if not name:
        return ""
    # Remove special characters, lowercase, strip whitespace
    normalized = re.sub(r'[^\w\s]', '', name.lower())
    normalized = re.sub(r'\s+', ' ', normalized).strip()
    return normalized


def name_similarity(name1, name2):
    """Calculate similarity between two names (0.0 to 1.0)."""
    norm1 = normalize_name(name1)
    norm2 = normalize_name(name2)
    if not norm1 or not norm2:
        return 0.0
    return SequenceMatcher(None, norm1, norm2).ratio()


def coords_close(x1, y1, x2, y2, threshold=0.02):
    """Check if two coordinate pairs are close (within threshold)."""
    if x1 is None or y1 is None or x2 is None or y2 is None:
        return False
    distance = ((x1 - x2) ** 2 + (y1 - y2) ** 2) ** 0.5
    return distance <= threshold


def parse_lootcollector_readable(filepath):
    """Parse LootCollector readable format to extract items."""
    items = []
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Split by item separator
    item_blocks = content.split('Item ID: ')[1:]  # Skip header
    
    for block in item_blocks:
        lines = block.strip().split('\n')
        if len(lines) < 2:
            continue
        
        item = {}
        
        # Parse itemID (first line)
        item['itemId'] = int(lines[0].strip())
        
        # Parse fields
        for line in lines[1:]:
            if line.startswith('Name: '):
                item['name'] = line.replace('Name: ', '').strip()
            elif line.startswith('Quality: '):
                item['quality'] = line.replace('Quality: ', '').strip()
            elif '(' in line and ')' in line and 'Coords:' in line:
                # Parse zone from location line like "  • Tanaris (Kalimdor)"
                if '•' in line:
                    zone_part = line.split('•')[1].split('(')[0].strip()
                    item['zone'] = zone_part
                # Parse coordinates
                coord_match = re.search(r'Coords: \(([\d.]+), ([\d.]+)\)', line)
                if coord_match:
                    item['x'] = float(coord_match.group(1))
                    item['y'] = float(coord_match.group(2))
        
        # Filter out mystic scrolls
        if 'name' in item and not any(kw in item['name'].lower() for kw in ['mystic scroll', 'glyph of', 'unimbued']):
            item['source'] = 'lootcollector'
            items.append(item)
    
    return items


def find_duplicates(worldforged_items, lootcollector_items):
    """Find all types of duplicates."""
    
    all_items = []
    
    # Prepare worldforged items
    for item in worldforged_items:
        entry = {
            'pid': item.get('pid'),
            'itemId': item.get('itemId'),
            'itemIds': item.get('itemIds', []),
            'name': item.get('name'),
            'zone': item.get('zone'),
            'x': item.get('x'),
            'y': item.get('y'),
            'source': 'worldforged_placeholders',
            'duplicate_flag': item.get('duplicate', False),
            'notRPG_flag': item.get('notRPG', False),
            'variants': item.get('variants', [])
        }
        all_items.append(entry)
    
    # Add lootcollector items
    for item in lootcollector_items:
        all_items.append(item)
    
    # Analysis results
    results = {
        'total_items': len(all_items),
        'worldforged_count': len(worldforged_items),
        'lootcollector_count': len(lootcollector_items),
        'exact_itemid_duplicates': [],
        'name_duplicates': [],
        'location_duplicates': [],
        'potential_matches': [],
        'summary': {}
    }
    
    # 1. Find exact itemID duplicates
    print("  • Finding exact itemID duplicates...")
    itemid_groups = defaultdict(list)
    for i, item in enumerate(all_items):
        item_id = item.get('itemId')
        if item_id:
            itemid_groups[item_id].append((i, item))
        # Also check itemIds array
        for iid in item.get('itemIds', []):
            itemid_groups[iid].append((i, item))
    
    for item_id, group in itemid_groups.items():
        if len(group) > 1:
            results['exact_itemid_duplicates'].append({
                'itemId': item_id,
                'count': len(group),
                'items': [{'index': idx, 'pid': item.get('pid'), 'name': item.get('name'), 
                          'zone': item.get('zone'), 'source': item.get('source')} 
                         for idx, item in group]
            })
    
    # 2. Find name duplicates (exact name matches)
    print("  • Finding name duplicates...")
    name_groups = defaultdict(list)
    for i, item in enumerate(all_items):
        name = normalize_name(item.get('name', ''))
        if name:
            name_groups[name].append((i, item))
    
    for name, group in name_groups.items():
        if len(group) > 1:
            results['name_duplicates'].append({
                'normalized_name': name,
                'count': len(group),
                'items': [{'index': idx, 'pid': item.get('pid'), 'name': item.get('name'),
                          'itemId': item.get('itemId'), 'zone': item.get('zone'), 
                          'source': item.get('source')} 
                         for idx, item in group]
            })
    
    # 3. Find location duplicates (same zone + close coords)
    print("  • Finding location duplicates...")
    zone_groups = defaultdict(list)
    for i, item in enumerate(all_items):
        zone = item.get('zone')
        x = item.get('x')
        y = item.get('y')
        if zone and x is not None and y is not None:
            zone_groups[zone].append((i, item, x, y))
    
    for zone, items_in_zone in zone_groups.items():
        # Compare all pairs in same zone
        for i in range(len(items_in_zone)):
            for j in range(i + 1, len(items_in_zone)):
                idx1, item1, x1, y1 = items_in_zone[i]
                idx2, item2, x2, y2 = items_in_zone[j]
                
                if coords_close(x1, y1, x2, y2, threshold=0.02):
                    results['location_duplicates'].append({
                        'zone': zone,
                        'coords1': (x1, y1),
                        'coords2': (x2, y2),
                        'distance': ((x1 - x2) ** 2 + (y1 - y2) ** 2) ** 0.5,
                        'item1': {
                            'index': idx1,
                            'pid': item1.get('pid'),
                            'name': item1.get('name'),
                            'itemId': item1.get('itemId'),
                            'source': item1.get('source')
                        },
                        'item2': {
                            'index': idx2,
                            'pid': item2.get('pid'),
                            'name': item2.get('name'),
                            'itemId': item2.get('itemId'),
                            'source': item2.get('source')
                        }
                    })
    
    # 4. Find potential matches (similar names, one without itemID)
    print("  • Finding potential matches...")
    items_without_id = [(i, item) for i, item in enumerate(all_items) 
                       if not item.get('itemId') and not item.get('itemIds')]
    items_with_id = [(i, item) for i, item in enumerate(all_items) 
                    if item.get('itemId') or item.get('itemIds')]
    
    print(f"    Comparing {len(items_without_id)} items without ID against {len(items_with_id)} with ID...")
    
    # Build index of normalized names for faster lookup
    name_index = {}
    for idx2, item2 in items_with_id:
        name2 = normalize_name(item2.get('name', ''))
        if name2:
            if name2 not in name_index:
                name_index[name2] = []
            name_index[name2].append((idx2, item2))
    
    match_count = 0
    for idx1, item1 in items_without_id:
        name1 = item1.get('name', '')
        norm1 = normalize_name(name1)
        if not norm1:
            continue
        
        candidates = []
        
        # Check for exact normalized name match only (skip fuzzy matching for now - too slow)
        if norm1 in name_index:
            for idx2, item2 in name_index[norm1]:
                candidates.append({
                    'similarity': 1.0,
                    'item_with_id': {
                        'index': idx2,
                        'pid': item2.get('pid'),
                        'name': item2.get('name'),
                        'itemId': item2.get('itemId'),
                        'zone': item2.get('zone'),
                        'source': item2.get('source')
                    }
                })
        
        if candidates:
            match_count += 1
            # Sort by similarity
            candidates.sort(key=lambda x: x['similarity'], reverse=True)
            results['potential_matches'].append({
                'item_without_id': {
                    'index': idx1,
                    'pid': item1.get('pid'),
                    'name': name1,
                    'zone': item1.get('zone'),
                    'source': item1.get('source')
                },
                'candidates': candidates[:5]  # Top 5 matches
            })
    
    print(f"    Found exact name matches for {match_count} items (fuzzy matching skipped for performance)")
    
    # Generate summary
    results['summary'] = {
        'total_items': len(all_items),
        'worldforged_count': len(worldforged_items),
        'lootcollector_count': len(lootcollector_items),
        'exact_itemid_duplicate_groups': len(results['exact_itemid_duplicates']),
        'items_in_itemid_duplicates': sum(d['count'] for d in results['exact_itemid_duplicates']),
        'name_duplicate_groups': len(results['name_duplicates']),
        'items_in_name_duplicates': sum(d['count'] for d in results['name_duplicates']),
        'location_duplicate_pairs': len(results['location_duplicates']),
        'items_without_id': len(items_without_id),
        'potential_matches_found': len(results['potential_matches']),
        'estimated_unique_after_dedup': len(all_items) - sum(d['count'] - 1 for d in results['exact_itemid_duplicates'])
    }
    
    return results


def export_to_csv(results, csv_file):
    """Export duplicates analysis to CSV for manual review."""
    
    rows = []
    
    # Exact itemID duplicates
    for dup in results['exact_itemid_duplicates']:
        for i, item in enumerate(dup['items']):
            rows.append({
                'Type': 'EXACT_ITEMID',
                'Action': 'REMOVE' if i > 0 else 'KEEP',
                'ItemID': dup['itemId'],
                'PID': item.get('pid', ''),
                'Name': item.get('name', ''),
                'Zone': item.get('zone', ''),
                'Source': item.get('source', ''),
                'Notes': f"Duplicate {i+1} of {dup['count']}"
            })
    
    # Name duplicates
    for dup in results['name_duplicates']:
        for i, item in enumerate(dup['items']):
            has_itemid = 'YES' if item.get('itemId') else 'NO'
            rows.append({
                'Type': 'NAME_MATCH',
                'Action': 'REVIEW',
                'ItemID': item.get('itemId', ''),
                'PID': item.get('pid', ''),
                'Name': item.get('name', ''),
                'Zone': item.get('zone', ''),
                'Source': item.get('source', ''),
                'Notes': f"Name duplicate {i+1} of {dup['count']}, has_itemID={has_itemid}"
            })
    
    # Location duplicates
    for dup in results['location_duplicates']:
        distance = dup['distance']
        rows.append({
            'Type': 'LOCATION_CLOSE',
            'Action': 'REVIEW',
            'ItemID': f"{dup['item1'].get('itemId', '')} vs {dup['item2'].get('itemId', '')}",
            'PID': f"{dup['item1'].get('pid', '')} vs {dup['item2'].get('pid', '')}",
            'Name': f"{dup['item1'].get('name', '')} vs {dup['item2'].get('name', '')}",
            'Zone': dup['zone'],
            'Source': f"{dup['item1'].get('source', '')} vs {dup['item2'].get('source', '')}",
            'Notes': f"Distance: {distance:.4f}, Coords: {dup['coords1']} vs {dup['coords2']}"
        })
    
    # Potential matches
    for match in results['potential_matches']:
        item_no_id = match['item_without_id']
        for candidate in match['candidates'][:3]:  # Top 3
            similarity = candidate['similarity']
            candidate_item = candidate['item_with_id']
            rows.append({
                'Type': 'POTENTIAL_MATCH',
                'Action': 'REVIEW',
                'ItemID': candidate_item.get('itemId', ''),
                'PID': f"{item_no_id.get('pid', '')} → {candidate_item.get('pid', '')}",
                'Name': f"{item_no_id.get('name', '')} → {candidate_item.get('name', '')}",
                'Zone': f"{item_no_id.get('zone', '')} → {candidate_item.get('zone', '')}",
                'Source': f"{item_no_id.get('source', '')} → {candidate_item.get('source', '')}",
                'Notes': f"Similarity: {similarity:.1%}"
            })
    
    # Write CSV
    if rows:
        fieldnames = ['Type', 'Action', 'ItemID', 'PID', 'Name', 'Zone', 'Source', 'Notes']
        with open(csv_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)


def main():
    if len(sys.argv) != 5:
        print(__doc__)
        sys.exit(1)
    
    worldforged_file = sys.argv[1]
    lootcollector_file = sys.argv[2]
    output_json = sys.argv[3]
    output_csv = sys.argv[4]
    
    print("Loading data sources...")
    print(f"  • {worldforged_file}")
    with open(worldforged_file, 'r', encoding='utf-8') as f:
        worldforged_data = json.load(f)
    worldforged_items = worldforged_data['items']
    
    print(f"  • {lootcollector_file}")
    lootcollector_items = parse_lootcollector_readable(lootcollector_file)
    
    print(f"\nAnalyzing duplicates...")
    print(f"  Worldforged placeholders: {len(worldforged_items)} items")
    print(f"  LootCollector items: {len(lootcollector_items)} items")
    print(f"  Total to analyze: {len(worldforged_items) + len(lootcollector_items)} items")
    print()
    
    results = find_duplicates(worldforged_items, lootcollector_items)
    
    print("\n" + "="*70)
    print("DUPLICATE ANALYSIS SUMMARY")
    print("="*70)
    print(f"Total items analyzed:              {results['summary']['total_items']}")
    print(f"  • Worldforged placeholders:      {results['summary']['worldforged_count']}")
    print(f"  • LootCollector items:           {results['summary']['lootcollector_count']}")
    print("-"*70)
    print(f"Exact itemID duplicate groups:     {results['summary']['exact_itemid_duplicate_groups']}")
    print(f"  Items in duplicates:             {results['summary']['items_in_itemid_duplicates']}")
    print(f"Name duplicate groups:             {results['summary']['name_duplicate_groups']}")
    print(f"  Items in name duplicates:        {results['summary']['items_in_name_duplicates']}")
    print(f"Location duplicate pairs:          {results['summary']['location_duplicate_pairs']}")
    print(f"Items without itemID:              {results['summary']['items_without_id']}")
    print(f"  Potential matches found:         {results['summary']['potential_matches_found']}")
    print("-"*70)
    print(f"Estimated unique after dedup:      {results['summary']['estimated_unique_after_dedup']}")
    print(f"Target count (per game creators):  ~1800")
    print("="*70)
    
    # Save results
    print(f"\nWriting {output_json}...")
    Path(output_json).parent.mkdir(parents=True, exist_ok=True)
    with open(output_json, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2)
    
    print(f"Writing {output_csv}...")
    export_to_csv(results, output_csv)
    
    print("\n✓ Analysis complete!")
    print(f"  • Full results: {output_json}")
    print(f"  • Review CSV: {output_csv}")


if __name__ == '__main__':
    main()
