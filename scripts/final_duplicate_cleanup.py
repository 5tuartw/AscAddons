#!/usr/bin/env python3
"""
Advanced duplicate detection with manual review rules and pattern matching.
"""

import json
import csv
from pathlib import Path
from collections import defaultdict
import re

INPUT_DATA = Path("data/intermediate/worldforged_items_location_matched.json")
OUTPUT_CLEANED = Path("data/intermediate/worldforged_items_final_cleaned.json")
OUTPUT_REMOVED = Path("temp/final_removed_duplicates.json")
OUTPUT_REPORT = Path("temp/final_duplicate_report.md")

def load_data():
    """Load location-matched items."""
    with open(INPUT_DATA, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data['items']

def calculate_distance(x1, y1, x2, y2):
    """Calculate distance between two points."""
    import math
    return math.sqrt((x2 - x1)**2 + (y2 - y1)**2)

def normalize_name(name):
    """Normalize name for comparison."""
    if not name:
        return ""
    # Remove common suffixes (only as separate word, not in middle)
    name = re.sub(r'\s+[Pp]rop$', '', name)
    return name.lower().strip()

def find_advanced_duplicates(items):
    """
    Find duplicates using advanced rules:
    1. Items with "Prop" suffix are duplicates of non-prop versions
    2. Same itemID at very close locations (< 0.001 distance)
    3. Items from specific game modes (Mysterious Cache, Orb, Portal)
    4. Same placeholder name at identical coordinates
    """
    
    to_remove = []
    removal_reasons = []
    
    # Rule 1: Remove known game mode items and quest items
    game_mode_names = [
        'Mysterious Cache',
        'Mysterious Orb', 
        'Unstable Manastorm Portal',
        "Quel'Thalas Sunken Treasure Chest",
    ]
    
    for idx, item in enumerate(items):
        name = item.get('name', '')
        for gm_name in game_mode_names:
            if name == gm_name:
                to_remove.append(idx)
                removal_reasons.append({
                    'index': idx,
                    'name': name,
                    'zone': item.get('zone', ''),
                    'coords': f"({item.get('x', ''):.3f}, {item.get('y', ''):.3f})",
                    'reason': f'Game mode item: {gm_name}'
                })
                break
    
    # Rule 2: Props are duplicates (only if " Prop" or " prop" as suffix)
    # Build index of non-prop items by normalized name
    non_prop_index = {}
    for idx, item in enumerate(items):
        if idx in to_remove:
            continue
        name = item.get('name', '')
        # Check for " Prop" as a word boundary (not in middle of word like "inappropriate" or "proper")
        if not re.search(r'\s+[Pp]rop$', name):
            normalized = normalize_name(name)
            zone = item.get('zone', '')
            key = f"{normalized}|{zone}"
            if key not in non_prop_index:
                non_prop_index[key] = []
            non_prop_index[key].append((idx, item))
    
    # Find prop items that have non-prop equivalents
    for idx, item in enumerate(items):
        if idx in to_remove:
            continue
        name = item.get('name', '')
        # Only match " Prop" or " prop" as suffix with space before it
        if re.search(r'\s+[Pp]rop$', name):
            normalized = normalize_name(name)
            zone = item.get('zone', '')
            key = f"{normalized}|{zone}"
            
            # Check if non-prop version exists
            if key in non_prop_index:
                to_remove.append(idx)
                non_prop_names = [it[1].get('name', '') for it in non_prop_index[key]]
                removal_reasons.append({
                    'index': idx,
                    'name': name,
                    'zone': zone,
                    'coords': f"({item.get('x', ''):.3f}, {item.get('y', ''):.3f})",
                    'reason': f'Prop duplicate of: {non_prop_names[0]}'
                })
    
    # Rule 3: Same itemID at very close locations (< 0.005 distance)
    itemid_locations = defaultdict(list)
    for idx, item in enumerate(items):
        if idx in to_remove:
            continue
        
        item_ids = item.get('itemIds', [])
        if not item_ids:
            single_id = item.get('itemID')
            if single_id:
                item_ids = [single_id]
        
        for item_id in item_ids:
            if item_id and item.get('x') is not None and item.get('y') is not None:
                itemid_locations[item_id].append((idx, item))
    
    for item_id, locations in itemid_locations.items():
        if len(locations) <= 1:
            continue
        
        # Sort by x, y to make comparison consistent
        locations.sort(key=lambda x: (x[1].get('x', 0), x[1].get('y', 0)))
        
        # Compare each pair
        for i in range(len(locations)):
            if locations[i][0] in to_remove:
                continue
            for j in range(i + 1, len(locations)):
                if locations[j][0] in to_remove:
                    continue
                    
                idx1, item1 = locations[i]
                idx2, item2 = locations[j]
                
                # Check if in same zone
                if item1.get('zone') != item2.get('zone'):
                    continue
                
                # Calculate distance
                dist = calculate_distance(
                    item1.get('x', 0), item1.get('y', 0),
                    item2.get('x', 0), item2.get('y', 0)
                )
                
                if dist < 0.005:  # Very close
                    # Keep the one with more info (prefer verified/matched)
                    score1 = (
                        bool(item1.get('verified_by_scan')) * 10 +
                        bool(item1.get('matched_from_location')) * 5 +
                        len(item1.get('name', ''))
                    )
                    score2 = (
                        bool(item2.get('verified_by_scan')) * 10 +
                        bool(item2.get('matched_from_location')) * 5 +
                        len(item2.get('name', ''))
                    )
                    
                    if score1 >= score2:
                        to_remove.append(idx2)
                        removal_reasons.append({
                            'index': idx2,
                            'name': item2.get('name', ''),
                            'zone': item2.get('zone', ''),
                            'coords': f"({item2.get('x', ''):.3f}, {item2.get('y', ''):.3f})",
                            'reason': f'Duplicate itemID {item_id} very close (dist={dist:.4f}) to: {item1.get("name", "")}'
                        })
                    else:
                        to_remove.append(idx1)
                        removal_reasons.append({
                            'index': idx1,
                            'name': item1.get('name', ''),
                            'zone': item1.get('zone', ''),
                            'coords': f"({item1.get('x', ''):.3f}, {item1.get('y', ''):.3f})",
                            'reason': f'Duplicate itemID {item_id} very close (dist={dist:.4f}) to: {item2.get("name", "")}'
                        })
                    break  # Only remove once
    
    # Rule 4: Exact same name and coordinates
    name_coord_index = defaultdict(list)
    for idx, item in enumerate(items):
        if idx in to_remove:
            continue
        name = item.get('name', '')
        zone = item.get('zone', '')
        x = item.get('x', 0)
        y = item.get('y', 0)
        
        if name and zone and x and y:
            key = f"{name}|{zone}|{x:.4f}|{y:.4f}"
            name_coord_index[key].append((idx, item))
    
    for key, group in name_coord_index.items():
        if len(group) <= 1:
            continue
        
        # Keep first, remove rest
        for i in range(1, len(group)):
            idx, item = group[i]
            if idx not in to_remove:
                to_remove.append(idx)
                removal_reasons.append({
                    'index': idx,
                    'name': item.get('name', ''),
                    'zone': item.get('zone', ''),
                    'coords': f"({item.get('x', ''):.3f}, {item.get('y', ''):.3f})",
                    'reason': f'Exact duplicate: same name + coordinates as {group[0][1].get("name", "")}'
                })
    
    return set(to_remove), removal_reasons

def suggest_more_patterns(items):
    """
    Suggest other patterns that might indicate duplicates.
    """
    suggestions = []
    
    # Pattern 1: Multiple items with similar names at close locations
    name_groups = defaultdict(list)
    for idx, item in enumerate(items):
        name = item.get('name', '')
        if not name:
            continue
        # Extract base name (remove common prefixes/suffixes)
        base = re.sub(r'^(Old|Ancient|Forgotten|Hidden|Lost|Mysterious)\s+', '', name, flags=re.IGNORECASE)
        base = re.sub(r'\s+(Chest|Cache|Crate|Supplies|Equipment|Pile|Stash|Box)$', '', base, flags=re.IGNORECASE)
        base = normalize_name(base)
        
        if len(base) > 3:  # Ignore very short bases
            zone = item.get('zone', '')
            key = f"{base}|{zone}"
            name_groups[key].append((idx, item))
    
    for key, group in name_groups.items():
        if len(group) >= 3:  # 3+ items with similar base names
            base_name = key.split('|')[0]
            zone = key.split('|')[1]
            suggestions.append({
                'pattern': 'Similar base names',
                'count': len(group),
                'base_name': base_name,
                'zone': zone,
                'examples': [item[1].get('name', '') for item in group[:5]]
            })
    
    # Pattern 2: Generic container names
    generic_names = [
        'Chest', 'Cache', 'Crate', 'Box', 'Barrel', 'Sack', 
        'Supplies', 'Equipment', 'Bundle', 'Package', 'Shipment'
    ]
    
    generic_items = defaultdict(list)
    for idx, item in enumerate(items):
        name = item.get('name', '')
        for generic in generic_names:
            if name == generic:  # Exact match to generic name
                zone = item.get('zone', '')
                generic_items[generic].append((zone, item))
    
    for generic, items_list in generic_items.items():
        if len(items_list) >= 2:
            suggestions.append({
                'pattern': 'Generic container name',
                'count': len(items_list),
                'name': generic,
                'zones': list(set(z for z, _ in items_list)),
                'note': 'Consider if these should have more specific names'
            })
    
    return suggestions

def main():
    print("Loading location-matched data...")
    items = load_data()
    print(f"✓ Loaded {len(items):,} items")
    
    print("\nFinding advanced duplicates...")
    to_remove_set, removal_reasons = find_advanced_duplicates(items)
    print(f"✓ Found {len(to_remove_set):,} items to remove")
    
    # Remove duplicates
    kept_items = [item for idx, item in enumerate(items) if idx not in to_remove_set]
    removed_items = [items[idx] for idx in sorted(to_remove_set)]
    
    print(f"\nResults:")
    print(f"  Input items:    {len(items):,}")
    print(f"  Items removed:  {len(removed_items):,}")
    print(f"  Items kept:     {len(kept_items):,}")
    
    # Get suggestions for more patterns
    print("\nAnalyzing for more potential duplicate patterns...")
    suggestions = suggest_more_patterns(kept_items)
    
    # Save cleaned data
    items_with_ids = sum(1 for item in kept_items if (item.get('itemIds') or item.get('itemID')))
    coverage = (items_with_ids / len(kept_items) * 100) if kept_items else 0
    
    output_data = {
        'metadata': {
            'total_items': len(kept_items),
            'items_with_itemid': items_with_ids,
            'itemid_coverage_percent': round(coverage, 2),
            'items_removed': len(removed_items),
            'removal_rules': [
                'Game mode items (Mysterious Cache, Orb, Portal)',
                'Prop suffix duplicates',
                'Same itemID at close locations (< 0.005 distance)',
                'Exact name + coordinate duplicates'
            ]
        },
        'items': kept_items
    }
    
    OUTPUT_CLEANED.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_CLEANED, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    print(f"\n✓ Saved cleaned data: {OUTPUT_CLEANED}")
    
    # Save removed items
    with open(OUTPUT_REMOVED, 'w', encoding='utf-8') as f:
        json.dump(removal_reasons, f, indent=2, ensure_ascii=False)
    print(f"✓ Saved removed items: {OUTPUT_REMOVED}")
    
    # Generate report
    report = []
    report.append("# Final Duplicate Removal Report\n\n")
    
    report.append("## Summary\n")
    report.append(f"- Input items: {len(items):,}\n")
    report.append(f"- Items removed: {len(removed_items):,}\n")
    report.append(f"- Items kept: {len(kept_items):,}\n")
    report.append(f"- ItemID coverage: {items_with_ids}/{len(kept_items)} ({coverage:.1f}%)\n\n")
    
    report.append("## Removal Rules Applied\n")
    report.append("1. **Game mode items**: Mysterious Cache, Mysterious Orb, Unstable Manastorm Portal\n")
    report.append("2. **Prop duplicates**: Items ending in 'Prop' that have non-prop equivalents\n")
    report.append("3. **Close itemID duplicates**: Same itemID within 0.005 distance\n")
    report.append("4. **Exact duplicates**: Same name + exact coordinates\n\n")
    
    # Group removal reasons by type
    reason_groups = defaultdict(list)
    for reason in removal_reasons:
        reason_type = reason['reason'].split(':')[0]
        reason_groups[reason_type].append(reason)
    
    report.append("## Removed Items by Reason\n\n")
    for reason_type, reasons in sorted(reason_groups.items()):
        report.append(f"### {reason_type} ({len(reasons)} items)\n\n")
        report.append("| Name | Zone | Coords | Reason |\n")
        report.append("|------|------|--------|--------|\n")
        for r in reasons[:50]:  # Show first 50
            report.append(f"| {r['name']} | {r['zone']} | {r['coords']} | {r['reason']} |\n")
        if len(reasons) > 50:
            report.append(f"\n*...and {len(reasons) - 50} more*\n")
        report.append("\n")
    
    # Add suggestions
    if suggestions:
        report.append("## Suggested Additional Review Patterns\n\n")
        report.append("These patterns might indicate more duplicates for manual review:\n\n")
        for i, sug in enumerate(suggestions[:20], 1):
            report.append(f"### {i}. {sug['pattern']}\n")
            for key, val in sug.items():
                if key != 'pattern':
                    report.append(f"- **{key}**: {val}\n")
            report.append("\n")
    
    with open(OUTPUT_REPORT, 'w', encoding='utf-8') as f:
        f.write(''.join(report))
    print(f"✓ Saved report: {OUTPUT_REPORT}")
    
    # Print suggestions summary
    if suggestions:
        print(f"\n📋 Found {len(suggestions)} potential duplicate patterns for manual review")
        print("   Check the report for details")
    
    print(f"\n✓ Final dataset: {len(kept_items):,} items ({coverage:.1f}% with itemIDs)")

if __name__ == '__main__':
    main()
