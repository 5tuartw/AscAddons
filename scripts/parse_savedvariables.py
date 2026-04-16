#!/usr/bin/env python3
"""
Parse SavedVariables files to extract character-stored data about items.

Extracts from HandyNotes_AscensionRPG and AscensionRPGCollector SavedVariables:
- Name overrides (player-corrected names)
- Coordinate overrides (player-corrected positions)
- ItemIDs and variant levels from itemMeta
- Duplicate markers (items flagged as duplicates)
- NotRPG markers (items flagged as not RPG loot)
- Collected items by character (itemID → timestamp)
- Pending assignments (itemID → pid mappings from in-game discoveries)
- Pending creates (new discoveries not yet in Data_Placeholders.lua)

Output: JSON with enhancements to apply to placeholders

Usage:
    python scripts/parse_savedvariables.py \\
        archive/data/savedvars_current/HandyNotes_AscensionRPG_31-10-25.lua \\
        archive/data/savedvars_current/AscensionRPGCollector_31-10-25.lua \\
        data/intermediate/savedvars_enhancements.json
"""

import sys
import re
import json
from pathlib import Path
from datetime import datetime


def parse_lua_table(content, start_key):
    """
    Extract a Lua table by key name.
    Returns the table content as a string.
    """
    # Find the start of the table
    pattern = rf'\["{start_key}"\]\s*=\s*{{'
    match = re.search(pattern, content)
    if not match:
        return None
    
    # Find matching closing brace
    start = match.end()
    depth = 1
    pos = start
    
    while pos < len(content) and depth > 0:
        if content[pos] == '{':
            depth += 1
        elif content[pos] == '}':
            depth -= 1
        pos += 1
    
    if depth == 0:
        return content[start:pos-1]
    return None


def extract_simple_kv_pairs(table_content):
    """Extract simple key = value pairs from Lua table."""
    result = {}
    # Match patterns like ["key"] = value or ["key"] = "value"
    pattern = r'\["([^"]+)"\]\s*=\s*(?:"([^"]+)"|([^,\n]+))'
    matches = re.finditer(pattern, table_content)
    
    for match in matches:
        key = match.group(1)
        value = match.group(2) if match.group(2) else match.group(3)
        if value:
            value = value.strip().rstrip(',')
            if value == 'true':
                value = True
            elif value == 'false':
                value = False
            elif value.isdigit():
                value = int(value)
            result[key] = value
    
    return result


def parse_item_meta(content):
    """
    Parse itemMeta section for itemIDs and variant levels.
    Returns: dict of pid → {itemIds: {itemId: level}}
    """
    item_meta_content = parse_lua_table(content, "itemMeta")
    if not item_meta_content:
        return {}
    
    result = {}
    
    # Find each PID's itemMeta entry
    # Pattern: ["PID"] = { ... ["itemLevels"] = { [itemId] = level } ... }
    pid_pattern = r'\["([A-Z0-9]+)"\]\s*=\s*\{'
    pid_matches = list(re.finditer(pid_pattern, item_meta_content))
    
    for i, pid_match in enumerate(pid_matches):
        pid = pid_match.group(1)
        
        # Find the end of this PID's block
        start = pid_match.end()
        if i + 1 < len(pid_matches):
            end = pid_matches[i + 1].start()
        else:
            end = len(item_meta_content)
        
        pid_content = item_meta_content[start:end]
        
        # Extract itemLevels
        item_levels_match = re.search(r'\["itemLevels"\]\s*=\s*\{([^}]+)\}', pid_content)
        if item_levels_match:
            levels_content = item_levels_match.group(1)
            # Extract [itemId] = level pairs
            level_matches = re.findall(r'\[(\d+)\]\s*=\s*(\d+)', levels_content)
            
            if level_matches:
                result[pid] = {
                    'itemIds': {int(item_id): int(level) for item_id, level in level_matches}
                }
    
    return result


def parse_collected_by_character(content):
    """
    Parse collectedByCharacter section.
    Returns: dict of itemId → {character: timestamp}
    """
    collected_content = parse_lua_table(content, "collectedByCharacter")
    if not collected_content:
        return {}
    
    result = {}
    
    # Pattern: [itemId] = { ["Character-Realm"] = timestamp }
    item_pattern = r'\[(\d+)\]\s*=\s*\{([^}]+)\}'
    matches = re.finditer(item_pattern, collected_content)
    
    for match in matches:
        item_id = int(match.group(1))
        char_content = match.group(2)
        
        # Extract character names and timestamps
        char_matches = re.findall(r'\["([^"]+)"\]\s*=\s*(\d+)', char_content)
        if char_matches:
            result[item_id] = {char: int(ts) for char, ts in char_matches}
    
    return result


def parse_pending_assignments(content):
    """
    Parse pendingAssignments from AscensionRPGCollector.
    Returns: dict of itemId → {pid, timestamp}
    """
    pending_content = parse_lua_table(content, "pendingAssignments")
    if not pending_content:
        return {}
    
    result = {}
    
    # Pattern: [itemId] = { ["pid"] = "...", ["ts"] = timestamp }
    item_pattern = r'\[(\d+)\]\s*=\s*\{([^}]+)\}'
    matches = re.finditer(item_pattern, pending_content)
    
    for match in matches:
        item_id = int(match.group(1))
        content_block = match.group(2)
        
        pid_match = re.search(r'\["pid"\]\s*=\s*"([^"]+)"', content_block)
        ts_match = re.search(r'\["ts"\]\s*=\s*(\d+)', content_block)
        
        if pid_match:
            result[item_id] = {
                'pid': pid_match.group(1),
                'timestamp': int(ts_match.group(1)) if ts_match else None
            }
    
    return result


