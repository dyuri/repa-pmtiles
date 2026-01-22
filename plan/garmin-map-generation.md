# Garmin Map Generation Plan

## Overview

This document outlines a plan to generate Garmin-compatible IMG map files from the same OpenStreetMap data used for PMTiles generation. The goal is to create a similar automated workflow that produces installable Garmin maps for GPS devices and applications.

## Garmin IMG Format Background

### What is IMG?

- **Format**: Proprietary binary format developed by Garmin for GPS devices
- **File Types**:
  - `.img` - Individual map tiles or complete maps
  - `.gmapsupp.img` - Combined map file for device installation
  - `.gmap` - macOS BaseCamp/RoadTrip format
- **Usage**: Can be installed on:
  - Garmin GPS devices (eTrex, Oregon, Montana, etc.)
  - Garmin BaseCamp desktop application
  - QMapShack (open-source planning tool)
  - Mobile apps (OruxMaps, Locus Map via conversion)

### Key Differences from PMTiles

| Feature | PMTiles | Garmin IMG |
|---------|---------|------------|
| Format | Vector tiles (MVT) | Proprietary binary |
| Usage | Web browsers via MapLibre | GPS devices + desktop apps |
| Styling | Runtime (JSON style) | Compile-time (TYP file) |
| File Size | 500-600MB | 300-800MB (varies by detail) |
| Updates | Replace file, instant | Re-install on device |
| Interactivity | Full (web features) | Limited (device UI) |
| Routable | No (display only) | Yes (can include routing) |

## Tools and Technologies

### Primary Tools

1. **mkgmap** - Converts OSM data to IMG format
   - Java-based converter
   - Supports custom styles
   - Can generate routable maps
   - Latest version: ~r4900+ (updated regularly)

2. **splitter** - Splits large OSM files into tiles for mkgmap
   - Required for region-sized maps (like Hungary)
   - Manages memory constraints
   - Creates optimal tile boundaries

3. **osmconvert** (optional) - Preprocessing OSM data
   - Filtering specific regions
   - Converting between OSM formats
   - Applying bounding boxes

4. **TYPViewer/TYPWiz** - Creating custom TYP files
   - Visual style editor
   - Defines colors, patterns, icons for Garmin display
   - Alternative: text-based TYP compilation

### Container Strategy

Unlike PMTiles (which has official Docker images), Garmin tools require custom containerization:

**Option A: Create custom Docker image**
```dockerfile
FROM openjdk:17-slim
RUN apt-get update && apt-get install -y wget unzip osmium-tool
WORKDIR /opt/garmin
RUN wget https://www.mkgmap.org.uk/download/mkgmap-latest.tar.gz
RUN wget https://www.mkgmap.org.uk/download/splitter-latest.tar.gz
RUN tar xzf mkgmap-latest.tar.gz && tar xzf splitter-latest.tar.gz
# Add scripts and styling
VOLUME ["/data", "/output"]
ENTRYPOINT ["/opt/garmin/build.sh"]
```

**Option B: Use existing community images**
- `yadutaf/mkgmap` - Available but may be outdated
- `eeschiavo/mkgmap` - Another community option
- **Recommendation**: Build custom image for control and updates

## Workflow Design

### Proposed Directory Structure

```
pmtiles-server/
├── config/
│   ├── config-hiking.json          # Existing PMTiles config
│   ├── process-hiking.lua          # Existing Tilemaker Lua
│   ├── garmin/                     # NEW
│   │   ├── style/                  # mkgmap style files
│   │   │   ├── lines               # Trail/path rendering rules
│   │   │   ├── points              # POI rendering rules
│   │   │   ├── polygons            # Area rendering rules
│   │   │   ├── info                # Map metadata
│   │   │   ├── options             # Build options
│   │   │   └── relations           # Route relation handling
│   │   ├── hiking.typ              # Custom Garmin display style
│   │   └── splitter.args           # Splitter configuration
├── data/
│   └── hungary-latest.osm.pbf      # Existing OSM data (reused!)
├── garmin-output/                  # NEW - Generated Garmin maps
│   ├── gmapsupp.img                # For Garmin devices
│   ├── hungary-hiking.gmap/        # For BaseCamp (macOS)
│   └── tiles/                      # Intermediate tile files
├── scripts/
│   ├── download.sh                 # Existing (reused)
│   ├── generate-tiles.sh           # Existing PMTiles generation
│   ├── generate-garmin.sh          # NEW - Garmin IMG generation
│   └── garmin/                     # NEW
│       ├── build-garmin-image.sh   # Build Docker image
│       ├── preprocess-osm.sh       # Optional OSM filtering
│       └── install-to-device.sh    # Device installation helper
├── docker/                         # NEW
│   └── garmin/
│       ├── Dockerfile              # Custom mkgmap+splitter image
│       └── entrypoint.sh           # Container entrypoint script
└── docker-compose.yml              # Update with Garmin service (optional)
```

