#!/usr/bin/env python3
"""
Decode LootCollector DBopt/db.lua compressed data.

IMPORTANT: This script decodes compressed LootCollector discovery data using the
exact encoding algorithm from LibDeflate.lua. Keep this script for future versions!

Encoding Chain (from LootCollector/Modules/ImportExport.lua):
═══════════════════════════════════════════════════════════════
1. AceSerializer:Serialize(data) → binary with ^S ^T ^N control chars
2. LibDeflate:CompressDeflate(binary, level=8) → deflate compression
3. LibDeflate:EncodeForPrint(compressed) → printable string using custom alphabet
4. Add "!LC1!" header prefix → final db.lua data field

Decoding Process:
═════════════════
1. Strip "!LC1!" header
2. Decode from EncodeForPrint format using custom 64-char alphabet:
   - a-z = 0-25, A-Z = 26-51, 0-9 = 52-61, ( = 62, ) = 63
   - Processes 4 chars → 3 bytes (6-bit encoding)
3. Decompress with zlib/Deflate (Python: zlib.decompress with -zlib.MAX_WBITS)
4. Parse AceSerializer format (^S=string, ^T=table start, ^N=number, ^t=table end)

LibDeflate Source: archive/addons/other-creators/LootCollector_git/libs/LibDeflate/LibDeflate.lua
- EncodeForPrint: lines 3311-3353
- DecodeForPrint: lines 3365-3410
- Alphabet tables: lines 3165-3230

Tested Versions:
- Oct 30, 2024: archive/addons/old-versions/LootCollector/DBopt/db.lua (271,417 bytes)
- Oct 31, 2024: archive/addons/other-creators/LootCollector_git/DBopt/db.lua (271,409 bytes)
- Both decode to identical 1,261,351 bytes (2078 discoveries)

Usage:
    python scripts/decode_lootcollector_db.py <input_db.lua> <output_decoded.txt>
    
Example:
    python scripts/decode_lootcollector_db.py \\
        archive/addons/other-creators/LootCollector_git/DBopt/db.lua \\
        data/intermediate/lootcollector_db_decoded.txt

Output:
    Binary AceSerializer format with discovery data (itemIDs, coords, zones, timestamps)
    Use parse_lootcollector.py to convert to JSON/CSV

Author: Reverse-engineered Nov 1, 2025 from LibDeflate.lua
"""

import sys
import re
import zlib
import base64
from pathlib import Path


def extract_encoded_data(lua_content):
    """Extract the encoded data string from db.lua file."""
    # Pattern: _G.LootCollector_OptionalDB_Data = { version = "...", data = "..." }
    # The data field contains the encoded string
    
    # First try to find the data field
    data_match = re.search(r'data\s*=\s*"([^"]+)"', lua_content, re.DOTALL)
    if data_match:
        return data_match.group(1)
    
    # Alternative: data might be split across lines with escapes
    data_match = re.search(r'data\s*=\s*"(.+?)"(?=\s*[,}])', lua_content, re.DOTALL)
    if data_match:
        return data_match.group(1)
    
    return None


def libdeflate_decode_for_print(encoded_str):
    """
    Decode LibDeflate:EncodeForPrint format.
    
    LibDeflate uses a custom 64-character alphabet (NOT standard base64):
    - a-z (lowercase) = values 0-25
    - A-Z (uppercase) = values 26-51  
    - 0-9 (digits)    = values 52-61
    - (  (left paren) = value 62
    - )  (right paren)= value 63
    
    Algorithm:
    1. Strip leading/trailing whitespace and control characters
    2. Process 4 input characters at a time:
       - Each char maps to 6-bit value (0-63)
       - Combine 4×6=24 bits
       - Extract 3 bytes (8 bits each)
    3. Handle remaining 1-3 chars with bit accumulator
    
    Source: LibDeflate.lua lines 3365-3410
    """
    # Clean control characters and spaces from start/end
    encoded_str = encoded_str.strip()
    
    # Build the decode lookup table (character -> 6-bit value)
    decode_map = {}
    # a-z = 0-25
    for i in range(26):
        decode_map[chr(ord('a') + i)] = i
    # A-Z = 26-51
    for i in range(26):
        decode_map[chr(ord('A') + i)] = 26 + i
    # 0-9 = 52-61
    for i in range(10):
        decode_map[chr(ord('0') + i)] = 52 + i
    # ( = 62, ) = 63
    decode_map['('] = 62
    decode_map[')'] = 63
    
    strlen = len(encoded_str)
    if strlen == 1:
        return None
    
    result = bytearray()
    i = 0
    
    # Process 4 characters at a time (most of the string)
    while i <= strlen - 4:
        try:
            x1 = decode_map[encoded_str[i]]
            x2 = decode_map[encoded_str[i+1]]
            x3 = decode_map[encoded_str[i+2]]
            x4 = decode_map[encoded_str[i+3]]
        except KeyError:
            print(f"Invalid character at position {i}: '{encoded_str[i]}'")
            return None
        
        i += 4
        # Combine 4 6-bit values into 24 bits, then extract 3 bytes
        cache = x1 + x2 * 64 + x3 * 4096 + x4 * 262144
        b1 = cache % 256
        cache = (cache - b1) // 256
        b2 = cache % 256
        b3 = (cache - b2) // 256
        result.extend([b1, b2, b3])
    
    # Handle remaining characters (padding)
    cache = 0
    cache_bitlen = 0
    while i < strlen:
        try:
            x = decode_map[encoded_str[i]]
        except KeyError:
            print(f"Invalid character at position {i}: '{encoded_str[i]}'")
            return None
        cache = cache + x * (2 ** cache_bitlen)
        cache_bitlen += 6
        i += 1
    
    # Extract remaining bytes
    while cache_bitlen >= 8:
        byte = cache % 256
        result.append(byte)
        cache = (cache - byte) // 256
        cache_bitlen -= 8
    
    return bytes(result)


