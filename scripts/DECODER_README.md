# LootCollector db.lua Decoder

## Quick Reference

**Script**: `scripts/decode_lootcollector_db.py`  
**Purpose**: Decode compressed LootCollector discovery data from `DBopt/db.lua`  
**Status**: ✅ Working (tested Nov 1, 2025)

## Usage

```bash
python3 scripts/decode_lootcollector_db.py \
    archive/addons/other-creators/LootCollector_git/DBopt/db.lua \
    data/intermediate/lootcollector_db_decoded.txt
```

## Output

- **Format**: Binary AceSerializer format (not human-readable)
- **Size**: ~1.3 MB (1,261,351 bytes)
- **Content**: ~2,078 item discoveries with itemIDs, coordinates, zones, quality, timestamps
- **Further Processing**: Use `parse_lootcollector.py` or similar to extract to JSON/CSV

## How It Works

### 1. Encoding Chain (LootCollector)

```
Raw Data 
  ↓ AceSerializer:Serialize
Binary with ^S ^T ^N markers
  ↓ LibDeflate:CompressDeflate (level 8)
Compressed binary
  ↓ LibDeflate:EncodeForPrint
Printable string (a-zA-Z0-9())
  ↓ Add header
"!LC1!..." stored in db.lua
```

### 2. Decoding Steps

```python
# Step 1: Strip header
data = strip_header(lua_content)  # Remove "!LC1!"

# Step 2: Decode from EncodeForPrint
binary = libdeflate_decode_for_print(data)  # Custom 64-char alphabet

# Step 3: Decompress
raw = zlib.decompress(binary, -zlib.MAX_WBITS)  # Raw deflate

# Step 4: Output AceSerializer format
write_file(raw)  # Contains ^S ^T ^N markers
```

### 3. LibDeflate Custom Alphabet

**NOT standard base64!** Uses 64 characters:

| Range | Characters | Values |
|-------|------------|--------|
| a-z   | lowercase  | 0-25   |
| A-Z   | uppercase  | 26-51  |
| 0-9   | digits     | 52-61  |
| (     | left paren | 62     |
| )     | right paren| 63     |

**Algorithm**: Processes 4 input chars → 3 output bytes (6-bit encoding)

## Source Code References

### LibDeflate.lua
Location: `archive/addons/other-creators/LootCollector_git/libs/LibDeflate/LibDeflate.lua`

- **Alphabet tables**: lines 3165-3230
- **EncodeForPrint**: lines 3311-3353
- **DecodeForPrint**: lines 3365-3410

### ImportExport.lua
Location: `archive/addons/other-creators/LootCollector_git/Modules/ImportExport.lua`

- **serialize()**: Shows encoding chain
- **deserialize()**: Shows decoding chain

## Tested Versions

| Version | File | Size | MD5 | Decoded Size | Discoveries |
|---------|------|------|-----|--------------|-------------|
| Oct 30, 2024 | `archive/addons/old-versions/LootCollector/DBopt/db.lua` | 271,417 bytes | `031bbef4...` | 1,261,351 bytes | ~2,078 |
| Oct 31, 2024 | `archive/addons/other-creators/LootCollector_git/DBopt/db.lua` | 271,409 bytes | `b0357ce7...` | 1,261,351 bytes | ~2,078 |

**Note**: Both versions decode to **identical content**. The 8-byte size difference was Lua formatting only.

## Troubleshooting

### "Invalid character at position X"
- Check if encoding alphabet changed in newer LibDeflate versions
- Verify source file is the actual `db.lua` with `!LC1!` header
- Check for file corruption during copy/paste

### "Deflate decompression failed"
- EncodeForPrint decode may have failed (returns `None`)
- Check decoded binary length (should be ~200KB for typical dataset)
- Try both raw deflate and zlib headers (script tries both)

### "Wrong number of discoveries"
- AceSerializer parsing is basic (counts `^T` markers)
- For accurate counts, parse full AceSerializer format
- Compare with `lootcollector_readable.txt` (human-formatted version)

## Future Updates

If LootCollector updates break the decoder:

1. **Check LibDeflate version**: Compare `libs/LibDeflate/LibDeflate.lua`
   - Look for changes to `EncodeForPrint` alphabet
   - Check if compression level changed

2. **Check header format**: May change from `!LC1!` to `!LC2!` etc.
   - Update `strip_header()` function

3. **Check AceSerializer version**: AceSerializer-3.0 → 4.0?
   - Control character mappings may change
   - String length encoding may differ

4. **Test with known data**: Keep Oct 30/31 versions as reference
   - Decoder should always work on archived versions
   - Compare new output with `lootcollector_readable.txt`

## Related Files

- `scripts/parse_lootcollector.py` - Parse decoded AceSerializer data
- `consolidate_all_sources.py` - Merge LootCollector with other sources
- `data/intermediate/lootcollector_readable.txt` - Human-formatted reference (Oct 31)
- `DATA_SOURCES_INVENTORY.md` - Complete file catalog

---

**Preserved**: Nov 1, 2025  
**Author**: Reverse-engineered from LibDeflate.lua and ImportExport.lua
