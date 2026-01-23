#!/bin/bash
set -e

# Script to generate Garmin IMG maps from OSM data
# Usage: ./scripts/generate-garmin.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
CONFIG_DIR="$PROJECT_DIR/config/garmin"
OUTPUT_DIR="$PROJECT_DIR/garmin-output"
WORK_DIR="$OUTPUT_DIR/work"

echo "======================================"
echo "Generating Garmin Hiking Map"
echo "======================================"
echo ""

# Check if OSM data exists (reuse from PMTiles!)
if [ ! -f "$DATA_DIR/hungary-latest.osm.pbf" ]; then
    echo "Error: hungary-latest.osm.pbf not found!"
    echo "Please run ./scripts/download.sh first"
    exit 1
fi

# Check if style files exist
if [ ! -d "$CONFIG_DIR/style" ]; then
    echo "Error: Style files not found at $CONFIG_DIR/style"
    exit 1
fi

# Compile TYP file if it doesn't exist
if [ ! -f "$CONFIG_DIR/hiking.typ" ]; then
    echo "TYP file not found, compiling from hiking.txt..."
    echo ""
    "$SCRIPT_DIR/garmin/compile-typ.sh"
    echo ""
fi

# Create output directories
mkdir -p "$OUTPUT_DIR" "$WORK_DIR"

echo "Step 1: Splitting OSM data into tiles..."
echo "This may take 5-10 minutes depending on data size"
echo ""

# Run splitter to divide large OSM file into manageable tiles
podman run --rm \
  -v "$DATA_DIR:/data:ro" \
  -v "$WORK_DIR:/work" \
  garmin-builder:latest \
  splitter \
    --output-dir=/work \
    --mapid=77770001 \
    --max-nodes=1200000 \
    --keep-complete \
    --output=pbf \
    /data/hungary-latest.osm.pbf

if [ $? -ne 0 ]; then
    echo "Error: splitter failed"
    exit 1
fi

echo ""
echo "Step 2: Building Garmin map with mkgmap..."
echo "This may take 15-30 minutes depending on system"
echo ""

# Count tile files
TILE_COUNT=$(ls -1 "$WORK_DIR"/7*.osm.pbf 2>/dev/null | wc -l)
if [ "$TILE_COUNT" -eq 0 ]; then
    echo "Error: No tile files found in $WORK_DIR"
    echo "Splitter may have failed to generate tiles"
    exit 1
fi
echo "Processing $TILE_COUNT tile(s)..."
echo ""

# Run mkgmap to convert OSM tiles to Garmin IMG format
# Note: Using bash -c to expand glob pattern inside container
podman run --rm \
  -v "$WORK_DIR:/work" \
  -v "$CONFIG_DIR:/config:ro" \
  -v "$OUTPUT_DIR:/output" \
  -e JAVA_OPTS="-Xmx8G" \
  --entrypoint=/bin/bash \
  garmin-builder:latest \
  -c "java \$JAVA_OPTS -jar /opt/garmin/mkgmap/mkgmap.jar \
    --style-file=/config/style \
    --family-id=7777 \
    --product-id=1 \
    --family-name='Hungarian Hiking' \
    --series-name='Hungarian Hiking' \
    --description='Hungarian Hiking Trails from OSM' \
    --country-name=Hungary \
    --country-abbr=HU \
    --region-name=Hungary \
    --mapname=77770000 \
    --draw-priority=25 \
    --copyright-message='Map data © OpenStreetMap contributors' \
    --license-file=/config/LICENSE.txt \
    --index \
    --route \
    --add-pois-to-areas \
    --link-pois-to-ways \
    --precomp-sea=/opt/garmin/data/sea.zip \
    --bounds=/opt/garmin/data/bounds.zip \
    --location-autofill=bounds,is_in,nearest \
    --housenumbers \
    --latin1 \
    --code-page=1252 \
    --lower-case \
    --keep-going \
    --max-jobs \
    --output-dir=/output \
    --gmapsupp \
    /work/7*.osm.pbf \
    /config/hiking.typ"

if [ $? -ne 0 ]; then
    echo "Warning: mkgmap completed with errors (may be non-fatal)"
fi

echo ""
echo "======================================"
echo "Garmin map generation complete!"
echo "======================================"
echo ""

if [ -f "$OUTPUT_DIR/gmapsupp.img" ]; then
    echo "✓ Device map created successfully"
    echo ""
    echo "Output file:"
    echo "  $OUTPUT_DIR/gmapsupp.img"
    echo ""
    echo "File size:"
    ls -lh "$OUTPUT_DIR/gmapsupp.img" | awk '{print "  " $5 " (" $9 ")"}'
    echo ""
    echo "Installation:"
    echo "  1. Copy gmapsupp.img to your Garmin device's /Garmin/ folder"
    echo "  2. Safely eject the device"
    echo "  3. The map will appear in the device's map list"
    echo ""
    echo "Or use the helper script:"
    echo "  ./scripts/garmin/install-to-device.sh"
    echo ""
else
    echo "✗ Error: gmapsupp.img was not created"
    echo "Check the logs above for errors"
    exit 1
fi

echo ""
echo "Cleaning up temporary files..."
echo ""

# Clean up intermediate tile files (save space)
rm -rf "$WORK_DIR/*"

