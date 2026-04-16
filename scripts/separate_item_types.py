#!/usr/bin/env python3
"""
Separate enriched data into Worldforged items and Mystic Scrolls.

WarcraftRebornCollector should focus on Worldforged items (physical loot).
Mystic Scrolls should be tracked separately for future addon features.

Usage:
    python scripts/separate_item_types.py \\
        data/intermediate/placeholders_enriched.json \\
        data/intermediate/worldforged_items.json \\
        data/intermediate/mystic_scrolls.json
"""

import sys
import json
from pathlib import Path
from datetime import datetime


def is_mystic_scroll(item):
    """Check if item is a mystic scroll or glyph."""
    name = item.get('name', '').lower()
    return any(keyword in name for keyword in ['mystic scroll', 'glyph of', 'unimbued'])


def is_worldforged(item):
    """Check if item is worldforged (physical loot, not scrolls)."""
    return not is_mystic_scroll(item)


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        print("\nUsage: python scripts/separate_item_types.py <enriched.json> <worldforged.json> <scrolls.json>")
        sys.exit(1)
    
    enriched_file = sys.argv[1]
    worldforged_file = sys.argv[2]
    scrolls_file = sys.argv[3]
    
    print(f"Loading {enriched_file}...")
    with open(enriched_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    items = data['items']
    
    # Separate by type
    worldforged_items = [item for item in items if is_worldforged(item)]
    mystic_scrolls = [item for item in items if is_mystic_scroll(item)]
    
    # Calculate coverage
    wf_with_id = sum(1 for i in worldforged_items 
                     if i.get('itemId') or (i.get('itemIds') and len(i['itemIds']) > 0))
    ms_with_id = sum(1 for i in mystic_scrolls 
                     if i.get('itemId') or (i.get('itemIds') and len(i['itemIds']) > 0))
    
    print("\n" + "="*60)
    print("ITEM TYPE SEPARATION")
    print("="*60)
    print(f"Total items:           {len(items)}")
    print(f"Worldforged items:     {len(worldforged_items)} ({wf_with_id} with itemID = {100*wf_with_id/len(worldforged_items):.1f}%)")
    print(f"Mystic Scrolls:        {len(mystic_scrolls)} ({ms_with_id} with itemID = {100*ms_with_id/len(mystic_scrolls):.1f}%)")
    print("="*60)
    
    # Create worldforged output
    worldforged_data = {
        'metadata': {
            'generated_date': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'source_file': enriched_file,
            'item_type': 'worldforged',
            'description': 'Physical loot items for WarcraftRebornCollector',
            'statistics': {
                'total_items': len(worldforged_items),
                'items_with_itemid': wf_with_id,
                'itemid_coverage_pct': round(100 * wf_with_id / len(worldforged_items), 1)
            }
        },
        'items': worldforged_items
    }
    
    # Create mystic scrolls output
    scrolls_data = {
        'metadata': {
            'generated_date': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'source_file': enriched_file,
            'item_type': 'mystic_scrolls',
            'description': 'Mystic Scrolls and Glyphs (tracked separately from Worldforged items)',
            'statistics': {
                'total_items': len(mystic_scrolls),
                'items_with_itemid': ms_with_id,
                'itemid_coverage_pct': round(100 * ms_with_id / len(mystic_scrolls), 1) if mystic_scrolls else 0
            }
        },
        'items': mystic_scrolls
    }
    
    # Write outputs
    print(f"\nWriting {worldforged_file}...")
    Path(worldforged_file).parent.mkdir(parents=True, exist_ok=True)
    with open(worldforged_file, 'w', encoding='utf-8') as f:
        json.dump(worldforged_data, f, indent=2)
    
    print(f"Writing {scrolls_file}...")
    Path(scrolls_file).parent.mkdir(parents=True, exist_ok=True)
    with open(scrolls_file, 'w', encoding='utf-8') as f:
        json.dump(scrolls_data, f, indent=2)
    
    print("\n✓ Item types separated successfully")
    print(f"  • Worldforged: {len(worldforged_items)} items → {worldforged_file}")
    print(f"  • Mystic Scrolls: {len(mystic_scrolls)} items → {scrolls_file}")


if __name__ == '__main__':
    main()
