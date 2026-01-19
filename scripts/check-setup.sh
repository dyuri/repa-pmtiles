#!/bin/bash

# Script to check if the setup is correct
# Usage: ./scripts/check-setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "======================================"
echo "Checking PMTiles Server Setup"
echo "======================================"
echo ""

# Check Docker
echo -n "Checking Docker... "
if command -v docker &> /dev/null; then
    echo "✓ Found: $(docker --version)"
else
    echo "✗ Docker not found!"
    echo "  Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check Docker Compose
echo -n "Checking Docker Compose... "
if command -v docker-compose &> /dev/null; then
    echo "✓ Found: $(docker-compose --version)"
elif docker compose version &> /dev/null; then
    echo "✓ Found: Docker Compose (plugin)"
else
    echo "✗ Docker Compose not found!"
    exit 1
fi

# Check directory structure
echo ""
echo "Checking directory structure:"
DIRS=("config" "data" "tiles" "www" "nginx" "scripts")
for dir in "${DIRS[@]}"; do
    if [ -d "$PROJECT_DIR/$dir" ]; then
        echo "  ✓ $dir/"
    else
        echo "  ✗ $dir/ missing"
    fi
done

# Check config files
echo ""
echo "Checking configuration files:"
FILES=(
    "config/config-hiking.json"
    "config/process-hiking.lua"
    "nginx/nginx.conf"
    "www/index.html"
    "docker-compose.yml"
)
for file in "${FILES[@]}"; do
    if [ -f "$PROJECT_DIR/$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file missing"
    fi
done

# Check for OSM data
echo ""
echo "Checking OSM data:"
if [ -f "$PROJECT_DIR/data/hungary-latest.osm.pbf" ]; then
    SIZE=$(du -h "$PROJECT_DIR/data/hungary-latest.osm.pbf" | cut -f1)
    echo "  ✓ hungary-latest.osm.pbf ($SIZE)"
else
    echo "  ✗ hungary-latest.osm.pbf not found"
    echo "    Run: ./scripts/download.sh"
fi

# Check for generated tiles
echo ""
echo "Checking generated tiles:"
if [ -f "$PROJECT_DIR/tiles/hungary-hiking.pmtiles" ]; then
    SIZE=$(du -h "$PROJECT_DIR/tiles/hungary-hiking.pmtiles" | cut -f1)
    echo "  ✓ hungary-hiking.pmtiles ($SIZE)"
else
    echo "  ✗ hungary-hiking.pmtiles not found"
    echo "    Run: ./scripts/generate-tiles.sh"
fi

# Check if server is running
echo ""
echo "Checking nginx server:"
if docker ps | grep -q "pmtiles-nginx"; then
    echo "  ✓ Server is running"
    echo "    View at: http://localhost:8080"
else
    echo "  ○ Server is not running"
    echo "    Start with: docker-compose up -d"
fi

echo ""
echo "======================================"
echo "Setup check complete!"
echo "======================================"
