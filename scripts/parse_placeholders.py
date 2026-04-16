#!/usr/bin/env python3
"""
Parse Data_Placeholders.lua from HandyNotes_AscensionRPG addon.

Extracts all pin data including:
- pid (placeholder ID)
- name (item/object name)
- zone, continent
- x, y coordinates (0.0-1.0 range)
- itemIds array (for variants)
- metadata flags (notRPG, duplicate, note)

Output: JSON for merging, CSV for manual review
"""

import re
import json
import csv
from pathlib import Path

def parse_lua_string(s):
    """Parse Lua string, handling escape sequences"""
    if not s:
        return ""
    # Remove outer quotes
    s = s.strip()
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")):
        s = s[1:-1]
    # Handle common escapes
    s = s.replace('\\"', '"')
    s = s.replace("\\'", "'")
    s = s.replace('\\n', '\n')
    s = s.replace('\\\\', '\\')
    return s

def parse_item_ids(ids_str):
    """Parse itemIds array from Lua table"""
    if not ids_str:
        return []
    # Extract numbers from { num1, num2, ... }
    ids_str = ids_str.strip()
    if ids_str.startswith('{') and ids_str.endswith('}'):
        ids_str = ids_str[1:-1]
    # Split by comma and extract integers
    ids = []
    for part in ids_str.split(','):
        part = part.strip()
        if part and part.isdigit():
            ids.append(int(part))
    return ids

def parse_placeholders(lua_file_path):
    """Parse Data_Placeholders.lua and extract all items"""
    print(f"Parsing {lua_file_path}...")
    
    with open(lua_file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    items = []
    
    for line in lines:
        line = line.strip()
        
        # Skip comments and empty lines
        if not line or line.startswith('--') or line.startswith('local'):
            continue
        
        # Match pattern: t["PID"] = { ... }
        if not line.startswith('t["'):
            continue
        
        # Extract PID from key
        pid_match = re.match(r't\["([^"]+)"\]', line)
        if not pid_match:
            continue
        
        pid = pid_match.group(1)
        
        # Parse the table content (everything between { and })
        # Handle potential nested braces in itemIds
        item = {
            'pid': pid,
            'name': None,
            'zone': None,
            'continent': None,
            'x': None,
            'y': None,
            'itemIds': [],
            'sourceType': 'placeholder',
            'notRPG': False,
            'duplicate': False,
            'note': None
        }
        
        # Extract fields using regex on the full line
        # pid
        pid_val = re.search(r'pid="([^"]+)"', line)
        if pid_val:
            item['pid'] = pid_val.group(1)
        
        # name
        name_match = re.search(r'name="([^"]+)"', line)
        if name_match:
            item['name'] = parse_lua_string(name_match.group(1))
        
        # zone
        zone_match = re.search(r'zone="([^"]+)"', line)
        if zone_match:
            item['zone'] = parse_lua_string(zone_match.group(1))
        
        # continent
        cont_match = re.search(r'continent="([^"]+)"', line)
        if cont_match:
            item['continent'] = parse_lua_string(cont_match.group(1))
        
        # x coordinate
        x_match = re.search(r'[,\s]x=([\d.]+)', line)
        if x_match:
            item['x'] = float(x_match.group(1))
        
        # y coordinate
        y_match = re.search(r'[,\s]y=([\d.]+)', line)
        if y_match:
            item['y'] = float(y_match.group(1))
        
        # itemIds array - look for itemIds={ ... }
        ids_match = re.search(r'itemIds=\s*\{\s*([^}]+)\}', line)
        if ids_match:
            ids_str = ids_match.group(1)
            # Parse comma-separated numbers
            item['itemIds'] = parse_item_ids(ids_str)
        
        # notRPG flag
        if 'notRPG=true' in line:
            item['notRPG'] = True
        
        # duplicate flag
        if 'duplicate=true' in line:
            item['duplicate'] = True
        
        # note field
        note_match = re.search(r'note="([^"]+)"', line)
        if note_match:
            item['note'] = parse_lua_string(note_match.group(1))
        
        items.append(item)
    
    print(f"  ✓ Extracted {len(items)} placeholder items")
    return items

def generate_statistics(items):
    """Generate summary statistics"""
    stats = {
        'total_items': len(items),
        'with_itemids': len([i for i in items if i['itemIds']]),
        'without_itemids': len([i for i in items if not i['itemIds']]),
        'marked_not_rpg': len([i for i in items if i['notRPG']]),
        'marked_duplicate': len([i for i in items if i['duplicate']]),
        'with_notes': len([i for i in items if i['note']]),
        'by_continent': {},
        'by_zone': {},
        'top_variant_counts': []
    }
    
    # By continent
    for item in items:
        cont = item['continent'] or 'Unknown'
        stats['by_continent'][cont] = stats['by_continent'].get(cont, 0) + 1
    
    # By zone
    for item in items:
        zone = item['zone'] or 'Unknown'
        stats['by_zone'][zone] = stats['by_zone'].get(zone, 0) + 1
    
    # Items with most variants
    items_with_variants = [(item['pid'], item['name'], len(item['itemIds'])) 
                           for item in items if item['itemIds']]
    items_with_variants.sort(key=lambda x: x[2], reverse=True)
    stats['top_variant_counts'] = items_with_variants[:20]
    
    return stats

def export_to_json(items, output_path):
    """Export items to JSON"""
    print(f"\nExporting to {output_path}...")
    
    output = {
        'source': 'Data_Placeholders.lua',
        'source_path': 'archive/addons/old-versions/HandyNotes_AscensionRPG/Data_Placeholders.lua',
        'extracted_date': '2025-11-01',
        'items_count': len(items),
        'items': items
    }
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2)
    
    print(f"  ✓ {len(items)} items exported to JSON")

