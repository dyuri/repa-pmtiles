#!/bin/bash
set -e

# Script to generate PMTiles from OSM data using Docker
# Usage: ./scripts/generate-tiles.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
CONFIG_DIR="$PROJECT_DIR/config"
TILES_DIR="$PROJECT_DIR/tiles"

echo "======================================"
echo "Generating Hungarian Hiking Tiles"
echo "======================================"

# Check if OSM data exists
if [ ! -f "$DATA_DIR/hungary-latest.osm.pbf" ]; then
    echo "Error: hungary-latest.osm.pbf not found!"
    echo "Please run ./scripts/download.sh first"
    exit 1
fi

# Check if config files exist
if [ ! -f "$CONFIG_DIR/config-hiking.json" ] || [ ! -f "$CONFIG_DIR/process-hiking.lua" ]; then
    echo "Error: Configuration files not found!"
    echo "Please ensure config-hiking.json and process-hiking.lua exist in the config/ directory"
    exit 1
fi

# Create tiles directory if it doesn't exist
mkdir -p "$TILES_DIR"

echo ""
echo "Step 1: Running Tilemaker to generate MBTiles..."
echo "This may take 10-30 minutes depending on your system"
echo ""

# Run Tilemaker in Podman
podman run --rm \
  -v "$DATA_DIR:/data" \
  -v "$CONFIG_DIR:/config" \
  -v "$TILES_DIR:/output" \
  ghcr.io/systemed/tilemaker:master \
  --input /data/hungary-latest.osm.pbf \
  --output /output/hungary-hiking.mbtiles \
  --config /config/config-hiking.json \
  --process /config/process-hiking.lua

echo ""
echo "Step 2: Converting MBTiles to PMTiles format..."
echo ""

# Run PMTiles conversion in Docker
podman run --rm \
  -v "$TILES_DIR:/tiles" \
  ghcr.io/protomaps/go-pmtiles:latest \
  convert /tiles/hungary-hiking.mbtiles /tiles/hungary-hiking.pmtiles

echo ""
echo "Step 3: Verifying PMTiles..."
echo ""

# Verify the PMTiles file
podman run --rm \
  -v "$TILES_DIR:/tiles" \
  ghcr.io/protomaps/go-pmtiles:latest \
  verify /tiles/hungary-hiking.pmtiles

echo ""
echo "Step 4: Cleaning up MBTiles file..."
echo ""

# Remove MBTiles to save space (optional)
rm -f "$TILES_DIR/hungary-hiking.mbtiles"

echo ""
echo "======================================"
echo "Tile generation complete!"
echo "======================================"
echo ""
echo "PMTiles file: $TILES_DIR/hungary-hiking.pmtiles"
echo ""
echo "File size:"
ls -lh "$TILES_DIR/hungary-hiking.pmtiles"
echo ""
echo "Next step: Run 'docker-compose up -d' to start the nginx server"