### Data Flow

```
OpenStreetMap Data (hungary-latest.osm.pbf)
           │
           ├─────────────────────┬─────────────────────┐
           │                     │                     │
           ▼                     ▼                     ▼
    [PMTiles Path]      [Garmin Path]         [Other formats...]
           │                     │
    Tilemaker (Lua)       Splitter (Java)
           │                     │
    MBTiles format         Split OSM tiles
           │                     │
    PMTiles convert        mkgmap (Java)
           │                     │
    hungary-hiking        gmapsupp.img
    .pmtiles              + .gmap bundle
```

## Implementation Plan

### Phase 1: Tool Setup (Week 1)

**Goals:**
- Create Docker image with mkgmap and splitter
- Verify tools work with sample data
- Set up basic build script

**Tasks:**
1. Create `docker/garmin/Dockerfile`
   - Base: `openjdk:17-slim`
   - Install mkgmap (latest version)
   - Install splitter (latest version)
   - Add osmium-tool for preprocessing
   - Set up entrypoint

2. Create `scripts/garmin/build-garmin-image.sh`
   ```bash
   #!/bin/bash
   podman build -t garmin-builder:latest docker/garmin/
   ```

3. Test with small dataset
   - Use existing `hungary-latest.osm.pbf`
   - Run splitter to verify it works
   - Run mkgmap with default style
   - Verify output IMG file

**Deliverables:**
- Working Docker image
- Basic IMG file generated from Hungary OSM data
- Documentation of tool versions and build process

### Phase 2: Style Development (Week 2-3)

**Goals:**
- Create mkgmap style files for hiking trails
- Design custom TYP file for enhanced rendering
- Match visual style to existing PMTiles map

**Tasks:**

1. **Create mkgmap style files** in `config/garmin/style/`

   **`lines` file** - Trail and path rendering:
   ```
   # Hiking routes with OSMC symbols
   type=route & route=hiking & osmc:symbol~'.*' {
     set mkgmap:display_name='${name} (${osmc:symbol})';
   }

   # Trails by highway type
   highway=path [0x16 resolution 24 continue]
   highway=footway [0x16 resolution 24 continue]
   highway=track & tracktype=grade1 [0x0e resolution 22]
   highway=track & tracktype=grade2 [0x0f resolution 22]
   highway=track & tracktype=grade3 [0x10 resolution 22]

   # Add SAC scale difficulty
   highway=path & sac_scale=hiking [0x16 resolution 24]
   highway=path & sac_scale=mountain_hiking [0x17 resolution 24]
   highway=path & sac_scale=demanding_mountain_hiking [0x18 resolution 24]

   # Routes with color coding
   highway=path & osmc:symbol~'.*:red:.*' {add color=red} [0x16 resolution 24]
   highway=path & osmc:symbol~'.*:blue:.*' {add color=blue} [0x16 resolution 24]
   highway=path & osmc:symbol~'.*:yellow:.*' {add color=yellow} [0x16 resolution 24]
   highway=path & osmc:symbol~'.*:green:.*' {add color=green} [0x16 resolution 24]
   ```

   **`points` file** - POI rendering:
   ```
   # Mountain peaks
   natural=peak [0x6616 resolution 23]
   natural=peak & ele>1000 [0x6616 resolution 21]

   # Hiking facilities
   tourism=alpine_hut [0x2b06 resolution 24]
   tourism=wilderness_hut [0x2b06 resolution 24]
   amenity=shelter [0x2b06 resolution 24]
   tourism=viewpoint [0x2c0c resolution 24]

   # Water sources
   amenity=drinking_water [0x5000 resolution 24]
   natural=spring [0x6511 resolution 24]

   # Other features
   natural=saddle [0x6616 resolution 24]
   natural=cave_entrance [0x6601 resolution 24]
   ```

   **`polygons` file** - Area rendering:
   ```
   # Natural features
   natural=wood [0x50 resolution 20]
   landuse=forest [0x50 resolution 20]
   natural=water [0x3c resolution 20]
   natural=wetland [0x51 resolution 22]

   # Land use
   landuse=grass [0x52 resolution 22]
   landuse=meadow [0x52 resolution 22]
   natural=grassland [0x52 resolution 22]
   leisure=park [0x17 resolution 22]
   landuse=farmland [0x4e resolution 22]

   # Buildings at high zoom
   building=* [0x13 resolution 24]
   ```

   **`info` file** - Map metadata:
   ```
   # Map information
   family-id: 7777
   product-id: 1
   code-page: 1252

   # Copyright
   copyright: Map data © OpenStreetMap contributors
   license-file: license.txt

   # Index options
   index
   latin1

   # Routing
   route
   drive-on-right
   ```

   **`options` file** - Style options:
   ```
   # mkgmap options
   levels = 0:24, 1:23, 2:22, 3:21, 4:20, 5:19, 6:18
   overview-levels = 4:20, 5:19, 6:18, 7:17, 8:16
   extra-used-tags = color
   ```

