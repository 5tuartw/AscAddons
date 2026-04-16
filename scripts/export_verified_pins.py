#!/usr/bin/env python3
"""
Export verified pins from WRC_DB SavedVariables
Helps identify which duplicate pins have been verified as legitimate
"""

import json
import re
import sys
from pathlib import Path

def parse_lua_table(content, table_name):
    """Extract a Lua table as Python dict"""
    pattern = rf'{table_name}\s*=\s*{{([^}}]+)}}'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        return {}
    
    table_content = match.group(1)
    result = {}
    
    # Parse entries like: ["pid"] = { ... }
    entry_pattern = r'\["([^"]+)"\]\s*=\s*\{([^}]+)\}'
    for entry_match in re.finditer(entry_pattern, table_content):
        key = entry_match.group(1)
        value_str = entry_match.group(2)
        
        # Parse the inner table
        value = {}
        field_pattern = r'\["?(\w+)"?\]\s*=\s*"?([^",\n]+)"?'
        for field_match in re.finditer(field_pattern, value_str):
            field_name = field_match.group(1)
            field_value = field_match.group(2).strip()
            value[field_name] = field_value
        
        result[key] = value
    
    return result

def main():
    # Find WRC_DB in SavedVariables
    savedvars_path = Path('/mnt/d/Games/ascension-launcher/Ascension Patch 3/WTF/Account/5TUARTW/SavedVariables/WarcraftRebornCollector.lua')
    
    if not savedvars_path.exists():
        print(f"Error: SavedVariables not found at {savedvars_path}")
        print("Please update the path in this script or run after playing the game.")
        return
    
    print(f"Reading SavedVariables from: {savedvars_path}")
    content = savedvars_path.read_text(encoding='utf-8')
    
    # Parse verified table
    verified = parse_lua_table(content, 'verified')
    
    if not verified:
        print("\nNo verified pins found yet.")
        print("Use Alt+RightClick on pins in-game to mark them as verified legitimate.")
        return
    
    print(f"\n✓ Found {len(verified)} verified pins:")
    print("=" * 80)
    
    # Load cleaned data to get item details
    data_path = Path('data/intermediate/worldforged_items_cleaned.json')
    if data_path.exists():
        with open(data_path) as f:
            cleaned_data = json.load(f)
        
        items_by_id = {item.get('pid'): item for item in cleaned_data.get('items', [])}
        
        for pid, info in sorted(verified.items()):
            item = items_by_id.get(pid)
            if item:
                print(f"\nPID: {pid}")
                print(f"  Name: {item.get('name')}")
                print(f"  Zone: {item.get('zone')}")
                print(f"  Coords: ({item.get('x'):.3f}, {item.get('y'):.3f})")
                print(f"  ItemID: {item.get('itemIds', ['None'])[0] if item.get('itemIds') else 'None'}")
                print(f"  Verified by: {info.get('character', 'Unknown')}")
                print(f"  Date: {info.get('timestamp', 'Unknown')}")
            else:
                print(f"\nPID: {pid}")
                print(f"  (Item details not found in cleaned data)")
                print(f"  Verified by: {info.get('character', 'Unknown')}")
    else:
        print("\nCleaned data not found - showing PIDs only:")
        for pid, info in sorted(verified.items()):
            print(f"  {pid} - verified by {info.get('character', 'Unknown')}")
    
    print("\n" + "=" * 80)
    print(f"Total verified: {len(verified)}")

if __name__ == '__main__':
    main()
