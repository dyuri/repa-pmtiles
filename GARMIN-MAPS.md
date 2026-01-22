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
- OSMC symbol information
- Network type (local/regional/national)

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

### Trails Not Showing Color

**Cause:** Garmin devices show colors differently than web

**Note:** Colors are applied via the style rules. On some devices:
- Night mode inverts colors
- Monochrome devices show grayscale
- Older devices have limited color palettes

To enhance colors, edit the TYP file (advanced - see documentation).

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
| **Custom Colors** | Easy | Moderate (TYP file) |

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

### Creating Custom TYP File

TYP files define how features render on the device (colors, patterns, icons).

Tools:
- [TYPWiz](http://www.pinns.co.uk/osm/typwiz.html) - Visual editor
- [TYPViewer](http://www.pinns.co.uk/osm/typviewer.html) - Preview tool

Process:
1. Create TYP with TYPWiz
2. Save as `config/garmin/hiking.typ`
3. Add to mkgmap command in `scripts/generate-garmin.sh`:
   ```bash
   --family-name="Hungarian Hiking" \
   --style-file=/config/style \
   --family-id=7777 \
   /config/hiking.typ \   # Add this line
   ```

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

## Credits

- Map data: [OpenStreetMap](https://www.openstreetmap.org/) contributors
- Tools: [mkgmap](http://www.mkgmap.org.uk/) and [splitter](http://www.mkgmap.org.uk/splitter/)
- Bounds/Sea data: [Thkukuk](https://www.thkukuk.de/osm/)

## License

- **OpenStreetMap data**: © OpenStreetMap contributors, ODbL license
- **Generated maps**: Subject to ODbL - must attribute OSM
- **mkgmap/splitter**: GPL v2 license
- **This configuration**: MIT license