2. **Create TYP file** for custom rendering
   - Define custom colors for Hungarian hiking trail markers
   - Add custom line styles (dashed, dotted for different trail types)
   - Define POI icons suitable for hiking
   - Tool: Use TYPWiz or create via text format + typcompiler

   Example TYP structure:
   ```
   [_polygon]
   Type=0x50
   String=Forest
   ExtendedLabels=Y
   CustomColor=Yes
   DayCustomColor=#52B788
   NightCustomColor=#2D6A4F

   [_line]
   Type=0x16
   String=Hiking Trail
   ExtendedLabels=Y
   LineWidth=3
   BorderWidth=1
   CustomColor=Yes
   DayCustomColor=#E63946
   NightCustomColor=#A62639
   ```

3. **Route relation handling**
   - Create `relations` file for processing hiking routes
   - Extract OSMC symbols and trail names
   - Generate proper labels for device display

4. **Create preprocessing script** if needed
   - Filter specific hiking-relevant tags
   - Add custom tags for Garmin-specific rendering
   - Optimize data for device constraints

**Deliverables:**
- Complete mkgmap style files
- Custom TYP file with hiking-optimized rendering
- Test IMG with visual verification on device/BaseCamp

### Phase 3: Build Automation (Week 3-4)

**Goals:**
- Create automated build script
- Handle splitter configuration
- Generate multiple output formats
- Add error handling and logging

**Tasks:**

