# Garmin Map Generation Guide

Generate installable Garmin hiking maps from the same OpenStreetMap data used for PMTiles.

## Overview

This project can generate two types of maps from the same OSM data:
- **PMTiles** - For web browsers (MapLibre GL JS)
- **Garmin IMG** - For Garmin GPS devices and BaseCamp

Both share the same data source and similar visual styles for a consistent experience across platforms.

## Quick Start

### Prerequisites

- Docker or Podman installed
- At least 8GB RAM recommended
- 20GB free disk space
- Hungarian OSM data downloaded (`make download`)

### Generate Garmin Map

```bash
# One-time: Build the Garmin tools container (downloads mkgmap & splitter)
make garmin-image

# Generate Garmin map (uses same OSM data as PMTiles)
make garmin

# Install to connected Garmin device
./scripts/garmin/install-to-device.sh
```

### Generate Both Map Types

```bash
# Download OSM data once, generate both formats
make all-maps
```

## What You Get

### Output Files

After running `make garmin`, you'll find:

```
garmin-output/
└── gmapsupp.img      # 400-600MB - Ready to install on device
```

### Map Features

The Garmin map includes:

**Trails:**
- Hiking paths and footways
- Track grades (grade1-5)
- SAC scale difficulty ratings
- Trail surface information

**Points of Interest:**
- Mountain peaks with elevation
- Viewpoints
- Alpine huts and shelters
- Drinking water sources
- Springs
- Cave entrances
- Saddles

**Base Layers:**
- Roads (all types)
- Waterways and water bodies
- Forests and landuse areas
- Buildings (at high zoom)
- Administrative boundaries
- Place labels (cities, towns, villages)

**Route Relations:**
- Hiking route names and references
- OSMC symbol information (colored trail markers)
- Network type (local/regional/national)
- Color-coded trails with distinct patterns when overlapping

## Colored Hiking Trails

### How It Works

Unlike web maps (PMTiles) that can apply colors at runtime, Garmin maps use **compile-time styling** with TYP files to display colored hiking trails.

### Trail Color Detection

The map automatically extracts trail colors from OSMC symbols in OSM route relations:

**OSMC Format:** `waycolor:background:foreground:text:textcolor`

**Examples:**
- `red:white:red_bar` → Red trail
- `blue:white::K:blue` → Blue trail with "K" marker
- `yellow:white:yellow_circle` → Yellow trail

The `relations` file in the style detects these patterns and applies individual flags to way members:
- Red routes → `hiking_red=yes`
- Blue routes → `hiking_blue=yes`
- Yellow routes → `hiking_yellow=yes`
- And so on for green, orange, purple, white, black

### Multiple Routes on Same Way

When a hiking path is part of multiple colored routes (common in trail networks), our approach handles this correctly:

1. **Relations file** sets individual flags for each color (e.g., both `hiking_red=yes` AND `hiking_blue=yes`)
2. **Lines file** checks each flag separately with `continue` statements
3. Each matching rule renders the trail with a different type code
4. **TYP file** defines unique colors and line patterns for each type code

**Result:** Overlapping trails render with different patterns, making all routes visible.

### Trail Color Mapping

| Color | Type Code | Line Pattern | Day Color | Night Color |
|-------|-----------|--------------|-----------|-------------|
| Red | 0x2a | Solid thick | #E63946 | #A62639 |
| Blue | 0x2b | Dashed | #2A9D8F | #1D6B61 |
| Yellow | 0x2c | Dotted | #F4D03F | #B8992E |
| Green | 0x2d | Double-border | #52B788 | #3A8561 |
| Orange | 0x2e | Long-dash | #F77F00 | #B45F00 |
| Purple | 0x2f | Dash-dot | #9D4EDD | #7239A3 |
| White | 0x30 | Thick border | #FFFFFF | #CCCCCC |
| Black | 0x31 | White border | #2B2D42 | #000000 |

**Different line patterns** (solid, dashed, dotted, etc.) make overlapping routes visually distinguishable on device screens, compensating for the lack of spatial offsets like in web maps.

