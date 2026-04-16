#!/usr/bin/env python3
"""
Merge SavedVariables enhancements with placeholder data.

Takes the parsed placeholders and enriches them with:
- Name corrections from nameOverrides
- ItemIDs from pendingAssignments and itemMeta
- Duplicate and notRPG flags
- Item variant levels
- New discoveries from pendingCreates

Usage:
    python scripts/enrich_placeholders.py \\
        data/intermediate/placeholders_extracted.json \\
        data/intermediate/savedvars_enhancements.json \\
        data/intermediate/placeholders_enriched.json
"""

import sys
import json
from pathlib import Path
from datetime import datetime


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        print("\nUsage: python scripts/enrich_placeholders.py <placeholders.json> <enhancements.json> <output.json>")
        sys.exit(1)
    
    placeholders_file = sys.argv[1]
    enhancements_file = sys.argv[2]
    output_file = sys.argv[3]
    
    print(f"Loading {placeholders_file}...")
    with open(placeholders_file, 'r', encoding='utf-8') as f:
        placeholder_data = json.load(f)
    
    # Handle both raw list and wrapped format
    if isinstance(placeholder_data, dict) and 'items' in placeholder_data:
        placeholders = placeholder_data['items']
    else:
        placeholders = placeholder_data
    
    print(f"Loading {enhancements_file}...")
    with open(enhancements_file, 'r', encoding='utf-8') as f:
        enhancements = json.load(f)
    
    # Create index by PID for fast lookup (use 'pid' field)
    placeholder_index = {item['pid']: item for item in placeholders}
    
    stats = {
        'original_count': len(placeholders),
        'names_updated': 0,
        'itemids_added': 0,
        'variants_added': 0,
        'duplicates_marked': 0,
        'not_rpg_marked': 0,
        'new_items_added': 0
    }
    
    print("\nApplying enhancements...")
    
    # 1. Apply name overrides
    print(f"  • Applying {len(enhancements['name_overrides'])} name overrides...")
    for pid, new_name in enhancements['name_overrides'].items():
        if pid in placeholder_index:
            old_name = placeholder_index[pid].get('name', '')
            placeholder_index[pid]['name'] = new_name
            placeholder_index[pid]['name_source'] = 'player_override'
            stats['names_updated'] += 1
    
    # 2. Apply itemMeta (itemIDs + variants)
    print(f"  • Applying {len(enhancements['item_meta'])} itemMeta entries...")
    for pid, meta in enhancements['item_meta'].items():
        if pid in placeholder_index:
            item_ids = meta.get('itemIds', {})
            
            if item_ids:
                # If item doesn't have itemId/itemIds, set the first one
                existing_ids = placeholder_index[pid].get('itemIds', [])
                if not existing_ids and not placeholder_index[pid].get('itemId'):
                    first_item_id = list(item_ids.keys())[0]
                    placeholder_index[pid]['itemId'] = first_item_id
                    placeholder_index[pid]['itemId_source'] = 'savedvars_itemMeta'
                    stats['itemids_added'] += 1
                
                # Store all variants
                if len(item_ids) > 0:
                    placeholder_index[pid]['variants'] = [
                        {'itemId': item_id, 'requiredLevel': level}
                        for item_id, level in item_ids.items()
                    ]
                    stats['variants_added'] += len(item_ids)
    
    # 3. Apply pending assignments (itemID → PID mappings)
    print(f"  • Applying {len(enhancements['pending_assignments'])} pending assignments...")
    for item_id, assignment in enhancements['pending_assignments'].items():
        pid = assignment['pid']
        if pid in placeholder_index:
            existing_ids = placeholder_index[pid].get('itemIds', [])
            if not existing_ids and not placeholder_index[pid].get('itemId'):
                placeholder_index[pid]['itemId'] = int(item_id)
                placeholder_index[pid]['itemId_source'] = 'savedvars_pendingAssignment'
                stats['itemids_added'] += 1
    
    # 4. Mark duplicates
    print(f"  • Marking {len(enhancements['duplicates'])} duplicates...")
    for pid in enhancements['duplicates']:
        if pid in placeholder_index:
            placeholder_index[pid]['duplicate'] = True
            stats['duplicates_marked'] += 1
    
    # 5. Mark notRPG
    print(f"  • Marking {len(enhancements['not_rpg'])} notRPG items...")
    for pid in enhancements['not_rpg']:
        if pid in placeholder_index:
            placeholder_index[pid]['notRPG'] = True
            stats['not_rpg_marked'] += 1
    
    # 6. Add new items from pendingCreates
    print(f"  • Adding {len(enhancements['pending_creates'])} new discoveries...")
    for create in enhancements['pending_creates']:
        new_item = {
            'pid': f"pending_{create['itemId']}",
            'itemId': create['itemId'],
            'name': create['itemName'],
            'zone': create['zone'],
            'continent': create.get('continent'),
            'x': create.get('x'),
            'y': create.get('y'),
            'itemIds': [],  # Will have itemId in itemId field
            'source': 'savedvars_pendingCreate',
            'itemId_source': 'savedvars_pendingCreate',
            'discoveryTimestamp': create.get('timestamp')
        }
        placeholder_index[new_item['pid']] = new_item
        stats['new_items_added'] += 1
    
    # Convert back to list
    enriched = list(placeholder_index.values())
    stats['final_count'] = len(enriched)
    
    # Calculate itemID coverage (check both itemId field and itemIds array)
    items_with_itemid = sum(1 for item in enriched 
                           if item.get('itemId') or (item.get('itemIds') and len(item['itemIds']) > 0))
    stats['items_with_itemid'] = items_with_itemid
    stats['itemid_coverage_pct'] = round(100 * items_with_itemid / len(enriched), 1)
    
    # Output
    output_data = {
        'metadata': {
            'generated_date': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'source_files': {
                'placeholders': placeholders_file,
                'enhancements': enhancements_file
            },
            'statistics': stats
        },
        'items': enriched
    }
    
    print(f"\nWriting {output_file}...")
    Path(output_file).parent.mkdir(parents=True, exist_ok=True)
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2)
    
    print("\n" + "="*60)
    print("ENRICHMENT SUMMARY")
    print("="*60)
    print(f"Original items:        {stats['original_count']}")
    print(f"Names updated:         {stats['names_updated']}")
    print(f"ItemIDs added:         {stats['itemids_added']}")
    print(f"Variants tracked:      {stats['variants_added']}")
    print(f"Duplicates marked:     {stats['duplicates_marked']}")
    print(f"NotRPG marked:         {stats['not_rpg_marked']}")
    print(f"New items added:       {stats['new_items_added']}")
    print(f"─" * 60)
    print(f"Final count:           {stats['final_count']}")
    print(f"Items with itemID:     {stats['items_with_itemid']} ({stats['itemid_coverage_pct']}%)")
    print("="*60)
    
    print(f"\n✓ Enriched data saved to: {output_file}")


if __name__ == '__main__':
    main()