1. **Create `scripts/generate-garmin.sh`**:
   ```bash
   #!/bin/bash
   set -e

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
   DATA_DIR="$PROJECT_DIR/data"
   CONFIG_DIR="$PROJECT_DIR/config/garmin"
   OUTPUT_DIR="$PROJECT_DIR/garmin-output"
   WORK_DIR="$OUTPUT_DIR/work"

   echo "======================================"
   echo "Generating Garmin Hiking Map"
   echo "======================================"

   # Check if OSM data exists (reuse from PMTiles!)
   if [ ! -f "$DATA_DIR/hungary-latest.osm.pbf" ]; then
       echo "Error: hungary-latest.osm.pbf not found!"
       echo "Please run ./scripts/download.sh first"
       exit 1
   fi

   # Create output directories
   mkdir -p "$OUTPUT_DIR" "$WORK_DIR"

   echo ""
   echo "Step 1: Splitting OSM data into tiles..."
   echo "This may take 5-10 minutes"
   echo ""

   # Run splitter
   podman run --rm \
     -v "$DATA_DIR:/data:ro" \
     -v "$WORK_DIR:/work" \
     garmin-builder:latest \
     splitter \
       --output-dir=/work \
       --mapid=77770001 \
       --max-nodes=1000000 \
       --keep-complete=true \
       /data/hungary-latest.osm.pbf

   echo ""
   echo "Step 2: Building Garmin map with mkgmap..."
   echo "This may take 10-20 minutes"
   echo ""

   # Run mkgmap
   podman run --rm \
     -v "$WORK_DIR:/work" \
     -v "$CONFIG_DIR:/config:ro" \
     -v "$OUTPUT_DIR:/output" \
     garmin-builder:latest \
     mkgmap \
       --style-file=/config/style \
       --family-id=7777 \
       --product-id=1 \
       --family-name="Hungarian Hiking" \
       --series-name="Hungarian Hiking" \
       --description="Hungarian Hiking Trails" \
       --country-name="Hungary" \
       --mapname=77770000 \
       --draw-priority=25 \
       --index \
       --route \
       --add-pois-to-areas \
       --link-pois-to-ways \
       --generate-sea=extend-sea-sectors \
       --precomp-sea=/config/sea.zip \
       --bounds=/config/bounds.zip \
       --location-autofill=is_in,nearest \
       --housenumbers \
       --latin1 \
       --code-page=1252 \
       --lower-case \
       --keep-going \
       --max-jobs \
       --output-dir=/output \
       --gmapsupp \
       /work/6*.osm.pbf

   echo ""
   echo "Step 3: Creating BaseCamp-compatible GMAP..."
   echo ""

   # Create .gmap for macOS BaseCamp
   podman run --rm \
     -v "$OUTPUT_DIR:/output" \
     garmin-builder:latest \
     mkgmap \
       --gmapi \
       --family-id=7777 \
       --output-dir=/output/gmap \
       /output/77770000.img

   echo ""
   echo "Step 4: Cleanup temporary files..."
   echo ""

   # Clean up intermediate files
   rm -rf "$WORK_DIR"

   echo ""
   echo "======================================"
   echo "Garmin map generation complete!"
   echo "======================================"
   echo ""
   echo "Output files:"
   echo "  - Device: $OUTPUT_DIR/gmapsupp.img"
   echo "  - BaseCamp: $OUTPUT_DIR/hungary-hiking.gmap/"
   echo ""
   echo "File sizes:"
   ls -lh "$OUTPUT_DIR/gmapsupp.img"
   echo ""
   echo "Next steps:"
   echo "  1. Copy gmapsupp.img to your Garmin device's /Garmin/ folder"
   echo "  2. Or install hungary-hiking.gmap in BaseCamp"
   echo ""
   ```

2. **Create `config/garmin/splitter.args`**:
   ```
   # Splitter configuration
   max-nodes=1000000
   mapid=77770001
   keep-complete=true
   polygon-file=hungary.poly
   write-kml=hungary-tiles.kml
   ```

3. **Add convenience script for device installation**:
   Create `scripts/garmin/install-to-device.sh`:
   ```bash
   #!/bin/bash
   # Helper script to install map to connected Garmin device

   GMAPSUPP="garmin-output/gmapsupp.img"

   if [ ! -f "$GMAPSUPP" ]; then
       echo "Error: gmapsupp.img not found!"
       echo "Run ./scripts/generate-garmin.sh first"
       exit 1
   fi

   # Detect mounted Garmin device
   GARMIN_PATH=$(mount | grep -i garmin | awk '{print $3}' | head -n1)

   if [ -z "$GARMIN_PATH" ]; then
       echo "No Garmin device detected."
       echo "Please manually copy $GMAPSUPP to your device's /Garmin/ folder"
       exit 1
   fi

   echo "Found Garmin device at: $GARMIN_PATH"
   echo "Installing map..."

   cp "$GMAPSUPP" "$GARMIN_PATH/Garmin/gmapsupp.img"

   echo "Installation complete!"
   echo "Safely eject your device and it will be ready to use"
   ```

**Deliverables:**
- Fully automated build script
- Device installation helper
- Error handling and progress reporting
- Documentation of build options

### Phase 4: Testing & Optimization (Week 4-5)

**Goals:**
- Test on real Garmin devices
- Verify routing works
- Optimize file size vs. detail
- Performance tuning

**Tasks:**

1. **Device Testing**:
   - Test on Garmin eTrex, Oregon, or Montana series
   - Verify trail visibility at different zoom levels
   - Check POI icons and labels
   - Test search functionality
   - Verify routing between points