### TYP File Compilation

The map includes a custom TYP file (`config/garmin/hiking.typ`) that defines these colors and patterns:

**Automatic Compilation:**
```bash
make garmin  # Automatically compiles hiking.txt → hiking.typ
```

**Manual Compilation:**
```bash
./scripts/garmin/compile-typ.sh
```

The TYP file is automatically included in the map generation process.

### Customizing Trail Colors

To modify trail colors or patterns:

1. Edit `config/garmin/hiking.txt`
2. Change the `DayCustomColor` and `NightCustomColor` values
3. Modify the `Xpm` pattern (line pattern definition)
4. Recompile: `./scripts/garmin/compile-typ.sh`
5. Regenerate map: `make garmin`

**Example - Making Red Trail Wider:**
```
[_line]
Type=0x2a
LineWidth=4        # Increase from 3 to 4
BorderWidth=2      # Increase from 1 to 2
DayCustomColor=#E63946
```

### Limitations

Unlike the PMTiles version where trails can have spatial offsets to appear side-by-side:
- Garmin trails **overlay** rather than offset spatially
- Different **patterns** (not positions) distinguish overlapping trails
- This is a fundamental limitation of the Garmin IMG format
- On small device screens, 2-3 overlapping trails are still clearly distinguishable
- More than 3 overlapping trails may become harder to distinguish

## Installation

### Method 1: Automatic Installation (Recommended)

```bash
# Connect your Garmin device via USB
./scripts/garmin/install-to-device.sh
```

The script will:
1. Detect your connected Garmin device
2. Backup existing map (if present)
3. Copy the new map to device
4. Prompt you to safely eject

### Method 2: Manual Installation

1. Connect your Garmin device to computer via USB
2. Locate the device (usually mounted as `/media/GARMIN` or similar)
3. Copy the map file:
   ```bash
   cp garmin-output/gmapsupp.img /path/to/device/Garmin/gmapsupp.img
   ```
4. Safely eject the device

### Enabling the Map on Device

After installation:
1. Turn on your Garmin device
2. Go to: **Setup → Map → Map Info**
3. Select "Hungarian Hiking"
4. Enable the map

## Device Compatibility

### Tested Devices
- eTrex series (20x, 30x, 32x)
- Oregon series (600, 700, 750)
- Montana series (600, 700)
- GPSMAP 64/65/66 series

### Requirements
- Device with at least 1GB total memory
- ~500MB free space for the map
- Color screen recommended (for trail colors)

### Known Limitations
- Older devices (eTrex 10, Dakota series): May be slow or run out of memory
- Monochrome devices: Trail colors will appear as grayscale

## Customization

### Modifying the Style

Edit the style files in `config/garmin/style/`:

**`lines`** - Trail and road rendering:
```
highway=path [0x16 resolution 24]  # Hiking trails
```

**`points`** - POI symbols and labels:
```
natural=peak [0x6616 resolution 21]  # Mountain peaks
```

**`polygons`** - Area rendering:
```
natural=wood [0x50 resolution 20]  # Forests
```

After editing, regenerate:
```bash
make garmin
```

### Adjusting Detail Level

Edit `scripts/generate-garmin.sh`:

**Reduce file size** (faster builds, less detail):
```bash
--max-nodes=800000       # Default: 1200000
```

**Increase detail** (larger file, more features):
```bash
--max-nodes=1600000      # Default: 1200000
```

### Disabling Routing

If you don't need device routing (smaller file):

Edit `scripts/generate-garmin.sh` and remove:
```bash
--route \
--add-pois-to-areas \
--link-pois-to-ways \
```

## Build Times

Typical build times on modern hardware:

| Step | Time | CPU Usage |
|------|------|-----------|
| Splitter | 5-10 min | Medium |
| mkgmap | 15-30 min | High |
| **Total** | **20-40 min** | Variable |

Factors affecting build time:
- CPU cores (mkgmap uses all available)
- Available memory (8GB+ recommended)
- SSD vs HDD storage

