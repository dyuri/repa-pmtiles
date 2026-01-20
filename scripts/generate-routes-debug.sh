#!/bin/bash
set -e

# Debug script to generate ONLY hiking routes PMTiles
# Usage: ./scripts/generate-routes-debug.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
CONFIG_DIR="$PROJECT_DIR/config"
TILES_DIR="$PROJECT_DIR/tiles"

echo "======================================"
echo "Generating Hiking Routes (DEBUG)"
echo "======================================"

# Check if OSM data exists
if [ ! -f "$DATA_DIR/hungary-latest.osm.pbf" ]; then
    echo "Error: hungary-latest.osm.pbf not found!"
    echo "Please run ./scripts/download.sh first"
    exit 1
fi

# Check if debug config files exist
if [ ! -f "$CONFIG_DIR/config-routes-only.json" ] || [ ! -f "$CONFIG_DIR/process-routes-only.lua" ]; then
    echo "Error: Debug configuration files not found!"
    echo "Please ensure config-routes-only.json and process-routes-only.lua exist"
    exit 1
fi

# Create tiles directory if it doesn't exist
mkdir -p "$TILES_DIR"

# Create temporary store directory for relation data
STORE_DIR="$PROJECT_DIR/tmp/tilemaker_store_debug"
mkdir -p "$STORE_DIR"

echo ""
echo "Step 1: Running Tilemaker (routes only)..."
echo "This should be faster than the full tileset"
echo ""

# Run Tilemaker in Podman with debug configs
podman run --rm \
  -v "$DATA_DIR:/data" \
  -v "$CONFIG_DIR:/config" \
  -v "$TILES_DIR:/output" \
  -v "$STORE_DIR:/store" \
  ghcr.io/systemed/tilemaker:master \
  --input /data/hungary-latest.osm.pbf \
  --output /output/hungary-routes-debug.mbtiles \
  --config /config/config-routes-only.json \
  --process /config/process-routes-only.lua \
  --store /store \
  --verbose

echo ""
echo "Step 2: Converting to PMTiles..."
echo ""

# Run PMTiles conversion
podman run --rm \
  -v "$TILES_DIR:/tiles" \
  ghcr.io/protomaps/go-pmtiles:latest \
  convert /tiles/hungary-routes-debug.mbtiles /tiles/hungary-routes-debug.pmtiles

echo ""
echo "Step 3: Inspecting PMTiles metadata..."
echo ""

# Show PMTiles info
podman run --rm \
  -v "$TILES_DIR:/tiles" \
  ghcr.io/protomaps/go-pmtiles:latest \
  show /tiles/hungary-routes-debug.pmtiles

echo ""
echo "Step 4: Extracting sample tiles for inspection..."
echo ""

# Extract a sample tile to check contents
podman run --rm \
  -v "$TILES_DIR:/tiles" \
  ghcr.io/protomaps/go-pmtiles:latest \
  tile /tiles/hungary-routes-debug.pmtiles 9 283 182 > "$TILES_DIR/sample-tile.mvt" 2>/dev/null || echo "Could not extract sample tile"

echo ""
echo "Step 5: Cleaning up temporary files..."
echo ""

# Keep MBTiles for now (for inspection)
echo "Keeping MBTiles for manual inspection"
# rm -f "$TILES_DIR/hungary-routes-debug.mbtiles"

# Remove store directory
rm -rf "$STORE_DIR"

echo ""
echo "======================================"
echo "Debug tile generation complete!"
echo "======================================"
echo ""
echo "PMTiles file: $TILES_DIR/hungary-routes-debug.pmtiles"
echo "MBTiles file: $TILES_DIR/hungary-routes-debug.mbtiles (kept for inspection)"
echo ""
echo "File sizes:"
ls -lh "$TILES_DIR"/hungary-routes-debug.*
echo ""
echo "Next steps for debugging:"
echo "1. Inspect the MBTiles with: sqlite3 tiles/hungary-routes-debug.mbtiles"
echo "2. Check metadata: SELECT * FROM metadata;"
echo "3. Count tiles: SELECT COUNT(*) FROM tiles;"
echo "4. Check a sample tile's content"
echo "5. Add to map viewer for visual inspection"
