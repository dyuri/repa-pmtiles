# Hiking Route Extraction from OSM Data - Investigation Report

## Problem Statement

Hiking routes were missing from the generated PMTiles despite being present in the OpenStreetMap data. The trails layer showed physical paths (ways) but not the logical hiking routes (relations) with their colors, symbols, and names.

## Investigation Process

### Initial Symptoms

1. Map showed physical paths but no colored/marked hiking routes
2. Route attributes (OSMC symbols, colors, names) were not appearing
3. Generated tiles contained trail geometries but missing route-level information

### Debugging Approach

Created a minimal debug configuration to isolate the problem:

**Files Created:**
- `config/config-routes-only.json` - Minimal config with only hiking_routes layer
- `config/process-routes-only.lua` - Simplified Lua to process ONLY route relations
- `scripts/generate-routes-debug.sh` - Debug script with verbose output

**Key Debug Output:**
```
DEBUG: Found hiking route relation - E3 európai hosszútávú turistaút
DEBUG: Found hiking route relation - Kékes (K▲)
DEBUG: Found hiking route relation - Mária-út
...
Generated points: 0, lines: 0, polygons: 0  ← THE PROBLEM
```

**Analysis:** Relations were being **found** and **accepted** by `relation_scan_function()` but **not outputted** as geometries.

## Root Cause

### The Incorrect Code

In `config/process-hiking.lua`, we were using:

```lua
function relation_postscan_function()
    -- ... get tags ...
    Layer("hiking_routes", false)
    -- ... set attributes ...
end
```

### Why This Failed