## Troubleshooting

### Out of Memory

**Error:** `java.lang.OutOfMemoryError`

**Solution:** Increase Java heap size in `docker/garmin/entrypoint.sh`:
```bash
JAVA_OPTS="${JAVA_OPTS:--Xmx10G}"  # Increase from 8G to 10G
```

Or reduce detail level (see Customization section).

### Map Not Appearing on Device

**Symptoms:** Device boots fine, but map doesn't appear in list

**Checks:**
1. Verify file is in correct location: `Garmin/gmapsupp.img`
2. Check file size (should be 400-600MB)
3. Ensure device has enough free space
4. Try renaming to `gmapsupp2.img` if you have other maps

### Map Loads Slowly on Device

**Cause:** Too much detail for device to handle

**Solutions:**
1. Reduce max-nodes in splitter
2. Disable buildings layer (edit `config/garmin/style/polygons`)
3. Increase minimum zoom levels in style files

### Device Freezes or Crashes

**Cause:** Device running out of memory

**Solutions:**
1. Remove other maps from device
2. Reduce map detail level
3. Consider using an older/smaller region extract
4. Update device firmware (if available)

### Build Fails with "No tiles generated"

**Cause:** OSM data not found or corrupted

**Solution:**
```bash
# Re-download OSM data
make download

# Rebuild
make garmin
```

### Trails Not Showing Correct Colors

**Cause:** TYP file not compiled or not included in map

**Solution:**
1. Check if TYP file exists:
   ```bash
   ls -l config/garmin/hiking.typ
   ```

2. If missing, compile it:
   ```bash
   ./scripts/garmin/compile-typ.sh
   ```

3. Regenerate map:
   ```bash
   make garmin
   ```

**Note on device rendering:**
- Night mode may adjust colors automatically
- Monochrome devices show patterns in grayscale
- Older devices have limited color palettes
- Different line patterns help distinguish trails even without color

### Multiple Trails Not Visible on Same Path

**Symptom:** Only one trail color visible where multiple routes overlap

**Cause:** TYP file patterns not rendering properly on device

**Solutions:**
1. Verify TYP file is included in map (should be automatic)
2. Try increasing line widths in `config/garmin/hiking.txt`
3. Check device supports custom TYP files (most modern devices do)
4. Some older firmware versions have TYP rendering bugs - update firmware if available

## Updating the Map

To regenerate with latest OSM data:

```bash
# Download latest data
make download

# Regenerate Garmin map
make garmin

# Re-install to device
./scripts/garmin/install-to-device.sh
```

## Comparison: PMTiles vs Garmin IMG

| Feature | PMTiles (Web) | Garmin IMG (Device) |
|---------|---------------|---------------------|
| **Platform** | Web browsers | GPS devices |
| **File Size** | 500-600MB | 400-600MB |
| **Build Time** | 30-60 min | 20-40 min |
| **Styling** | Runtime (JSON) | Compile-time |
| **Interactivity** | Full (clicks, popups) | Limited (device UI) |
| **Routing** | No | Yes (optional) |
| **Updates** | Replace file | Re-install |
| **Offline Use** | Requires server | Built-in |
| **Trail Colors** | Runtime (JSON style) | Compile-time (TYP file) |
| **Overlapping Trails** | Spatial offset | Pattern differentiation |
| **Custom Colors** | Easy (edit JSON) | Moderate (edit TYP) |

**Use PMTiles when:**
- Planning routes at home
- Sharing maps on website
- Need interactive features
- Want easy style updates

**Use Garmin IMG when:**
- Hiking with GPS device
- Need offline navigation
- Want device routing
- Prefer dedicated hardware

## Advanced Topics

### Customizing the TYP File

The map includes a pre-configured TYP file for colored hiking trails at `config/garmin/hiking.txt`.

**TYP File Structure:**

The TYP file is written in a text format and defines:
- Line colors (day and night modes)
- Line patterns (solid, dashed, dotted, etc.)
- Line widths and borders
- Labels and descriptions