2. **BaseCamp Testing**:
   - Install GMAP bundle
   - Verify rendering matches device
   - Test route planning
   - Export routes to GPX

3. **Optimization**:
   - Adjust `max-nodes` in splitter for optimal tile size
   - Tune resolution levels in style files
   - Balance detail vs. device memory constraints
   - Reduce file size if needed (current target: <500MB)

4. **Style Refinement**:
   - Adjust colors for better visibility
   - Refine POI priorities
   - Improve label placement
   - Test day/night mode rendering

**Deliverables:**
- Tested and verified IMG file
- Performance benchmarks
- Device compatibility matrix
- User installation guide

### Phase 5: Documentation & Integration (Week 5)

**Goals:**
- Document the complete workflow
- Integrate with existing Makefile
- Create user-facing documentation
- Set up update workflow

**Tasks:**

1. **Create `GARMIN-MAPS.md`** documentation:
   ```markdown
   # Garmin Map Generation Guide

   ## Overview
   Generate installable Garmin hiking maps from the same OSM data

   ## Quick Start
   1. Download OSM data: `./scripts/download.sh` (reuses PMTiles data)
   2. Build Docker image: `make garmin-image`
   3. Generate map: `./scripts/generate-garmin.sh`
   4. Install to device: `./scripts/garmin/install-to-device.sh`

   ## Output Files
   - `gmapsupp.img` - Copy to device /Garmin/ folder
   - `hungary-hiking.gmap/` - Install in BaseCamp

   ## Customization
   [Details on editing styles, TYP files, etc.]

   ## Troubleshooting
   [Common issues and solutions]
   ```

2. **Update `Makefile`** with Garmin targets:
   ```makefile
   # Garmin map generation
   .PHONY: garmin-image garmin garmin-clean

   garmin-image:
   	@echo "Building Garmin builder Docker image..."
   	@scripts/garmin/build-garmin-image.sh

   garmin: garmin-image
   	@echo "Generating Garmin hiking map..."
   	@scripts/generate-garmin.sh

   garmin-clean:
   	@echo "Cleaning Garmin build artifacts..."
   	@rm -rf garmin-output/work
   	@rm -f garmin-output/*.img

   # Combined target for both formats
   .PHONY: all-maps
   all-maps: tiles garmin
   	@echo "All map formats generated!"
   ```

3. **Update main `README.md`** with Garmin section:
   ```markdown
   ## Generating Garmin Maps

   In addition to web-based PMTiles, you can generate Garmin-compatible
   IMG files for GPS devices:

   ```bash
   # One-time: Build the Garmin tools container
   make garmin-image

   # Generate Garmin map (uses same OSM data)
   make garmin

   # Install to connected device
   ./scripts/garmin/install-to-device.sh
   ```

   See `GARMIN-MAPS.md` for detailed information.
   ```

4. **Create FAQ/troubleshooting section**:
   - Device compatibility issues
   - Memory constraints on older devices
   - Updating maps
   - Combining with other map data
   - Custom style modifications

**Deliverables:**
- Complete documentation
- Integrated Makefile targets
- User installation guide
- FAQ and troubleshooting guide

## Technical Considerations

### Memory Constraints

**Splitter Configuration**:
- Hungary ~10-15GB memory required for processing
- Use `--max-nodes=1000000` for good balance
- May need `--max-areas=4096` for large regions
- Consider `--split-file` for manual tile control

**mkgmap Memory**:
- Allocate 4-8GB heap: `-Xmx8G`
- Use `--max-jobs` for parallel processing
- Enable `--keep-going` to handle errors

### Routing Considerations

**Enable Routing** (optional, adds ~200-300MB):
```bash
mkgmap --route \
       --drive-on-right \
       --check-roundabouts \
       --add-pois-to-areas \
       --link-pois-to-ways
```

**Routing Network Types**:
- Hiking paths: Set access as `foot=yes`
- Bike trails: Set access as `bicycle=yes`
- Restrict motor vehicles appropriately

**Turn Restrictions**:
- Not critical for hiking maps
- Can disable to reduce file size

### Style Complexity

**Performance Impact**:
- Complex rules slow compilation
- Reduce resolution levels for faster builds
- Use `continue` statements carefully
- Limit polygon rendering depth

