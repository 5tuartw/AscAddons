#!/usr/bin/env python3
"""
Process approved removals from the suspicious items CSV.
"""

import json
import csv
from pathlib import Path

INPUT_DATA = Path("data/intermediate/worldforged_items_final_cleaned.json")
APPROVAL_CSV = Path("temp/suspicious_items_for_approval.csv")
OUTPUT_CLEANED = Path("data/intermediate/worldforged_items_approved.json")
OUTPUT_REMOVED = Path("temp/approved_removals.json")
OUTPUT_REPORT = Path("temp/approval_processing_report.md")

def load_data():
    """Load cleaned items."""
    with open(INPUT_DATA, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data['items'], data.get('metadata', {})

def load_approvals():
    """Load approval decisions from CSV."""
    approved_removals = []
    
    with open(APPROVAL_CSV, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row.get('approve_removal', '').strip().upper() == 'YES':
                approved_removals.append({
                    'name': row['name'],
                    'zone': row['zone'],
                    'coords': row['coords'],
                    'pattern': row['pattern'],
                    'itemID': row.get('itemID', '')
                })
    
    return approved_removals

def main():
    print("Loading cleaned data...")
    items, metadata = load_data()
    print(f"✓ Loaded {len(items):,} items")
    
    print("\nLoading approval decisions...")
    approved_removals = load_approvals()
    print(f"✓ Found {len(approved_removals):,} approved removals")
    
    if not approved_removals:
        print("\n⚠️  No items marked for removal (approve_removal = YES)")
        print("   If you want to remove items, edit the CSV and mark them with 'YES'")
        return
    
    # Build removal index by name + coords
    removal_index = set()
    for removal in approved_removals:
        # Extract coords from format "(x, y)"
        coords = removal['coords'].strip()
        key = f"{removal['name']}|{removal['zone']}|{coords}"
        removal_index.add(key)
    
    # Filter items
    kept_items = []
    removed_items = []
    
    for item in items:
        name = item.get('name', '')
        zone = item.get('zone', '')
        x = item.get('x', 0)
        y = item.get('y', 0)
        coords = f"({x:.3f}, {y:.3f})"
        
        key = f"{name}|{zone}|{coords}"
        
        if key in removal_index:
            removed_items.append(item)
        else:
            kept_items.append(item)
    
    print(f"\nResults:")
    print(f"  Input items:     {len(items):,}")
    print(f"  Items removed:   {len(removed_items):,}")
    print(f"  Items kept:      {len(kept_items):,}")
    
    # Calculate new coverage
    items_with_ids = sum(1 for item in kept_items if (item.get('itemIds') or item.get('itemID')))
    coverage = (items_with_ids / len(kept_items) * 100) if kept_items else 0
    
    # Update metadata
    metadata.update({
        'total_items': len(kept_items),
        'items_with_itemid': items_with_ids,
        'itemid_coverage_percent': round(coverage, 2),
        'items_removed_manual_approval': len(removed_items),
        'approval_date': '2025-11-01'
    })
    
    # Save cleaned data
    output_data = {
        'metadata': metadata,
        'items': kept_items
    }
    
    OUTPUT_CLEANED.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_CLEANED, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    print(f"\n✓ Saved cleaned data: {OUTPUT_CLEANED}")
    
    # Save removed items with reasons
    removed_with_reasons = []
    for item in removed_items:
        name = item.get('name', '')
        zone = item.get('zone', '')
        x = item.get('x', 0)
        y = item.get('y', 0)
        coords = f"({x:.3f}, {y:.3f})"
        
        # Find the reason from approvals
        reason = None
        for removal in approved_removals:
            if removal['name'] == name and removal['zone'] == zone and removal['coords'] == coords:
                reason = removal['pattern']
                break
        
        removed_with_reasons.append({
            'name': name,
            'zone': zone,
            'coords': coords,
            'itemID': item.get('itemID') or (item.get('itemIds', [None])[0] if item.get('itemIds') else None),
            'reason': reason or 'Manual approval'
        })
    
    with open(OUTPUT_REMOVED, 'w', encoding='utf-8') as f:
        json.dump(removed_with_reasons, f, indent=2, ensure_ascii=False)
    print(f"✓ Saved removed items: {OUTPUT_REMOVED}")
    
    # Generate report
    report = []
    report.append("# Manual Approval Processing Report\n\n")
    report.append(f"**Date**: 2025-11-01\n\n")
    
    report.append("## Summary\n")
    report.append(f"- Input items: {len(items):,}\n")
    report.append(f"- Approved removals: {len(approved_removals):,}\n")
    report.append(f"- Items removed: {len(removed_items):,}\n")
    report.append(f"- Items kept: {len(kept_items):,}\n")
    report.append(f"- ItemID coverage: {items_with_ids}/{len(kept_items)} ({coverage:.1f}%)\n\n")
    
    # Group by pattern
    from collections import defaultdict
    pattern_groups = defaultdict(list)
    for item in removed_with_reasons:
        pattern_groups[item['reason']].append(item)
    
    report.append("## Removed Items by Pattern\n\n")
    for pattern, items_list in sorted(pattern_groups.items()):
        report.append(f"### {pattern} ({len(items_list)} items)\n\n")
        report.append("| Name | Zone | Coords | ItemID |\n")
        report.append("|------|------|--------|--------|\n")
        for item in items_list[:50]:
            report.append(f"| {item['name']} | {item['zone']} | {item['coords']} | {item['itemID'] or ''} |\n")
        if len(items_list) > 50:
            report.append(f"\n*...and {len(items_list) - 50} more*\n")
        report.append("\n")
    
    with open(OUTPUT_REPORT, 'w', encoding='utf-8') as f:
        f.write(''.join(report))
    print(f"✓ Saved report: {OUTPUT_REPORT}")
    
    print(f"\n✅ Final dataset: {len(kept_items):,} items ({coverage:.1f}% with itemIDs)")
    print(f"\n🎯 Target: ~1,800 items | Current: {len(kept_items):,}")
    remaining = len(kept_items) - 1800
    if remaining > 0:
        print(f"   Still {remaining:,} items above target")
    else:
        print(f"   ✓ Within target range!")

if __name__ == '__main__':
    main()
