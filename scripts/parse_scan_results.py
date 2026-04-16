#!/usr/bin/env python3
"""
Parse WRC_DevTools scan results and use them to identify and remove duplicates.
"""

import json
import re
from pathlib import Path
from collections import defaultdict

# Paths
SCAN_RESULTS = Path("WRC_DevTools savedvars.lua")
WORLDFORGED_ITEMS = Path("data/intermediate/worldforged_items.json")
DUPLICATES_ANALYSIS = Path("temp/duplicates_analysis.json")
OUTPUT_CLEANED = Path("data/intermediate/worldforged_items_cleaned.json")
OUTPUT_REPORT = Path("temp/deduplication_report.md")

def parse_lua_savedvars(file_path):
    """Parse Lua SavedVariables file to extract scanned items."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract scannedItems table
    scanned_items = {}
    
    # Pattern: [itemID] = { ["name"] = "...", ["quality"] = ..., ... }
    # Match item blocks
    pattern = r'\[(\d+)\]\s*=\s*\{([^}]+)\}'
    
    for match in re.finditer(pattern, content):
        item_id = int(match.group(1))
        item_block = match.group(2)
        
        # Extract name
        name_match = re.search(r'\["name"\]\s*=\s*"([^"]+)"', item_block)
        if not name_match:
            continue
        name = name_match.group(1)
        
        # Extract quality
        quality_match = re.search(r'\["quality"\]\s*=\s*(\d+)', item_block)
        quality = int(quality_match.group(1)) if quality_match else 0
        
        scanned_items[item_id] = {
            'name': name,
            'quality': quality,
            'itemID': item_id
        }
    
    return scanned_items

def load_worldforged_items():
    """Load worldforged items dataset."""
    with open(WORLDFORGED_ITEMS, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data['items']

def load_duplicates_analysis():
    """Load duplicates analysis."""
    with open(DUPLICATES_ANALYSIS, 'r', encoding='utf-8') as f:
        return json.load(f)

def deduplicate_items(items, scanned_items, duplicates_analysis):
    """
    Remove duplicates using scan results.
    Strategy:
    1. For items with same itemID, use scanned name as truth
    2. Remove entries where placeholder name doesn't match scanned name
    3. Keep the best entry per itemID (prefer entries with coords)
    4. Keep all items without itemIDs (can't deduplicate without ID)
    """
    
    # Separate items with and without IDs
    items_with_ids = []
    items_without_ids = []
    
    for item in items:
        item_ids = item.get('itemIds', [])
        if not item_ids:
            single_id = item.get('itemID')
            if single_id:
                item_ids = [single_id]
        
        if item_ids and any(item_ids):
            items_with_ids.append(item)
        else:
            items_without_ids.append(item)
    
    # Index items by itemID
    items_by_id = defaultdict(list)
    for item in items_with_ids:
        item_ids = item.get('itemIds', [])
        if not item_ids:
            single_id = item.get('itemID')
            if single_id:
                item_ids = [single_id]
        
        # Use first non-empty itemID for indexing
        for item_id in item_ids:
            if item_id:
                items_by_id[item_id].append(item)
                break  # Only index by first ID to avoid double-counting
    
    kept_items = []
    removed_items = []
    dedup_stats = {
        'total_input': len(items),
        'items_with_ids': len(items_with_ids),
        'items_without_ids': len(items_without_ids),
        'unique_itemids': len(items_by_id),
        'itemids_with_duplicates': 0,
        'items_removed': 0,
        'items_kept': 0,
        'name_mismatches_fixed': 0,
        'verified_by_scan': 0
    }
    
    # Keep all items without IDs (can't deduplicate)
    kept_items.extend(items_without_ids)
    
    # Process each itemID group
    for item_id, item_group in items_by_id.items():
        if len(item_group) == 1:
            # No duplicates for this ID
            kept_items.append(item_group[0])
            continue
        
        dedup_stats['itemids_with_duplicates'] += 1
        
        # Check if we have scan data for this itemID
        scanned = scanned_items.get(item_id)
        
        if scanned:
            dedup_stats['verified_by_scan'] += 1
            canonical_name = scanned['name']
            
            # Find best match
            best_item = None
            best_score = -1
            
            for item in item_group:
                score = 0
                item_name = item.get('name', '')
                
                # Exact name match
                if item_name == canonical_name:
                    score += 100
                
                # Has coordinates
                if item.get('x') and item.get('y'):
                    score += 50
                
                # Has zone
                if item.get('zone'):
                    score += 25
                
                # Prefer placeholder source (more curated)
                if item.get('source') == 'placeholder':
                    score += 10
                
                if score > best_score:
                    best_score = score
                    best_item = item
            
            # Update name if needed
            if best_item['name'] != canonical_name:
                dedup_stats['name_mismatches_fixed'] += 1
                best_item['name'] = canonical_name
            
            # Add scan verification
            best_item['verified_by_scan'] = True
            best_item['scanned_quality'] = scanned['quality']
            
            kept_items.append(best_item)
            
            # Track removed items
            for item in item_group:
                if item is not best_item:
                    removed_items.append({
                        'itemID': item_id,
                        'name': item.get('name'),
                        'reason': f'Duplicate of {canonical_name}',
                        'canonical_name': canonical_name
                    })
        else:
            # No scan data - use heuristic
            # Keep item with most complete data
            best_item = max(item_group, key=lambda x: (
                bool(x.get('x') and x.get('y')),  # Has coords
                bool(x.get('zone')),  # Has zone
                x.get('source') == 'placeholder',  # Prefer placeholder
                len(x.get('name', ''))  # Longer name
            ))
            
            kept_items.append(best_item)
            
            for item in item_group:
                if item is not best_item:
                    removed_items.append({
                        'itemID': item_id,
                        'name': item.get('name'),
                        'reason': f'Duplicate (no scan data)',
                        'kept_name': best_item.get('name')
                    })
    
    dedup_stats['items_kept'] = len(kept_items)
    dedup_stats['items_removed'] = len(removed_items)
    
    return kept_items, removed_items, dedup_stats

def generate_report(scanned_items, dedup_stats, removed_items):
    """Generate deduplication report."""
    report = []
    report.append("# Deduplication Report\n")
    report.append(f"Generated: {Path(__file__).name}\n\n")
    
    report.append("## Scan Results\n")
    report.append(f"- Items scanned: {len(scanned_items)}\n")
    report.append(f"- Scan success rate: {(len(scanned_items) / 678 * 100):.1f}%\n\n")
    
    report.append("## Deduplication Statistics\n")
    report.append(f"- Input items: {dedup_stats['total_input']}\n")
    report.append(f"- Items with itemIDs: {dedup_stats['items_with_ids']}\n")
    report.append(f"- Items without itemIDs: {dedup_stats['items_without_ids']}\n")
    report.append(f"- Unique itemIDs: {dedup_stats['unique_itemids']}\n")
    report.append(f"- ItemIDs with duplicates: {dedup_stats['itemids_with_duplicates']}\n")
    report.append(f"- Items verified by scan: {dedup_stats['verified_by_scan']}\n")
    report.append(f"- Name mismatches fixed: {dedup_stats['name_mismatches_fixed']}\n")
    report.append(f"- **Items removed: {dedup_stats['items_removed']}**\n")
    report.append(f"- **Items kept: {dedup_stats['items_kept']}**\n\n")
    
    report.append("## Sample Removed Items (first 50)\n\n")
    report.append("| ItemID | Name | Reason |\n")
    report.append("|--------|------|--------|\n")
    
    for item in removed_items[:50]:
        report.append(f"| {item['itemID']} | {item.get('name', 'N/A')} | {item['reason']} |\n")
    
    if len(removed_items) > 50:
        report.append(f"\n*...and {len(removed_items) - 50} more*\n")
    
    return ''.join(report)

def main():
    print("Parsing WRC_DevTools scan results...")
    scanned_items = parse_lua_savedvars(SCAN_RESULTS)
    print(f"✓ Parsed {len(scanned_items)} scanned items")
    
    print("\nLoading worldforged items...")
    items = load_worldforged_items()
    print(f"✓ Loaded {len(items)} worldforged items")
    
    print("\nLoading duplicates analysis...")
    duplicates = load_duplicates_analysis()
    print(f"✓ Loaded duplicates analysis")
    
    print("\nDeduplicating items...")
    cleaned_items, removed_items, stats = deduplicate_items(items, scanned_items, duplicates)
    
    print("\n" + "="*60)
    print("DEDUPLICATION RESULTS")
    print("="*60)
    print(f"Input items:          {stats['total_input']:,}")
    print(f"Items with IDs:       {stats['items_with_ids']:,}")
    print(f"Items without IDs:    {stats['items_without_ids']:,} (kept all)")
    print(f"Unique itemIDs:       {stats['unique_itemids']:,}")
    print(f"ItemIDs with dupes:   {stats['itemids_with_duplicates']:,}")
    print(f"Verified by scan:     {stats['verified_by_scan']:,}")
    print(f"Names fixed:          {stats['name_mismatches_fixed']:,}")
    print(f"Items removed:        {stats['items_removed']:,}")
    print(f"Items kept:           {stats['items_kept']:,}")
    print("="*60)
    
    # Calculate itemID coverage
    items_with_ids = sum(1 for item in cleaned_items if (item.get('itemIds') or item.get('itemID')))
    coverage = (items_with_ids / len(cleaned_items) * 100) if cleaned_items else 0
    print(f"\nItemID coverage: {items_with_ids}/{len(cleaned_items)} ({coverage:.1f}%)")
    
    # Save cleaned dataset
    output_data = {
        'metadata': {
            'total_items': len(cleaned_items),
            'items_with_itemid': items_with_ids,
            'itemid_coverage_percent': round(coverage, 2),
            'verified_by_scan': stats['verified_by_scan'],
            'deduplication_stats': stats
        },
        'items': cleaned_items
    }
    
    OUTPUT_CLEANED.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_CLEANED, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    print(f"\n✓ Saved cleaned dataset: {OUTPUT_CLEANED}")
    
    # Generate report
    report = generate_report(scanned_items, stats, removed_items)
    OUTPUT_REPORT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_REPORT, 'w', encoding='utf-8') as f:
        f.write(report)
    print(f"✓ Saved report: {OUTPUT_REPORT}")
    
    # Save removed items for reference
    removed_path = Path("temp/removed_duplicates.json")
    with open(removed_path, 'w', encoding='utf-8') as f:
        json.dump(removed_items, f, indent=2, ensure_ascii=False)
    print(f"✓ Saved removed items: {removed_path}")

if __name__ == '__main__':
    main()
