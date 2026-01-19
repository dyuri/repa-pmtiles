#!/bin/bash
set -e

# Script to update tiles with latest OSM data
# Usage: ./scripts/update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
TILES_DIR="$PROJECT_DIR/tiles"
BACKUP_DIR="$PROJECT_DIR/backups"

echo "======================================"
echo "Updating Hungarian Hiking Tiles"
echo "======================================"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup existing tiles if they exist
if [ -f "$TILES_DIR/hungary-hiking.pmtiles" ]; then
    BACKUP_NAME="hungary-hiking-$(date +%Y%m%d-%H%M%S).pmtiles"
    echo "Backing up current tiles to: $BACKUP_NAME"
    cp "$TILES_DIR/hungary-hiking.pmtiles" "$BACKUP_DIR/$BACKUP_NAME"
    echo ""
fi

# Download latest OSM data
echo "Step 1: Downloading latest OSM data..."
cd "$DATA_DIR"
wget -N https://download.geofabrik.de/europe/hungary-latest.osm.pbf
echo ""

# Generate new tiles
echo "Step 2: Generating new tiles..."
"$SCRIPT_DIR/generate-tiles.sh"
echo ""

# Restart nginx if it's running
if podman compose -f "$PROJECT_DIR/docker-compose.yml" ps | grep -q "pmtiles-nginx"; then
    echo "Step 3: Restarting nginx server..."
    podman compose -f "$PROJECT_DIR/docker-compose.yml" restart
    echo ""
fi

echo "======================================"
echo "Update complete!"
echo "======================================"
echo ""
echo "New tiles: $TILES_DIR/hungary-hiking.pmtiles"
echo "Backup saved to: $BACKUP_DIR/$BACKUP_NAME"
echo ""
echo "Old backups in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"
echo ""
echo "Tip: You can safely delete old backups to save space"