**Device Limitations**:
- Older devices: Max 2048 map tiles
- Memory: 4GB max map size for most devices
- Search index: Balance between size and functionality

### File Size Optimization

**Current Target**: 400-600MB for Hungary hiking map

**Optimization Strategies**:
1. Reduce max zoom level (24 → 23)
2. Limit building rendering
3. Simplify polygon boundaries (`--simplify-level`)
4. Remove unused POI types
5. Disable routing if not needed
6. Use higher `--reduce-point-density`

**Example Optimized Build**:
```bash
mkgmap --reduce-point-density=4 \
       --reduce-point-density-polygon=8 \
       --simplify-level=2 \
       --polygon-size-limits="24:12, 23:10, 22:8, 21:6"
```

## Comparison with PMTiles Workflow

### Similarities

1. **Data Source**: Both use same `hungary-latest.osm.pbf`
2. **OSM Extraction**: Both process trails, POIs, and base layers
3. **Containerization**: Both use Docker/Podman
4. **Automation**: Both have scripted generation
5. **Update Process**: Both can be regenerated from latest OSM data

### Differences

| Aspect | PMTiles | Garmin IMG |
|--------|---------|------------|
| **Build Time** | 30-60 min | 20-40 min |
| **Styling** | Runtime JSON | Compile-time TYP |
| **Style Language** | MapLibre GL | mkgmap rules |
| **Output Size** | 500-600MB | 400-600MB |
| **Update Method** | Replace file | Re-install to device |
| **Interactivity** | Full web features | Device UI only |
| **Prerequisites** | Browser | GPS device or BaseCamp |
| **Custom Rendering** | Easy (edit JSON) | Medium (recompile) |
| **Routing** | No | Yes (optional) |

### Workflow Parallelism

Both workflows can run in parallel and share data:

```
./scripts/download.sh  ← Run once
    ↓
hungary-latest.osm.pbf
    ↓
    ├─→ ./scripts/generate-tiles.sh   → hungary-hiking.pmtiles
    └─→ ./scripts/generate-garmin.sh  → gmapsupp.img
```

**Makefile Integration**:
```makefile
# Generate everything
all: tiles garmin

# Just web maps
web: tiles

# Just device maps
device: garmin
```

## Expected Outcomes

### Output Files

After running `make garmin`, you should have:

```
garmin-output/
├── gmapsupp.img              # 400-600MB - For Garmin devices
├── hungary-hiking.gmap/      # 450-650MB - For BaseCamp (macOS/Windows)
│   ├── Info.xml
│   └── Product1/
│       └── [map tiles]
└── tiles/                    # Cleaned up after build
```

### Performance Expectations

**Build Times** (on modern system):
- Splitter: 5-10 minutes
- mkgmap: 15-30 minutes
- Total: 20-40 minutes

**Device Performance**:
- Map load time: 10-30 seconds (depending on device age)
- Redraw speed: Smooth on modern devices (eTrex 32x, Oregon 750, GPSMAP 66)
- Memory usage: 400-600MB (ensure device has >1GB total memory)

### Visual Quality

**On Device Screen**:
- Trails visible from zoom 500m to 50m
- POIs appear at 300m zoom and closer
- Labels readable on 2.2" - 3.5" screens
- Night mode automatically adjusts colors

**In BaseCamp**:
- Full detail at all zoom levels
- Smooth panning and zooming
- Route planning with trail profiles
- POI search and filtering

## Future Enhancements

### Phase 6 (Optional Improvements)

1. **Multi-Region Support**:
   - Generate maps for other countries
   - Create Europe-wide hiking map
   - Script for any Geofabrik region

2. **Advanced Routing**:
   - Hiking-specific routing profiles
   - Avoid dangerous trails
   - Prefer scenic routes
   - Elevation-aware routing

3. **DEM Integration**:
   - Add elevation contours to Garmin map
   - Integrate SRTM data
   - Show elevation profiles
   - 3D terrain view (on compatible devices)

4. **TYP File Variants**:
   - High-contrast mode for bright sunlight
   - Colorblind-friendly palette
   - Minimalist style for small screens
   - Detailed style for large-screen devices