def parse_pending_creates(content):
    """
    Parse pendingCreates from AscensionRPGCollector.
    Returns: list of new discoveries with itemId, name, coords, zone
    """
    pending_content = parse_lua_table(content, "pendingCreates")
    if not pending_content:
        return []
    
    result = []
    
    # Pattern: [itemId] = { ["itemName"] = "...", ["zone"] = "...", ["x"] = ..., ["y"] = ... }
    item_pattern = r'\[(\d+)\]\s*=\s*\{([^}]+)\}'
    matches = re.finditer(item_pattern, pending_content)
    
    for match in matches:
        item_id = int(match.group(1))
        content_block = match.group(2)
        
        name_match = re.search(r'\["itemName"\]\s*=\s*"([^"]+)"', content_block)
        zone_match = re.search(r'\["zone"\]\s*=\s*"([^"]+)"', content_block)
        continent_match = re.search(r'\["continent"\]\s*=\s*"([^"]+)"', content_block)
        x_match = re.search(r'\["x"\]\s*=\s*([0-9.]+)', content_block)
        y_match = re.search(r'\["y"\]\s*=\s*([0-9.]+)', content_block)
        ts_match = re.search(r'\["ts"\]\s*=\s*(\d+)', content_block)
        
        if name_match and zone_match:
            result.append({
                'itemId': item_id,
                'itemName': name_match.group(1),
                'zone': zone_match.group(1),
                'continent': continent_match.group(1) if continent_match else None,
                'x': float(x_match.group(1)) if x_match else None,
                'y': float(y_match.group(1)) if y_match else None,
                'timestamp': int(ts_match.group(1)) if ts_match else None
            })
    
    return result


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        print("\nUsage: python scripts/parse_savedvariables.py <handynotes.lua> <collector.lua> <output.json>")
        sys.exit(1)
    
    handynotes_file = sys.argv[1]
    collector_file = sys.argv[2]
    output_file = sys.argv[3]
    
    print(f"Reading {handynotes_file}...")
    with open(handynotes_file, 'r', encoding='utf-8') as f:
        handynotes_content = f.read()
    
    print(f"Reading {collector_file}...")
    with open(collector_file, 'r', encoding='utf-8') as f:
        collector_content = f.read()
    
    print("\nParsing HandyNotes_AscensionRPG...")
    
    # Extract simple tables
    name_overrides_content = parse_lua_table(handynotes_content, "nameOverrides")
    name_overrides = extract_simple_kv_pairs(name_overrides_content) if name_overrides_content else {}
    print(f"  • Name overrides: {len(name_overrides)}")
    
    coord_overrides_content = parse_lua_table(handynotes_content, "coordOverrides")
    coord_overrides = {}  # TODO: Parse coordinate overrides if needed
    
    duplicate_content = parse_lua_table(handynotes_content, "duplicate")
    duplicates = extract_simple_kv_pairs(duplicate_content) if duplicate_content else {}
    duplicates = {k: v for k, v in duplicates.items() if v is True}
    print(f"  • Duplicate markers: {len(duplicates)}")
    
    not_rpg_content = parse_lua_table(handynotes_content, "notRPG")
    not_rpg = extract_simple_kv_pairs(not_rpg_content) if not_rpg_content else {}
    not_rpg = {k: v for k, v in not_rpg.items() if v is True}
    print(f"  • NotRPG markers: {len(not_rpg)}")
    
    item_meta = parse_item_meta(handynotes_content)
    print(f"  • ItemMeta entries (PIDs with itemIDs): {len(item_meta)}")
    
    collected = parse_collected_by_character(handynotes_content)
    print(f"  • Collected items: {len(collected)}")
    
    print("\nParsing AscensionRPGCollector...")
    
    pending_assignments = parse_pending_assignments(collector_content)
    print(f"  • Pending assignments (itemID→PID): {len(pending_assignments)}")
    
    pending_creates = parse_pending_creates(collector_content)
    print(f"  • Pending creates (new discoveries): {len(pending_creates)}")
    
    # Compile results
    enhancements = {
        'source_files': {
            'handynotes': handynotes_file,
            'collector': collector_file
        },
        'extracted_date': datetime.now().strftime('%Y-%m-%d'),
        'summary': {
            'name_overrides': len(name_overrides),
            'duplicates': len(duplicates),
            'not_rpg': len(not_rpg),
            'item_meta_pids': len(item_meta),
            'collected_items': len(collected),
            'pending_assignments': len(pending_assignments),
            'pending_creates': len(pending_creates)
        },
        'name_overrides': name_overrides,
        'duplicates': list(duplicates.keys()),
        'not_rpg': list(not_rpg.keys()),
        'item_meta': item_meta,
        'collected_by_character': collected,
        'pending_assignments': pending_assignments,
        'pending_creates': pending_creates
    }
    
    # Write output
    print(f"\nWriting {output_file}...")
    Path(output_file).parent.mkdir(parents=True, exist_ok=True)
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(enhancements, f, indent=2)
    
    print(f"\n✓ Extracted {len(name_overrides) + len(duplicates) + len(not_rpg) + len(item_meta) + len(pending_assignments) + len(pending_creates)} total enhancements")
    print(f"✓ Output saved to: {output_file}")


if __name__ == '__main__':
    main()
