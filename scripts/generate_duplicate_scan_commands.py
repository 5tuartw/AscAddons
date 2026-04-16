#!/usr/bin/env python3
"""
Generate WRC_DevTools scan commands for duplicate itemIDs.

Extracts unique itemIDs from duplicate analysis and creates scan commands
to verify item details in-game using /wrcdev scan <itemID>.

Usage:
    python scripts/generate_duplicate_scan_commands.py \\
        temp/duplicates_analysis.json \\
        temp/scan_duplicates.txt
"""

import sys
import json
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    
    analysis_file = sys.argv[1]
    output_file = sys.argv[2]
    
    print(f"Loading {analysis_file}...")
    with open(analysis_file, 'r', encoding='utf-8') as f:
        analysis = json.load(f)
    
    # Collect all itemIDs that need verification
    itemids_to_scan = set()
    scan_details = {}
    
    # 1. Exact itemID duplicates - these are the most critical to verify
    print("\nExtracting itemIDs from exact duplicates...")
    for dup_group in analysis['exact_itemid_duplicates']:
        item_id = int(dup_group['itemId'])
        itemids_to_scan.add(item_id)
        
        # Store the names associated with this itemID for context
        names = [item['name'] for item in dup_group['items'] if item.get('name')]
        zones = [item['zone'] for item in dup_group['items'] if item.get('zone')]
        
        scan_details[item_id] = {
            'count': dup_group['count'],
            'names': names,
            'zones': zones,
            'reason': 'exact_itemid_duplicate'
        }
    
    print(f"  • Found {len(itemids_to_scan)} unique itemIDs in exact duplicates")
    
    # 2. Potential matches - items without IDs that might match these
    print("\nExtracting itemIDs from potential matches...")
    potential_count = 0
    for match in analysis['potential_matches']:
        for candidate in match['candidates']:
            item_id = candidate['item_with_id'].get('itemId')
            if item_id:
                item_id = int(item_id)
                if item_id not in itemids_to_scan:
                    itemids_to_scan.add(item_id)
                    potential_count += 1
                
                scan_details[item_id] = {
                    'count': 1,
                    'names': [candidate['item_with_id'].get('name')],
                    'zones': [candidate['item_with_id'].get('zone')],
                    'reason': 'potential_match',
                    'similarity': candidate.get('similarity')
                }
    
    print(f"  • Found {potential_count} additional itemIDs from potential matches")
    
    # Sort itemIDs
    sorted_itemids = sorted(itemids_to_scan)
    
    # Generate scan commands
    print(f"\nGenerating scan commands for {len(sorted_itemids)} itemIDs...")
    
    commands = []
    commands.append("-- WRC_DevTools Scan Commands for Duplicate Analysis")
    commands.append("-- Generated from duplicates_analysis.json")
    commands.append(f"-- Total itemIDs to scan: {len(sorted_itemids)}")
    commands.append("--")
    commands.append("-- Copy and paste these commands into WoW chat")
    commands.append("-- Or use /wrcdev scanlist with the itemIDs below")
    commands.append("")
    
    # Group by reason
    exact_dups = [iid for iid in sorted_itemids if scan_details[iid]['reason'] == 'exact_itemid_duplicate']
    potentials = [iid for iid in sorted_itemids if scan_details[iid]['reason'] == 'potential_match']
    
    # Exact duplicates section
    commands.append("-- ======================================")
    commands.append(f"-- EXACT ITEMID DUPLICATES ({len(exact_dups)} items)")
    commands.append("-- These itemIDs appear multiple times with different names")
    commands.append("-- Scan to verify which name is correct")
    commands.append("-- ======================================")
    commands.append("")
    
    for item_id in exact_dups:
        details = scan_details[item_id]
        commands.append(f"-- ItemID {item_id}: appears {details['count']} times")
        commands.append(f"--   Names: {', '.join(details['names'][:3])}")
        if len(details['names']) > 3:
            commands.append(f"--          ... and {len(details['names']) - 3} more")
        commands.append(f"/wrcdev scan {item_id}")
        commands.append("")
    
    # Potential matches section
    if potentials:
        commands.append("")
        commands.append("-- ======================================")
        commands.append(f"-- POTENTIAL MATCHES ({len(potentials)} items)")
        commands.append("-- These have itemIDs but might match placeholders without IDs")
        commands.append("-- ======================================")
        commands.append("")
        
        for item_id in potentials:
            details = scan_details[item_id]
            commands.append(f"-- ItemID {item_id}: {details['names'][0] if details['names'] else 'Unknown'}")
            commands.append(f"/wrcdev scan {item_id}")
            commands.append("")
    
    # Also generate a scanlist version
    commands.append("")
    commands.append("-- ======================================")
    commands.append("-- BATCH SCAN USING SCANLIST")
    commands.append("-- ======================================")
    commands.append("-- Use this command to scan all at once:")
    commands.append("-- /wrcdev scanlist " + ",".join(map(str, sorted_itemids[:50])))
    
    if len(sorted_itemids) > 50:
        commands.append("")
        commands.append("-- Note: scanlist limited to first 50 items above")
        commands.append("-- Run subsequent batches:")
        for i in range(50, len(sorted_itemids), 50):
            batch = sorted_itemids[i:i+50]
            commands.append(f"-- /wrcdev scanlist " + ",".join(map(str, batch)))
    
    # Write output
    print(f"\nWriting {output_file}...")
    Path(output_file).parent.mkdir(parents=True, exist_ok=True)
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(commands))
    
    # Summary
    print("\n" + "="*70)
    print("SCAN COMMANDS GENERATED")
    print("="*70)
    print(f"Total itemIDs to scan:         {len(sorted_itemids)}")
    print(f"  • Exact duplicates:          {len(exact_dups)}")
    print(f"  • Potential matches:         {len(potentials)}")
    print("-"*70)
    print(f"Output file:                   {output_file}")
    print("")
    print("Next steps:")
    print("  1. Open the scan commands file")
    print("  2. Copy commands into WoW chat")
    print("  3. Or use /wrcdev scanlist for batch scanning")
    print("  4. Export results with /wrcdev export")
    print("  5. Use parse_scan_results.py to process the export")
    print("="*70)


if __name__ == '__main__':
    main()
