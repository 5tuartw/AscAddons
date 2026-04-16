#!/usr/bin/env python3
"""
Convert WRC final dataset (JSON) to Lua format for WarcraftRebornCollector addon.
Based on WORLDFORGED_DATA_STRUCTURE.md specification.
"""

import json
import sys
from pathlib import Path

def escape_lua_string(s):
    """Escape special characters for Lua strings."""
    if not isinstance(s, str):
        return str(s)
    
    # Escape backslashes first
    s = s.replace('\\', '\\\\')
    # Escape quotes
    s = s.replace('"', '\\"')
    # Escape newlines
    s = s.replace('\n', '\\n')
    s = s.replace('\r', '\\r')
    
    return s

def convert_to_lua(input_file, output_file):
    """Convert JSON dataset to Lua table format."""
    
    print(f"Reading {input_file}...")
    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    map_pins = data.get('mapPins', {})
    item_details = data.get('itemDetails', {})
    metadata = data.get('metadata', {})
    
    print(f"Dataset statistics:")
    print(f"  Total locations: {metadata.get('total_locations', 0):,}")
    print(f"  Total items: {metadata.get('total_items', 0):,}")
    print(f"  Items with IDs: {metadata.get('items_with_ids', 0):,}")
    print(f"  Multi-variant locations: {metadata.get('multi_variant_locations', 0):,}")
    
    # Start Lua file
    lua_lines = [
        "-- WarcraftRebornCollector Data",
        "-- Generated from wrc_final_dataset.json",
        f"-- Total locations: {metadata.get('total_locations', 0):,}",
        f"-- Total items: {metadata.get('total_items', 0):,}",
        f"-- Items with itemIDs: {metadata.get('items_with_ids', 0):,}",
        "",
        "WRC_DATA = {}",
        "",
    ]
    
    # Generate mapPins
    lua_lines.append("-- Map pins organized by continent -> zone -> location")
    lua_lines.append("WRC_DATA.mapPins = {")
    
    for continent_id in sorted(map_pins.keys(), key=int):
        zones = map_pins[continent_id]
        continent_names = {1: 'Kalimdor', 2: 'Eastern Kingdoms', 3: 'Outland', 4: 'Northrend'}
        continent_name = continent_names.get(int(continent_id), f'Continent {continent_id}')
        
        lua_lines.append(f"    [{continent_id}] = {{ -- {continent_name}")
        
        for zone_id in sorted(zones.keys(), key=int):
            locations = zones[zone_id]
            zone_name = list(locations.values())[0].get('zone', f'Zone {zone_id}') if locations else f'Zone {zone_id}'
            
            lua_lines.append(f"        [{zone_id}] = {{ -- {zone_name}")
            
            for coord_hash, location in sorted(locations.items()):
                x = location.get('x', 0)
                y = location.get('y', 0)
                variants = location.get('variants', [])
                source = location.get('source', 'placeholder')
                
                lua_lines.append(f'            ["{coord_hash}"] = {{')
                lua_lines.append(f'                x = {x:.3f},')
                lua_lines.append(f'                y = {y:.3f},')
                lua_lines.append(f'                zone = "{escape_lua_string(location.get("zone", ""))}",')
                lua_lines.append(f'                source = "{source}",')
                
                # Variants array
                lua_lines.append('                variants = {')
                for variant in variants:
                    if isinstance(variant, str):
                        # Placeholder key
                        lua_lines.append(f'                    "{variant}",')
                    else:
                        # Numeric itemID
                        lua_lines.append(f'                    {variant},')
                lua_lines.append('                },')
                
                lua_lines.append('            },')
            
            lua_lines.append('        },')
        
        lua_lines.append('    },')
    
    lua_lines.append('}')
    lua_lines.append('')
    
    # Generate itemDetails
    lua_lines.append("-- Detailed item information")
    lua_lines.append("WRC_DATA.itemDetails = {")
    
    for item_key in sorted(item_details.keys(), key=lambda k: str(k)):
        details = item_details[item_key]
        name = details.get('name', '')
        location = details.get('location', {})
        
        # Handle both numeric and string keys
        if isinstance(item_key, str) and item_key.startswith('placeholder_'):
            lua_lines.append(f'    ["{item_key}"] = {{')
        else:
            lua_lines.append(f'    [{item_key}] = {{')
        
        # Basic info
        if 'itemID' in details:
            lua_lines.append(f'        itemID = {details["itemID"]},')
        lua_lines.append(f'        name = "{escape_lua_string(name)}",')
        lua_lines.append(f'        itemType = "{details.get("itemType", "WORLDFORGED")}",')
        
        # Location reference
        lua_lines.append('        location = {')
        lua_lines.append(f'            zoneID = {location.get("zoneID", 0)},')
        lua_lines.append(f'            zone = "{escape_lua_string(location.get("zone", ""))}",')
        lua_lines.append(f'            coordHash = "{location.get("coordHash", "")}",')
        lua_lines.append(f'            x = {location.get("x", 0):.3f},')
        lua_lines.append(f'            y = {location.get("y", 0):.3f},')
        lua_lines.append('        },')
        
        # Optional fields
        if details.get('quality'):
            lua_lines.append(f'        quality = {details["quality"]},')
        
        if details.get('needsScanning'):
            lua_lines.append('        needsScanning = true,')
        
        if details.get('verified'):
            lua_lines.append('        verified = true,')
        
        if details.get('matched'):
            lua_lines.append('        matched = true,')
        
        lua_lines.append(f'        source = "{details.get("source", "placeholder")}",')
        
        lua_lines.append('    },')
    
    lua_lines.append('}')
    lua_lines.append('')
    
    # Generate stats summary
    lua_lines.append("-- Dataset statistics")
    lua_lines.append("WRC_DATA.stats = {")
    lua_lines.append(f'    totalLocations = {metadata.get("total_locations", 0)},')
    lua_lines.append(f'    totalItems = {metadata.get("total_items", 0)},')
    lua_lines.append(f'    itemsWithIDs = {metadata.get("items_with_ids", 0)},')
    lua_lines.append(f'    itemsNeedingScan = {metadata.get("items_needing_scan", 0)},')
    lua_lines.append(f'    multiVariantLocations = {metadata.get("multi_variant_locations", 0)},')
    lua_lines.append('}')
    
    # Write output
    print(f"\nWriting {output_file}...")
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lua_lines))
    
    file_size = Path(output_file).stat().st_size
    print(f"✓ Wrote {len(lua_lines):,} lines ({file_size:,} bytes)")
    print(f"\n✅ Lua data file ready: {output_file}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python convert_json_to_lua.py <input.json> [output.lua]")
        print("Example: python convert_json_to_lua.py data/final/wrc_final_dataset.json WarcraftRebornCollector/Data.lua")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else "WarcraftRebornCollector/Data.lua"
    
    convert_to_lua(input_file, output_file)

if __name__ == '__main__':
    main()
