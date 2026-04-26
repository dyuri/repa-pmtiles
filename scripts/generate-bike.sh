#!/bin/bash
set -e

# Script to generate bike PMTiles from OSM data
# Usage: ./scripts/generate-bike.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
CONFIG_DIR="$PROJECT_DIR/config"
TILES_DIR="$PROJECT_DIR/tiles"

echo "======================================"
echo "Generating Hungarian Bike Tiles"
echo "======================================"

if [ ! -f "$DATA_DIR/hungary-latest.osm.pbf" ]; then
    echo "Error: hungary-latest.osm.pbf not found!"
    echo "Please run ./scripts/download.sh first"
    exit 1
fi

if [ ! -f "$CONFIG_DIR/config-bike.json" ] || [ ! -f "$CONFIG_DIR/process-bike.lua" ]; then
    echo "Error: Configuration files not found!"
    echo "Please ensure config-bike.json and process-bike.lua exist in the config/ directory"
    exit 1
fi

mkdir -p "$TILES_DIR"

STORE_DIR="$PROJECT_DIR/tmp/tilemaker_store_bike"
mkdir -p "$STORE_DIR"

echo ""
echo "Step 1: Running Tilemaker to generate MBTiles..."
echo "This may take 10-30 minutes depending on your system"
echo ""

podman run --rm \
  -v "$DATA_DIR:/data" \
  -v "$CONFIG_DIR:/config" \
  -v "$TILES_DIR:/output" \
  -v "$STORE_DIR:/store" \
  ghcr.io/systemed/tilemaker:master \
  --input /data/hungary-latest.osm.pbf \
  --output /output/hungary-bike.mbtiles \
  --config /config/config-bike.json \
  --process /config/process-bike.lua \
  --store /store

echo ""
echo "Step 2: Converting MBTiles to PMTiles format..."
echo ""

podman run --rm \
  -v "$TILES_DIR:/tiles" \
  ghcr.io/protomaps/go-pmtiles:latest \
  convert /tiles/hungary-bike.mbtiles /tiles/hungary-bike.pmtiles

echo ""
echo "Step 3: Verifying PMTiles..."
echo ""

podman run --rm \
  -v "$TILES_DIR:/tiles" \
  ghcr.io/protomaps/go-pmtiles:latest \
  verify /tiles/hungary-bike.pmtiles

echo ""
echo "Step 4: Cleaning up temporary files..."
echo ""

rm -f "$TILES_DIR/hungary-bike.mbtiles"
rm -rf "$STORE_DIR"

echo ""
echo "======================================"
echo "Bike tile generation complete!"
echo "======================================"
echo ""
echo "PMTiles file: $TILES_DIR/hungary-bike.pmtiles"
echo ""
echo "File size:"
ls -lh "$TILES_DIR/hungary-bike.pmtiles"
echo ""
echo "View the bike map at: http://localhost:8080/bike.html"