def decompress_deflate(compressed_data):
    """
    Decompress using Deflate algorithm (LibDeflate:DecompressDeflate).
    
    LibDeflate uses standard Deflate compression (RFC 1951).
    Python's zlib.decompress with -zlib.MAX_WBITS for raw deflate (no headers).
    
    LootCollector uses compression level 8 for exports.
    """
    try:
        # Try raw deflate (no headers)
        decompressed = zlib.decompress(compressed_data, -zlib.MAX_WBITS)
        return decompressed
    except zlib.error as e:
        print(f"Raw deflate failed: {e}, trying with zlib headers...")
    
    try:
        # Try with zlib headers
        decompressed = zlib.decompress(compressed_data)
        return decompressed
    except zlib.error as e:
        print(f"Zlib decompress failed: {e}")
        return None


def parse_aceserializer(data):
    """
    Parse AceSerializer-3.0 format to count discoveries.
    
    AceSerializer control characters:
    - ^S (0x13, chr 19) = string follows (length-prefixed)
    - ^T (0x14, chr 20) = table start (dictionary/array)
    - ^N (0x0E, chr 14) = number follows (encoded as string)
    - ^t (0x74, chr 116)= table end
    - ^Z (0x1A, chr 26) = nil value
    - ^b (0x62, chr 98) = boolean true
    - ^B (0x42, chr 66) = boolean false
    
    LootCollector data structure (simplified):
    {
        ["character@realm"] = {
            [itemID] = { x=coord, y=coord, zone=id, quality=num, timestamp=num }
        }
    }
    
    This basic parser just outputs the raw decoded data. For full parsing,
    use a proper AceSerializer parser that handles nested tables, string lengths, etc.
    See consolidate_all_sources.py for working parser implementation.
    """
    # Convert bytes to string if needed
    if isinstance(data, bytes):
        try:
            return data.decode('utf-8', errors='replace')
        except:
            return data.decode('latin-1', errors='replace')
    
    return data


def decode_lootcollector_db(input_file, output_file):
    """Main decoder function."""
    print(f"Reading {input_file}...")
    
    with open(input_file, 'rb') as f:
        lua_content = f.read().decode('utf-8', errors='ignore')
    
    print("Extracting encoded data...")
    encoded_data = extract_encoded_data(lua_content)
    
    if not encoded_data:
        print("ERROR: Could not find encoded data in db.lua file")
        print("\nSearching for data patterns in file...")
        
        # Debug: show what we found
        if 'LootCollector_OptionalDB_Data' in lua_content:
            print("Found LootCollector_OptionalDB_Data table")
            # Show first 500 chars around it
            idx = lua_content.index('LootCollector_OptionalDB_Data')
            print(lua_content[idx:idx+500])
        
        return False
    
    print(f"Found encoded data (length: {len(encoded_data)} chars)")
    
    # Check for header
    header = None
    data_body = encoded_data
    if encoded_data.startswith('!LC1!'):
        header = '!LC1!'
        data_body = encoded_data[5:]
        print(f"Stripped header: {header}")
    
    print("Decoding from EncodeForPrint format...")
    decoded_bytes = libdeflate_decode_for_print(data_body)
    
    if not decoded_bytes:
        print("ERROR: Failed to decode from EncodeForPrint format")
        print(f"First 100 chars of encoded data: {data_body[:100]}")
        return False
    
    print(f"Decoded {len(decoded_bytes)} bytes")
    
    print("Decompressing with Deflate...")
    decompressed_data = decompress_deflate(decoded_bytes)
    
    if not decompressed_data:
        print("ERROR: Failed to decompress data")
        return False
    
    print(f"Decompressed to {len(decompressed_data)} bytes")
    
    print("Parsing AceSerializer format...")
    parsed_data = parse_aceserializer(decompressed_data)
    
    print(f"Writing output to {output_file}...")
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(parsed_data)
    
    print(f"✓ Successfully decoded! Output: {output_file}")
    
    # Show some stats
    if '^S' in parsed_data:
        discovery_count = parsed_data.count('^Sguid^S')
        print(f"Found approximately {discovery_count} discoveries")
    
    return True


def main():
    if len(sys.argv) < 3:
        print("Usage: python scripts/decode_lootcollector_db.py <input_db.lua> <output_decoded.txt>")
        print("\nExample:")
        print("  python scripts/decode_lootcollector_db.py \\")
        print("    archive/addons/other-creators/LootCollector_git/DBopt/db.lua \\")
        print("    data/intermediate/lootcollector_db_decoded_oct31.txt")
        sys.exit(1)
    
    input_file = Path(sys.argv[1])
    output_file = Path(sys.argv[2])
    
    if not input_file.exists():
        print(f"ERROR: Input file not found: {input_file}")
        sys.exit(1)
    
    # Create output directory if needed
    output_file.parent.mkdir(parents=True, exist_ok=True)
    
    success = decode_lootcollector_db(input_file, output_file)
    
    if not success:
        print("\n✗ Decoding failed")
        sys.exit(1)
    
    print("\n✓ Done!")


if __name__ == '__main__':
    main()
