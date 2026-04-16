#!/usr/bin/env python3
"""
Find suspicious items that might be duplicates and generate approval files.
"""

import json
import csv
from pathlib import Path
from collections import defaultdict
import re

INPUT_DATA = Path("data/intermediate/worldforged_items_final_cleaned.json")
OUTPUT_WATCH = Path("temp/manual_review_watchlist.txt")
OUTPUT_SUSPICIOUS = Path("temp/suspicious_items_for_approval.json")
OUTPUT_SUSPICIOUS_CSV = Path("temp/suspicious_items_for_approval.csv")

def load_data():
    """Load cleaned items."""
    with open(INPUT_DATA, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data['items']

def calculate_distance(x1, y1, x2, y2):
    """Calculate distance between two points."""
    import math
    return math.sqrt((x2 - x1)**2 + (y2 - y1)**2)

def find_suspicious_patterns(items):
    """
    Find items matching suspicious patterns:
    1. Zone density - multiple items in very small area (< 0.01)
    2. Very similar names in same zone
    3. Very short generic names
    4. Items named "Placeholder"
    """
    
    suspicious = {
        'zone_clusters': [],
        'similar_names': [],
        'generic_names': [],
        'placeholder_names': [],
        'watch_list': []
    }
    
    # Pattern 1: Zone density / clustering
    zone_items = defaultdict(list)
    for idx, item in enumerate(items):
        zone = item.get('zone', '')
        x = item.get('x')
        y = item.get('y')
        if zone and x is not None and y is not None:
            zone_items[zone].append((idx, item, x, y))
    
    # Track which items we've already added to clusters
    already_clustered = set()
    
    for zone, zone_list in zone_items.items():
        # Check for items very close together
        for i in range(len(zone_list)):
            idx1, item1, x1, y1 = zone_list[i]
            
            # Skip if already in a cluster
            if idx1 in already_clustered:
                continue
            
            cluster = [(idx1, item1)]
            
            for j in range(i + 1, len(zone_list)):
                idx2, item2, x2, y2 = zone_list[j]
                
                # Skip if already in a cluster
                if idx2 in already_clustered:
                    continue
                
                dist = calculate_distance(x1, y1, x2, y2)
                
                if dist < 0.01:  # Very close
                    cluster.append((idx2, item2))
            
            if len(cluster) >= 3:  # 3+ items clustered
                # Mark all items in this cluster as processed
                for idx, _ in cluster:
                    already_clustered.add(idx)
                
                suspicious['zone_clusters'].append({
                    'zone': zone,
                    'center': (x1, y1),
                    'count': len(cluster),
                    'items': [{'name': it.get('name', ''), 
                              'itemID': it.get('itemID') or (it.get('itemIds', [None])[0] if it.get('itemIds') else None),
                              'coords': f"({it.get('x', ''):.3f}, {it.get('y', ''):.3f})",
                              'index': idx} 
                             for idx, it in cluster]
                })
    
    # Pattern 2: Very similar names (Levenshtein-like)
    name_groups = defaultdict(list)
    for idx, item in enumerate(items):
        name = item.get('name', '')
        zone = item.get('zone', '')
        if name and len(name) > 3:
            # Group by first 3 chars + zone to find similar
            key = f"{name[:3].lower()}|{zone}"
            name_groups[key].append((idx, item))
    
    for key, group in name_groups.items():
        if len(group) >= 2:
            # Check if names are very similar
            names = [item[1].get('name', '') for item in group]
            # Simple similarity: share at least 70% of characters
            base_name = names[0].lower()
            similar = []
            for item_idx, item in group:
                name = item.get('name', '').lower()
                if name != base_name:
                    common = sum(1 for c in name if c in base_name)
                    if common / max(len(name), len(base_name)) > 0.7:
                        similar.append(item)
            
            if len(similar) >= 1:
                zone = key.split('|')[1]
                suspicious['similar_names'].append({
                    'zone': zone,
                    'base_name': names[0],
                    'similar_count': len(similar) + 1,
                    'items': [{'name': it.get('name', ''),
                              'itemID': it.get('itemID') or (it.get('itemIds', [None])[0] if it.get('itemIds') else None),
                              'coords': f"({it.get('x', ''):.3f}, {it.get('y', ''):.3f})"} 
                             for it in [group[0][1]] + similar]
                })
    
    # Pattern 3: Generic short names
    generic_short_names = [
        'Box', 'Bag', 'Crate', 'Chest', 'Sack', 'Barrel',
        'Cache', 'Stash', 'Pile', 'Bundle', 'Package',
        'Book', 'Tome', 'Scroll', 'Note', 'Letter'
    ]
    
    for idx, item in enumerate(items):
        name = item.get('name', '')
        if name in generic_short_names:
            suspicious['generic_names'].append({
                'name': name,
                'zone': item.get('zone', ''),
                'itemID': item.get('itemID') or (item.get('itemIds', [None])[0] if item.get('itemIds') else None),
                'coords': f"({item.get('x', ''):.3f}, {item.get('y', ''):.3f})"
            })
    
    # Pattern 4: "Placeholder" in name
    for idx, item in enumerate(items):
        name = item.get('name', '')
        if 'placeholder' in name.lower() or name.strip() == '':
            suspicious['placeholder_names'].append({
                'name': name or '(empty)',
                'zone': item.get('zone', ''),
                'itemID': item.get('itemID') or (item.get('itemIds', [None])[0] if item.get('itemIds') else None),
                'coords': f"({item.get('x', ''):.3f}, {item.get('y', ''):.3f})"
            })
    
    # Watch list: "Old Book" and "Chest"
    for idx, item in enumerate(items):
        name = item.get('name', '')
        if name == 'Old Book' or name == 'Chest':
            suspicious['watch_list'].append({
                'name': name,
                'zone': item.get('zone', ''),
                'itemID': item.get('itemID') or (item.get('itemIds', [None])[0] if item.get('itemIds') else None),
                'coords': f"({item.get('x', ''):.3f}, {item.get('y', ''):.3f})"
            })
    
    return suspicious

def main():
    print("Loading cleaned data...")
    items = load_data()
    print(f"✓ Loaded {len(items):,} items")
    
    print("\nAnalyzing for suspicious patterns...")
    suspicious = find_suspicious_patterns(items)
    
    # Count totals
    total_suspicious = (
        len(suspicious['zone_clusters']) +
        len(suspicious['similar_names']) +
        len(suspicious['generic_names']) +
        len(suspicious['placeholder_names'])
    )
    
    print(f"\nResults:")
    print(f"  Zone clusters (3+ items < 0.01 apart):  {len(suspicious['zone_clusters'])}")
    print(f"  Similar name groups:                    {len(suspicious['similar_names'])}")
    print(f"  Generic short names:                    {len(suspicious['generic_names'])}")
    print(f"  Placeholder names:                      {len(suspicious['placeholder_names'])}")
    print(f"  Watch list (Old Book, Chest):           {len(suspicious['watch_list'])}")
    
    # Save suspicious items
    OUTPUT_SUSPICIOUS.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_SUSPICIOUS, 'w', encoding='utf-8') as f:
        json.dump(suspicious, f, indent=2, ensure_ascii=False)
    print(f"\n✓ Saved suspicious items: {OUTPUT_SUSPICIOUS}")
    
    # Generate CSV for easy review
    csv_rows = []
    seen_items = set()  # Track unique items by name+coords to avoid duplicates
    
    # Zone clusters - only add each unique item once
    for cluster in suspicious['zone_clusters']:
        for item in cluster['items']:
            item_key = f"{item['name']}|{item['coords']}"
            if item_key not in seen_items:
                seen_items.add(item_key)
                csv_rows.append({
                    'pattern': 'Zone Cluster',
                    'zone': cluster['zone'],
                    'center_coords': f"({cluster['center'][0]:.3f}, {cluster['center'][1]:.3f})",
                    'cluster_count': cluster['count'],
                    'name': item['name'],
                    'itemID': item['itemID'] or '',
                    'coords': item['coords'],
                    'approve_removal': ''
                })
    
    # Similar names - only add each unique item once
    for group in suspicious['similar_names']:
        for item in group['items']:
            item_key = f"{item['name']}|{item['coords']}"
            if item_key not in seen_items:
                seen_items.add(item_key)
                csv_rows.append({
                    'pattern': 'Similar Names',
                    'zone': group['zone'],
                    'center_coords': '',
                    'cluster_count': group['similar_count'],
                    'name': item['name'],
                    'itemID': item['itemID'] or '',
                    'coords': item['coords'],
                    'approve_removal': ''
                })
    
    # Generic names - only add each unique item once
    for item in suspicious['generic_names']:
        item_key = f"{item['name']}|{item['coords']}"
        if item_key not in seen_items:
            seen_items.add(item_key)
            csv_rows.append({
                'pattern': 'Generic Name',
                'zone': item['zone'],
                'center_coords': '',
                'cluster_count': 1,
                'name': item['name'],
                'itemID': item['itemID'] or '',
                'coords': item['coords'],
                'approve_removal': ''
            })
    
    # Placeholder names - only add each unique item once
    for item in suspicious['placeholder_names']:
        item_key = f"{item['name']}|{item['coords']}"
        if item_key not in seen_items:
            seen_items.add(item_key)
            csv_rows.append({
                'pattern': 'Placeholder',
                'zone': item['zone'],
                'center_coords': '',
                'cluster_count': 1,
                'name': item['name'],
                'itemID': item['itemID'] or '',
                'coords': item['coords'],
                'approve_removal': ''
            })
    
    if csv_rows:
        with open(OUTPUT_SUSPICIOUS_CSV, 'w', encoding='utf-8', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=[
                'pattern', 'zone', 'center_coords', 'cluster_count', 
                'name', 'itemID', 'coords', 'approve_removal'
            ])
            writer.writeheader()
            writer.writerows(csv_rows)
        print(f"✓ Saved approval CSV: {OUTPUT_SUSPICIOUS_CSV}")
        print(f"  {len(csv_rows):,} items flagged for review")
    
    # Generate watch list
    if suspicious['watch_list']:
        with open(OUTPUT_WATCH, 'w', encoding='utf-8') as f:
            f.write("# Manual Review Watch List\n\n")
            f.write("Items to hunt down and verify in-game:\n\n")
            
            # Group by name
            watch_groups = defaultdict(list)
            for item in suspicious['watch_list']:
                watch_groups[item['name']].append(item)
            
            for name, items in sorted(watch_groups.items()):
                f.write(f"## {name} ({len(items)} items)\n\n")
                for item in items:
                    f.write(f"- {item['zone']} @ {item['coords']}")
                    if item['itemID']:
                        f.write(f" [itemID: {item['itemID']}]")
                    f.write("\n")
                f.write("\n")
        
        print(f"✓ Saved watch list: {OUTPUT_WATCH}")
        print(f"  {len(suspicious['watch_list'])} items to hunt")
    
    print(f"\n✅ Review {OUTPUT_SUSPICIOUS_CSV} and mark 'YES' in approve_removal column")

if __name__ == '__main__':
    main()