def export_to_csv(items, output_path):
    """Export items to CSV for manual review"""
    print(f"\nExporting to {output_path}...")
    
    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        fieldnames = ['pid', 'name', 'zone', 'continent', 'x', 'y', 
                      'itemIds_count', 'itemIds', 'notRPG', 'duplicate', 'note']
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        
        writer.writeheader()
        for item in items:
            writer.writerow({
                'pid': item['pid'],
                'name': item['name'],
                'zone': item['zone'],
                'continent': item['continent'],
                'x': item['x'],
                'y': item['y'],
                'itemIds_count': len(item['itemIds']),
                'itemIds': ','.join(map(str, item['itemIds'])) if item['itemIds'] else '',
                'notRPG': item['notRPG'],
                'duplicate': item['duplicate'],
                'note': item['note'] or ''
            })
    
    print(f"  ✓ {len(items)} items exported to CSV")

def print_statistics(stats):
    """Print summary statistics"""
    print("\n" + "=" * 70)
    print("DATA_PLACEHOLDERS.LUA EXTRACTION SUMMARY")
    print("=" * 70)
    
    print(f"\nTotal Items: {stats['total_items']}")
    print(f"  With itemIds: {stats['with_itemids']} ({stats['with_itemids']/stats['total_items']*100:.1f}%)")
    print(f"  Without itemIds: {stats['without_itemids']} ({stats['without_itemids']/stats['total_items']*100:.1f}%)")
    print(f"  Marked notRPG: {stats['marked_not_rpg']}")
    print(f"  Marked duplicate: {stats['marked_duplicate']}")
    print(f"  With notes: {stats['with_notes']}")
    
    print(f"\nBy Continent:")
    for cont, count in sorted(stats['by_continent'].items(), key=lambda x: x[1], reverse=True):
        print(f"  {cont:20} {count:4} items")
    
    print(f"\nTop 10 Zones:")
    sorted_zones = sorted(stats['by_zone'].items(), key=lambda x: x[1], reverse=True)[:10]
    for zone, count in sorted_zones:
        print(f"  {zone:30} {count:3} items")
    
    print(f"\nTop 10 Items with Most Variants:")
    for pid, name, count in stats['top_variant_counts'][:10]:
        print(f"  {name:40} {count:2} variants")
    
    print("\n" + "=" * 70)

def main():
    # Paths
    lua_file = Path('archive/addons/old-versions/HandyNotes_AscensionRPG/Data_Placeholders.lua')
    json_output = Path('data/intermediate/placeholders_extracted.json')
    csv_output = Path('data/intermediate/placeholders_extracted.csv')
    
    # Ensure output directory exists
    json_output.parent.mkdir(parents=True, exist_ok=True)
    
    # Parse
    items = parse_placeholders(lua_file)
    
    # Generate statistics
    stats = generate_statistics(items)
    
    # Export
    export_to_json(items, json_output)
    export_to_csv(items, csv_output)
    
    # Print summary
    print_statistics(stats)
    
    print(f"\n✓ Extraction complete!")
    print(f"  JSON: {json_output}")
    print(f"  CSV: {csv_output}")

if __name__ == '__main__':
    main()
