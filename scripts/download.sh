#!/bin/bash
set -e

# Script to download Hungarian OSM data
# Usage: ./scripts/download.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"

echo "======================================"
echo "Downloading Hungarian OSM Data"
echo "======================================"

# Create data directory if it doesn't exist
mkdir -p "$DATA_DIR"

cd "$DATA_DIR"

# Download Hungary extract from Geofabrik
echo "Downloading hungary-latest.osm.pbf from Geofabrik..."
echo "File size: approximately 500MB"
echo ""

wget -N https://download.geofabrik.de/europe/hungary-latest.osm.pbf

echo ""
echo "======================================"
echo "Download complete!"
echo "File location: $DATA_DIR/hungary-latest.osm.pbf"
echo "======================================"
echo ""
echo "Next step: Run ./scripts/generate-tiles.sh to generate tiles"