**Editing the TYP File:**

Edit `config/garmin/hiking.txt` directly:

```
[_line]
Type=0x2a                    # Red hiking trail
LineWidth=3                  # Line thickness
BorderWidth=1                # Border thickness
DayCustomColor=#E63946       # Day mode color (hex)
NightCustomColor=#A62639     # Night mode color (hex)
Xpm="0 0 2 0"               # Pattern definition
"! c #E63946"               # Pattern color
"- c none"                  # Transparent
"!-!-"                      # Pattern: dash-space-dash-space
```

**Common Patterns:**
- Solid line: `"!!!!"` (all filled)
- Dashed line: `"!-!-"` (alternating)
- Dotted line: `"!-"` (short dash, space)
- Long dash: `"!!!-"` (longer filled sections)
- Dash-dot: `"!!-!-"` (long dash, short dash)

**After editing:**
```bash
./scripts/garmin/compile-typ.sh  # Compile TYP
make garmin                       # Rebuild map
```

**Visual TYP Editors** (optional):
- [TYPWiz](http://www.pinns.co.uk/osm/typwiz.html) - Visual editor
- [TYPViewer](http://www.pinns.co.uk/osm/typviewer.html) - Preview tool

These tools provide GUI interfaces but our text-based approach is simpler for version control.

### Technical Implementation: How Colored Trails Work

Understanding the complete flow from OSM data to colored trails on your device:

**1. OSM Data Processing (Relations File)**

`config/garmin/style/relations`:
```
type=route & route=hiking & osmc:symbol~'red:.*' {
    apply {
        set hiking_red=yes;
        add mkgmap:route_name='${name}';
        add mkgmap:route_ref='${ref}';
    }
}
```

- Matches hiking route relations with OSMC symbols
- Extracts the color from the first part of `osmc:symbol` tag
- Sets individual flags on member ways (not a single color tag)
- Using `set` for flags (yes/no) and `add` for names (can accumulate)

**2. Way Rendering (Lines File)**

`config/garmin/style/lines`:
```
(highway=path | highway=footway | highway=track) & hiking_red=yes [0x2a resolution 22 continue]
(highway=path | highway=footway | highway=track) & hiking_blue=yes [0x2b resolution 22 continue]
```

- Each color flag triggers a separate line rendering
- Different Garmin type codes: 0x2a (red), 0x2b (blue), etc.
- `continue` allows the same way to match multiple rules
- Result: Multiple line objects for ways with multiple trail colors

**3. Visual Styling (TYP File)**

`config/garmin/hiking.txt` → compiled to `hiking.typ`:
```
[_line]
Type=0x2a
DayCustomColor=#E63946
Xpm="!!!!"  # Solid pattern
```

- Maps type codes (0x2a, 0x2b) to actual colors and patterns
- Defines how each line renders on the device
- Compiled to binary .typ format by mkgmap
- Included in final gmapsupp.img file

**Why Individual Flags Instead of Single Color Tag?**

❌ **Wrong approach** (gets overwritten):
```
# Way belongs to both red and blue routes
set route_color=red;   # First relation
set route_color=blue;  # Second relation overwrites red!
```

✓ **Correct approach** (accumulates):
```
# Way belongs to both red and blue routes
set hiking_red=yes;    # First relation
set hiking_blue=yes;   # Second relation - both flags exist!
```

This allows the lines file to render the way twice (once red, once blue) with both patterns visible.

**Why `continue` Statement?**

Without `continue`, mkgmap stops processing after the first match:
```
highway=path & hiking_red=yes [0x2a resolution 22]  # Matches, renders red, STOPS
highway=path & hiking_blue=yes [0x2b ...]           # Never reached!
```

With `continue`, mkgmap keeps processing:
```
highway=path & hiking_red=yes [0x2a resolution 22 continue]  # Matches, renders red, CONTINUES
highway=path & hiking_blue=yes [0x2b resolution 22 continue] # Also matches, renders blue
```

Result: Same way rendered with both patterns, visually distinguishable on device.

### Multi-Region Maps

To create maps for other regions:

1. Download region from [Geofabrik](http://download.geofabrik.de/):
   ```bash
   wget http://download.geofabrik.de/europe/austria-latest.osm.pbf -P data/
   ```

2. Edit `scripts/generate-garmin.sh` to use new file:
   ```bash
   /data/austria-latest.osm.pbf
   ```

3. Change map ID (avoid conflicts):
   ```bash
   --mapid=77780001 \      # Different from Hungary (77770001)
   --mapname=77780000 \
   ```

### Adding Contour Lines

To add elevation contours to Garmin map:

1. Generate contours with GDAL (see `CONTOURS.md`)
2. Convert contours to OSM format
3. Merge with main OSM file before splitter
4. Add contour styling to `lines` file

(Detailed instructions TBD - this is an advanced topic)

### Creating GMAP for BaseCamp

Currently, the script generates only `gmapsupp.img` for devices.

To create `.gmap` for BaseCamp (macOS/Windows):

```bash
podman run --rm \
  -v "$OUTPUT_DIR:/output" \
  garmin-builder:latest \
  mkgmap \
    --gmapi \
    --family-id=7777 \
    --output-dir=/output/gmap \
    /output/77770000.img
```

Install in BaseCamp:
- macOS: Double-click the `.gmap` folder
- Windows: Run installer (requires additional packaging)

## Resources

### Documentation
- [mkgmap Documentation](http://www.mkgmap.org.uk/doc/index.html)
- [mkgmap Style Manual](http://www.mkgmap.org.uk/doc/pdf/style-manual.pdf)
- [Garmin IMG Format](https://wiki.openstreetmap.org/wiki/OSM_Map_On_Garmin)
- [OSM Hiking Tags](https://wiki.openstreetmap.org/wiki/Hiking)

### Community Maps
- [Freizeitkarte](https://www.freizeitkarte-osm.de/) - Popular hiking/cycling maps
- [OpenMTBMap](https://openmtbmap.org/) - Mountain biking focused
- [OpenTopoMap Garmin](https://garmin.opentopomap.org/) - Topographic style

### Tools
- [BaseCamp](https://www.garmin.com/en-US/software/basecamp/) - Route planning
- [QMapShack](https://github.com/Maproom/qmapshack) - Open-source planning
- [GMapTool](https://www.gmaptool.eu/) - Map management utility

### Support
- [mkgmap Mailing List](https://www.mkgmap.org.uk/websvn/general.php)
- [OSM Forum - Garmin](https://forum.openstreetmap.org/viewforum.php?id=14)
- [r/Garmin](https://www.reddit.com/r/Garmin/)

### Colored Trails Implementation
- [Mkgmap Style Rules](https://wiki.openstreetmap.org/wiki/Mkgmap/help/style_rules) - Official style documentation
- [Mkgmap Custom Styles](https://wiki.openstreetmap.org/wiki/Mkgmap/help/Custom_styles) - Continue statement and overlays
- [OSMC Symbol Documentation](https://wiki.openstreetmap.org/wiki/Key:osmc:symbol) - Trail marker format
- [User:Petrovsk Garmin Styles](https://wiki.openstreetmap.org/wiki/User:Petrovsk/My_Garmin_map_styles) - TYP examples
- [Freizeitkarte Design](https://www.freizeitkarte-osm.de/garmin/en/design.html) - Hiking map approach

## Credits

- Map data: [OpenStreetMap](https://www.openstreetmap.org/) contributors
- Tools: [mkgmap](http://www.mkgmap.org.uk/) and [splitter](http://www.mkgmap.org.uk/splitter/)
- Bounds/Sea data: [Thkukuk](https://www.thkukuk.de/osm/)

## License

- **OpenStreetMap data**: © OpenStreetMap contributors, ODbL license
- **Generated maps**: Subject to ODbL - must attribute OSM
- **mkgmap/splitter**: GPL v2 license
- **This configuration**: MIT license