5. **Automated Updates**:
   - Cron job for weekly regeneration
   - Automatic download of latest OSM data
   - Versioned releases
   - Changelog generation

6. **Quality Assurance**:
   - Automated visual regression testing
   - Route validation
   - POI accuracy checks
   - Device compatibility testing

## Resources

### Documentation

- [mkgmap Documentation](http://www.mkgmap.org.uk/doc/index.html)
- [mkgmap Style Manual](http://www.mkgmap.org.uk/doc/pdf/style-manual.pdf)
- [splitter Documentation](http://www.mkgmap.org.uk/doc/splitter.html)
- [TYP File Format](http://www.pinns.co.uk/osm/typformat.html)
- [Garmin IMG Format](https://wiki.openstreetmap.org/wiki/OSM_Map_On_Garmin/IMG_File_Format)

### Tools

- [mkgmap Download](http://www.mkgmap.org.uk/download/mkgmap.html)
- [splitter Download](http://www.mkgmap.org.uk/download/splitter.html)
- [TYPWiz - Visual TYP Editor](http://www.pinns.co.uk/osm/typwiz.html)
- [GMapTool - Map Management](https://www.gmaptool.eu/)
- [BaseCamp Download](https://www.garmin.com/en-US/software/basecamp/)

### Community Styles

Existing mkgmap style examples to learn from:
- [Freizeitkarte](https://www.freizeitkarte-osm.de/) - Popular recreation/hiking style
- [OpenTopoMap Garmin](https://garmin.opentopomap.org/) - Topographic style
- [OpenMTBMap](https://openmtbmap.org/) - Mountain biking focused
- [VeloMap](https://www.velomap.org/) - Cycling focused

### Testing Resources

- [mkgmap Forum](https://www.mkgmap.org.uk/websvn/general.php)
- [OSM Garmin Maps Forum](https://forum.openstreetmap.org/viewforum.php?id=14)
- [r/Garmin Subreddit](https://www.reddit.com/r/Garmin/)

## Implementation Timeline

### Week 1: Foundation
- [ ] Create Dockerfile for mkgmap/splitter
- [ ] Build Docker image
- [ ] Test basic IMG generation
- [ ] Verify output on device

### Week 2: Styling
- [ ] Create mkgmap style files
- [ ] Design TYP file
- [ ] Test rendering
- [ ] Iterate on visual quality

### Week 3: Automation
- [ ] Write generate-garmin.sh script
- [ ] Configure splitter parameters
- [ ] Add error handling
- [ ] Create installation helpers

### Week 4: Testing
- [ ] Test on multiple devices
- [ ] Verify routing
- [ ] Optimize file size
- [ ] Performance tuning

### Week 5: Documentation
- [ ] Write GARMIN-MAPS.md
- [ ] Update README.md
- [ ] Create user guide
- [ ] Add troubleshooting section

## Success Criteria

✅ **Functional Requirements**:
- [ ] IMG file <600MB
- [ ] All hiking trails visible
- [ ] POIs correctly placed
- [ ] Labels readable on device
- [ ] Installs without errors
- [ ] Works on eTrex/Oregon/Montana series

✅ **Quality Requirements**:
- [ ] Build completes in <60 minutes
- [ ] Visual quality matches PMTiles
- [ ] No missing data from OSM source
- [ ] Routing works (if enabled)
- [ ] Compatible with BaseCamp

✅ **Usability Requirements**:
- [ ] Single command generation
- [ ] Automated installation script
- [ ] Clear documentation
- [ ] Easy style customization

## Conclusion

This plan provides a complete roadmap for generating Garmin hiking maps that complement the existing PMTiles web maps. The two formats serve different use cases:

- **PMTiles**: Interactive web mapping, modern browsers, desktop/mobile
- **Garmin IMG**: Dedicated GPS devices, offline navigation, proven reliability

By sharing the same OSM data source and maintaining similar visual styles, users get a consistent experience across web and device platforms.

The containerized approach ensures reproducibility and easy updates, while the automated scripts make regular map generation simple and maintainable.

**Estimated Total Effort**: 5 weeks (1 person, part-time)
**Estimated File Size**: 400-600MB for Hungary
**Estimated Build Time**: 20-40 minutes per build
**Ongoing Maintenance**: ~2 hours/month for updates