According to [Tilemaker RELATIONS.md documentation](https://github.com/systemed/tilemaker/blob/master/docs/RELATIONS.md):

1. **`relation_scan_function()`** - Called first to **accept** relations you want to process
2. **`relation_function()`** - Called to **output** relation geometries to layers
3. **`relation_postscan_function()`** - Only for handling nested relations and tag propagation

**The Problem:** `relation_postscan_function()` does NOT output geometries. It's designed for:
- Handling parent-child relation hierarchies
- Propagating tags from relations to member ways
- Post-processing after all relations are scanned

### Technical Details

Tilemaker constructs relation geometries by:
1. Storing member ways in memory (waystore) during OSM file processing
2. In `relation_function()`, assembling member ways into multilinestring geometries
3. Outputting these geometries to tile layers

When `Layer()` is called in `relation_postscan_function()`:
- Member way geometries are no longer available
- Tilemaker cannot construct the multilinestring
- No output is generated ("Generated points: 0, lines: 0, polygons: 0")

## The Solution

### Corrected Code

Replace `relation_postscan_function()` with `relation_function()`:

```lua
-- Scan relations to identify hiking routes (KEEP THIS)
function relation_scan_function()
    local type = Find("type")
    local route = Find("route")
    if type == "route" and (route == "hiking" or route == "foot") then
        Accept()
    end
end

-- Output relation geometries (FIX: Changed from relation_postscan_function)
function relation_function()
    local osmc = Find("osmc:symbol")
    local color = Find("color")
    local ref = Find("ref")
    local name = Find("name")
    local route = Find("route")
    local network = Find("network")

    -- Output the relation geometry as a multilinestring
    Layer("hiking_routes", false)  -- false = linestring (not area)

    -- Basic attributes
    Attribute("class", "hiking_route")
    Attribute("route_type", route)

    if name ~= "" then Attribute("name", name) end
    if ref ~= "" then Attribute("ref", ref) end
    if network ~= "" then Attribute("network", network) end
    if osmc ~= "" then Attribute("osmc_symbol", osmc) end

    -- Parse OSMC symbol for color and shape
    local t_color, t_symbol = parse_osmc(osmc)

    if not t_color and color ~= "" then
        t_color = color
    end

    if t_color then
        Attribute("trail_color", t_color)
    end

    if t_symbol then
        Attribute("trail_symbol", t_symbol)
    end

    MinZoom(6)
end
```

### Results After Fix

```
DEBUG: Found hiking route relation - E3 európai hosszútávú turistaút
DEBUG: Processing relation: E3 európai hosszútávú turistaút
...
Generated points: 0, lines: 12080, polygons: 0  ✓ SUCCESS
```

**Output:**
- **12,080 hiking route lines** extracted
- **20,342 tiles** generated (zoom 6-14)
- **45MB PMTiles** file created (`hungary-routes-debug.pmtiles`)
- All attributes present: name, ref, osmc_symbol, trail_color, trail_symbol, network

## Tilemaker Relation Processing Functions

### Function Reference

| Function | Purpose | When Called | Can Output Geometry |
|----------|---------|-------------|---------------------|
| `relation_scan_function()` | Accept relations for processing | First pass | No |
| `relation_function()` | Output relation geometries | During processing | **Yes** ✓ |
| `relation_postscan_function()` | Handle nested relations, tag propagation | After all relations scanned | No |

### Best Practices

1. **Always use `relation_function()`** to output relation geometries
2. **Use `relation_scan_function()`** to filter which relations to process (saves memory)
3. **Only use `relation_postscan_function()`** for:
   - Parent-child relation hierarchies (e.g., route master relations)
   - Propagating relation tags to member ways
   - Complex multi-pass processing

### Common Pitfall

```lua
-- ❌ WRONG - This outputs nothing
function relation_postscan_function()
    Layer("my_layer", false)
    -- ... attributes ...
end

// ✓ CORRECT - This outputs geometry
function relation_function()
    Layer("my_layer", false)
    // ... attributes ...
end
```

## Verification Steps

### 1. Inspect MBTiles Database

```bash
sqlite3 tiles/hungary-routes-debug.mbtiles

# Check metadata
SELECT * FROM metadata;

# Count tiles
SELECT COUNT(*) FROM tiles;

# Check layer fields
SELECT value FROM metadata WHERE name='json';
```

### 2. Inspect PMTiles

```bash
podman run --rm -v "$PWD/tiles:/tiles" \
  ghcr.io/protomaps/go-pmtiles:latest \
  show /tiles/hungary-routes-debug.pmtiles
```

### 3. Visual Inspection

Add to your map viewer (`www/index.html`):

```javascript
map.addSource('debug-routes', {
    type: 'vector',
    url: 'pmtiles://http://localhost:8080/tiles/hungary-routes-debug.pmtiles'
});

map.addLayer({
    id: 'hiking-routes-debug',
    type: 'line',
    source: 'debug-routes',
    'source-layer': 'hiking_routes',
    paint: {
        'line-color': [
            'match',
            ['get', 'trail_color'],
            'red', '#FF0000',
            'blue', '#0000FF',
            'yellow', '#FFFF00',
            'green', '#00FF00',
            '#888888'  // default
        ],
        'line-width': 3
    }
});
```

## Files Modified/Created

### Created (Debug)
- `config/config-routes-only.json` - Minimal layer configuration
- `config/process-routes-only.lua` - Debug Lua processor
- `scripts/generate-routes-debug.sh` - Debug generation script

### To Fix (Production)
- `config/process-hiking.lua` - Change `relation_postscan_function()` to `relation_function()`

## Next Steps

1. **Apply fix to main config** - Update `config/process-hiking.lua`
2. **Regenerate full tiles** - Run `./scripts/generate-tiles.sh`
3. **Update map style** - Add hiking route visualization layers
4. **Test thoroughly** - Verify routes appear with correct colors/symbols

## References

- [Tilemaker RELATIONS.md](https://github.com/systemed/tilemaker/blob/master/docs/RELATIONS.md)
- [Tilemaker CONFIGURATION.md](https://github.com/systemed/tilemaker/blob/master/docs/CONFIGURATION.md)
- [OpenStreetMap Hiking Routes](https://wiki.openstreetmap.org/wiki/Hiking)
- [OSMC Symbol Format](https://wiki.openstreetmap.org/wiki/Key:osmc:symbol)

## Key Takeaways

1. ✅ **Hiking routes ARE in the OSM data** (thousands found in Hungary)
2. ✅ **The issue was Lua function usage**, not data quality
3. ✅ **Tilemaker requires specific functions for geometry output**
4. ✅ **relation_function() is the correct function** for outputting relation geometries
5. ✅ **Debug configurations help isolate problems** quickly

---

**Investigation Date:** January 20, 2026
**Status:** ✅ Resolved
**Impact:** Critical - Enables hiking route visualization with proper colors, symbols, and names
